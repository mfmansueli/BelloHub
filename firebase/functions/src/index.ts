// Entry point of the deployed functions (Cloud Functions 2nd gen, region europe-west1, D28/D29). One exported function per
// use case, named exactly as in API.md. Business logic lives in the use cases; this file only wires them to a transport.

import { setGlobalOptions } from 'firebase-functions/v2';
import { onDocumentCreated, onDocumentWritten } from 'firebase-functions/v2/firestore';
import { onRequest } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import { createDeps } from './app/createDeps.js';
import { findUseCase } from './app/registry.js';
import type { AnyUseCase } from './app/UseCase.js';
import { FUNCTION_SECRETS } from './config/params.js';
import { FUNCTIONS_REGION } from './config/region.js';
import { handleAppStoreNotification } from './http/appStoreHandler.js';
import { defineCallable } from './http/callable.js';
import { handleIcs } from './http/icsHandler.js';
import { keyedHash } from './lib/crypto.js';
import { clientIpFrom } from './lib/clientIp.js';
import type { BookingDoc } from './lib/docs.js';
import { runReminders } from './jobs/sendReminders.js';
import { runCleanup } from './jobs/cleanup.js';
import { handleBookingWritten } from './triggers/handleBookingWritten.js';
import { handleInboxItemCreated } from './triggers/handleInboxItemCreated.js';

setGlobalOptions({ region: FUNCTIONS_REGION, maxInstances: 20 });

function useCase(name: string): AnyUseCase {
  const found = findUseCase(name);
  if (!found) throw new Error(`unknown use case ${name}`);
  return found;
}

// MARK: - Public and token functions (the web booking app)

export const getPublicPage = defineCallable(useCase('getPublicPage'));
export const getSlots = defineCallable(useCase('getSlots'));
export const holdSlot = defineCallable(useCase('holdSlot'));
export const getHold = defineCallable(useCase('getHold'));
export const sendEmailCode = defineCallable(useCase('sendEmailCode'));
export const verifyEmailCode = defineCallable(useCase('verifyEmailCode'));
export const createBooking = defineCallable(useCase('createBooking'));
export const findBookings = defineCallable(useCase('findBookings'));
export const joinWaitlist = defineCallable(useCase('joinWaitlist'));
export const getBooking = defineCallable(useCase('getBooking'));
export const confirmPresence = defineCallable(useCase('confirmPresence'));
export const reportLate = defineCallable(useCase('reportLate'));
export const cancelBooking = defineCallable(useCase('cancelBooking'));
export const rescheduleBooking = defineCallable(useCase('rescheduleBooking'));
export const requestReschedule = defineCallable(useCase('requestReschedule'));
export const rebook = defineCallable(useCase('rebook'));
export const getFormContext = defineCallable(useCase('getFormContext'));
export const submitSealed = defineCallable(useCase('submitSealed'), { memory: '512MiB' });
export const getPortal = defineCallable(useCase('getPortal'));
export const forgetDevice = defineCallable(useCase('forgetDevice'));

// MARK: - Owner functions (the iPhone app)

