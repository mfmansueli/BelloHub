// The typed API: one method per Cloud Function of docs/11 section 3 that the page calls. Components and the
// booking machine depend on this interface and never on `fetch`, so tests inject a fake and the coordinator can
// reconcile it with firebase/functions/API.md in one place. Token-bearing calls are POSTs so a token never
// appears in a URL (docs/06 section 5: tokens are never logged).

import { createTransport, type Transport } from './transport';
import {
  parseBookingResult,
  parseBookingView,
  parseFormContext,
  parseFound,
  parseHold,
  parsePortal,
  parsePublicProfile,
  parseSendCode,
  parseSlots,
  parseToken,
} from './parse';
import type {
  BookingResult,
  BookingView,
  CancelRequest,
  CancelResponse,
  CreateBookingRequest,
  FormContext,
  FoundBooking,
  HoldRequest,
  HoldResponse,
  LateResponse,
  PortalView,
  PublicProfile,
  RebookRequest,
  RescheduleAsk,
  RescheduleDirect,
  SealedEnvelope,
  SendCodeResponse,
  SendEmailCodeRequest,
  SlotQuery,
  SlotsResponse,
  VerificationProof,
  WaitlistRequest,
} from './types';
import { config } from '../lib/config';
import { getAppCheckToken } from './appcheck';

export interface Api {
  getPublicPage(slug: string): Promise<PublicProfile>;
  getSlots(query: SlotQuery): Promise<SlotsResponse>;
  holdSlot(request: HoldRequest): Promise<HoldResponse>;
  sendEmailCode(request: SendEmailCodeRequest): Promise<SendCodeResponse>;
  verifyEmailCode(email: string, code: string): Promise<string>;
  /** Only used when `VITE_SMS_VERIFIER=api` (tests and local dev); production uses Firebase Auth. */
  sendSmsCode(phone: string, slug: string): Promise<SendCodeResponse>;
  verifySmsCode(phone: string, code: string): Promise<string>;
  createBooking(request: CreateBookingRequest): Promise<BookingResult>;
  joinWaitlist(request: WaitlistRequest): Promise<void>;
  findBookings(slug: string, verification: VerificationProof): Promise<FoundBooking[]>;
  getBooking(token: string): Promise<BookingView>;
  confirmPresence(token: string): Promise<void>;
  reportLate(token: string, minutes: number): Promise<LateResponse>;
  rescheduleBooking(request: RescheduleDirect): Promise<BookingView>;
  requestReschedule(request: RescheduleAsk): Promise<BookingView>;
  cancelBooking(request: CancelRequest): Promise<CancelResponse>;
  rebook(request: RebookRequest): Promise<BookingResult>;
  getPortal(token: string): Promise<PortalView>;
  getFormContext(token: string): Promise<FormContext>;
  submitSealed(token: string, envelope: SealedEnvelope): Promise<void>;
}

export function createApi(transport: Transport): Api {
  return {
    getPublicPage: async (slug) => parsePublicProfile(await transport.get('getPublicPage', { slug })),

    getSlots: async (query) =>
      parseSlots(
        'token' in query
          ? await transport.post('getSlots', query)
          : await transport.get('getSlots', {
              slug: query.slug,
              serviceId: query.serviceId,
              addOns: query.addOnIds,
              guests: query.guests,
              from: query.from,
              to: query.to,
            }),
      ),

    holdSlot: async (request) => parseHold(await transport.post('holdSlot', request)),
    sendEmailCode: async (request) => parseSendCode(await transport.post('sendEmailCode', request)),
    verifyEmailCode: async (email, code) => parseToken(await transport.post('verifyEmailCode', { email, code })),
    sendSmsCode: async (phone, slug) => parseSendCode(await transport.post('sendSmsCode', { phone, slug })),
    verifySmsCode: async (phone, code) => parseToken(await transport.post('verifySmsCode', { phone, code })),
    createBooking: async (request) => parseBookingResult(await transport.post('createBooking', request)),

    joinWaitlist: async (request) => {
      await transport.post('joinWaitlist', request);
    },

    findBookings: async (slug, verification) => parseFound(await transport.post('findBookings', { slug, verification })),
    getBooking: async (token) => parseBookingView(await transport.post('getBooking', { token })),

    confirmPresence: async (token) => {
      await transport.post('confirmPresence', { token });
    },

    reportLate: async (token, minutes) => {
      const raw = (await transport.post('reportLate', { token, minutes })) as Partial<LateResponse> | null;
      return { lateByMinutes: raw?.lateByMinutes ?? minutes, ...(raw?.proReply === undefined ? {} : { proReply: raw.proReply }) };
    },

    rescheduleBooking: async (request) => parseBookingView(await transport.post('rescheduleBooking', request)),
    requestReschedule: async (request) => parseBookingView(await transport.post('requestReschedule', request)),

    cancelBooking: async (request) => {
      const raw = (await transport.post('cancelBooking', request)) as { booking?: unknown; countedAsLate?: unknown } | null;
      return { booking: parseBookingView(raw?.booking), countedAsLate: raw?.countedAsLate === true };
    },

    rebook: async (request) => parseBookingResult(await transport.post('rebook', request)),
    getPortal: async (token) => parsePortal(await transport.post('getPortal', { token })),
    getFormContext: async (token) => parseFormContext(await transport.post('getFormContext', { token })),

    submitSealed: async (token, envelope) => {
      await transport.post('submitSealed', { token, envelope });
    },
  };
}

/** The real API for this build (base URL and App Check from the build configuration). */
export const api: Api = createApi(
  createTransport({ baseUrl: config.apiBase, appCheckToken: () => getAppCheckToken(config) }),
);