export const ensureAccount = defineCallable(useCase('ensureAccount'));
export const reserveRegistration = defineCallable(useCase('reserveRegistration'));
export const reserveRegistrations = defineCallable(useCase('reserveRegistrations'));
export const syncPlan = defineCallable(useCase('syncPlan'));
export const isSlugAvailable = defineCallable(useCase('isSlugAvailable'));
export const claimSlug = defineCallable(useCase('claimSlug'));
export const publishProfile = defineCallable(useCase('publishProfile'));
export const publishAvailability = defineCallable(useCase('publishAvailability'));
export const updateInboxKey = defineCallable(useCase('updateInboxKey'));
export const respondBookingRequest = defineCallable(useCase('respondBookingRequest'));
export const respondRescheduleRequest = defineCallable(useCase('respondRescheduleRequest'));
export const cancelBookingByOwner = defineCallable(useCase('cancelBookingByOwner'));
export const moveBookingByOwner = defineCallable(useCase('moveBookingByOwner'));
export const suggestBookingTime = defineCallable(useCase('suggestBookingTime'));
export const mintManageLink = defineCallable(useCase('mintManageLink'));
export const registerManualBooking = defineCallable(useCase('registerManualBooking'));
export const offerWaitlistSlot = defineCallable(useCase('offerWaitlistSlot'));
export const removeWaitlistEntry = defineCallable(useCase('removeWaitlistEntry'));
export const markNoShow = defineCallable(useCase('markNoShow'));
export const setOnlineBookingStopped = defineCallable(useCase('setOnlineBookingStopped'));
export const publishPortal = defineCallable(useCase('publishPortal'));
export const getMailboxItem = defineCallable(useCase('getMailboxItem'), { memory: '512MiB' });
export const acknowledgeMailboxItem = defineCallable(useCase('acknowledgeMailboxItem'));
export const registerDevice = defineCallable(useCase('registerDevice'));
export const unregisterDevice = defineCallable(useCase('unregisterDevice'));
export const deleteClientServerData = defineCallable(useCase('deleteClientServerData'), { timeoutSeconds: 300 });
export const deleteAccount = defineCallable(useCase('deleteAccount'), { timeoutSeconds: 540 });

// MARK: - Plain HTTPS

/** `GET getIcs?token=&locale=`: the calendar file of a booking (API.md section 5.17). */
export const getIcs = onRequest({ cors: false, secrets: FUNCTION_SECRETS, memory: '256MiB' }, async (request, response) => {
  if (request.method !== 'GET') {
    response.status(405).end();
    return;
  }
  const deps = createDeps();
  const forwarded = request.headers['x-forwarded-for'];
  const ip = clientIpFrom(Array.isArray(forwarded) ? forwarded.join(',') : forwarded, request.socket.remoteAddress, deps.settings.trustedProxyHops);
  const result = await handleIcs(deps, request.query, keyedHash(deps.pepper, 'ip', ip));
  response.status(result.status).set(result.headers).send(result.body);
});

/** App Store Server Notifications V2 (docs/11 section 3). Apple POSTs `{ "signedPayload": "<JWS>" }`. */
export const appStoreNotifications = onRequest({ cors: false, secrets: FUNCTION_SECRETS }, async (request, response) => {
  if (request.method !== 'POST') {
    response.status(405).end();
    return;
  }
  const body = request.body as { signedPayload?: unknown } | undefined;
  const status = await handleAppStoreNotification(createDeps(), body?.signedPayload);
  response.status(status).end();
});

// MARK: - Triggers

export const onBookingWritten = onDocumentWritten(
  { document: 'bookings/{bookingId}', secrets: FUNCTION_SECRETS },
  async (event) => {
    const change = event.data;
    if (!change) return;
    const before = change.before.exists ? (change.before.data() as BookingDoc) : undefined;
    const after = change.after.exists ? (change.after.data() as BookingDoc) : undefined;
    await handleBookingWritten(createDeps(), event.params.bookingId, before, after);
  }
);

export const onInboxItemCreated = onDocumentCreated(
  { document: 'inbox/{ownerUid}/items/{itemId}', secrets: FUNCTION_SECRETS },
  async (event) => {
    await handleInboxItemCreated(createDeps(), event.params.ownerUid, event.params.itemId);
  }
);

// MARK: - Scheduled jobs

export const cleanupJob = onSchedule(
  { schedule: 'every 10 minutes', timeoutSeconds: 540, secrets: FUNCTION_SECRETS },
  async () => {
    await runCleanup(createDeps());
  }
);

/** Does nothing unless `WHATSAPP_AUTOMATION` is on (D31). */
export const sendReminders = onSchedule(
  { schedule: 'every 5 minutes', timeoutSeconds: 300, secrets: FUNCTION_SECRETS },
  async () => {
    await runReminders(createDeps());
  }
);
