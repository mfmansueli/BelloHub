// The typed API: one method per function of API.md section 5 that the page calls. Components and the booking
// machine depend on this interface and never on `fetch`, so tests inject a fake. Every call is a POST with the
// request in the body (callable protocol, transport.ts), so a token never appears in a URL (docs/06 section 5).
//
// The token pages need more than `getBooking` / `getPortal` return (her languages, zone, currency, photo), so
// those methods also fetch her public page by slug, once per slug, and hand the screens one composed view.

import { createTransport, type Transport } from './transport';
import {
  bookingView,
  formContext,
  parseBookingOutcome,
  parseCancelled,
  parseConfirmed,
  parseFound,
  parseHold,
  parseOfferedHold,
  parseLate,
  parseMoved,
  parseProof,
  parsePublicPage,
  parseRequested,
  parseSendCode,
  parseSlots,
  parseWireBooking,
  parseWireFormContext,
  parseWirePortal,
  portalView,
} from './parse';
import { ApiError } from './errors';
import type {
  BookingOutcome,
  BookingView,
  CancelRequest,
  CreateBookingRequest,
  FindBookingsRequest,
  FormContext,
  FoundBooking,
  HoldRequest,
  HoldResponse,
  LateResponse,
  MovedResponse,
  OfferedHold,
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
  WaitlistRequest,
} from './types';
import { config } from '../lib/config';

export interface Api {
  /** Her public page, one request per slug; a failure is forgotten so a retry asks again. */
  getPublicPage(slug: string): Promise<PublicProfile>;
  forgetPublicPage(slug: string): void;
  getSlots(query: SlotQuery): Promise<SlotsResponse>;
  /** Throws `slotTaken` or `paused` when the hold is not granted. */
  holdSlot(request: HoldRequest): Promise<HoldResponse>;
  /** The waiting-list offer behind `?offer=<holdKey>`; throws `notFound` or `expired` when it is gone. */
  getHold(slug: string, holdKey: string): Promise<OfferedHold>;
  sendEmailCode(request: SendEmailCodeRequest): Promise<SendCodeResponse>;
  /** Returns the single-use proof for `verification: { method: 'email', proof }`. */
  verifyEmailCode(email: string, code: string): Promise<string>;
  createBooking(request: CreateBookingRequest): Promise<BookingOutcome>;
  /** "Forget this device": the server deletes the trusted-device token (5.18); the same answer for an unknown one. */
  forgetDevice(token: string): Promise<void>;
  joinWaitlist(request: WaitlistRequest): Promise<void>;
  findBookings(request: FindBookingsRequest): Promise<FoundBooking[]>;
  getBooking(token: string): Promise<BookingView>;
  confirmPresence(token: string): Promise<string>;
  reportLate(token: string, minutes: number): Promise<LateResponse>;
  /** Direct mode only; throws `slotTaken` when the time went meanwhile. */
  rescheduleBooking(request: RescheduleDirect): Promise<MovedResponse>;
  /** Request mode only; throws `slotTaken` when the time went meanwhile. */
  requestReschedule(request: RescheduleAsk): Promise<void>;
  cancelBooking(request: CancelRequest): Promise<{ isLateCancellation: boolean }>;
  rebook(request: RebookRequest): Promise<BookingOutcome>;
  getPortal(token: string): Promise<PortalView>;
  /** The booking, her profile and the published form (absent when she published none) in one context. */
  getFormContext(token: string): Promise<FormContext>;
  submitSealed(token: string, envelope: SealedEnvelope): Promise<void>;
}

export function createApi(transport: Transport): Api {
  const pages = new Map<string, Promise<PublicProfile>>();

  const getPublicPage = (slug: string): Promise<PublicProfile> => {
    let promise = pages.get(slug);
    if (promise === undefined) {
      promise = transport.call('getPublicPage', { slug }).then(parsePublicPage);
      pages.set(slug, promise);
      promise.catch(() => {
        pages.delete(slug);
      });
    }
    return promise;
  };

  const getBooking = async (token: string): Promise<BookingView> => {
    const wire = parseWireBooking(await transport.call('getBooking', { token }));
    const profile = await getPublicPage(wire.slug);
    return bookingView(wire, profile);
  };

  return {
    getPublicPage,
    forgetPublicPage: (slug) => {
      pages.delete(slug);
    },
    getSlots: async (query) => parseSlots(await transport.call('getSlots', query)),
    holdSlot: async (request) => parseHold(await transport.call('holdSlot', request)),
    getHold: async (slug, holdKey) => parseOfferedHold(await transport.call('getHold', { slug, holdKey })),
    sendEmailCode: async (request) => parseSendCode(await transport.call('sendEmailCode', request)),
    verifyEmailCode: async (email, code) => parseProof(await transport.call('verifyEmailCode', { email, code })),
    createBooking: async (request) => parseBookingOutcome(await transport.call('createBooking', request)),
    forgetDevice: async (token) => {
      await transport.call('forgetDevice', { token });
    },

    joinWaitlist: async (request) => {
      await transport.call('joinWaitlist', request);
    },

    findBookings: async (request) => parseFound(await transport.call('findBookings', request)),
    getBooking,
    confirmPresence: async (token) => parseConfirmed(await transport.call('confirmPresence', { token })),
    reportLate: async (token, minutes) => parseLate(await transport.call('reportLate', { token, minutes })),
    rescheduleBooking: async (request) => parseMoved(await transport.call('rescheduleBooking', request)),
    requestReschedule: async (request) => {
      parseRequested(await transport.call('requestReschedule', request));
    },
    cancelBooking: async (request) => parseCancelled(await transport.call('cancelBooking', request)),
    rebook: async (request) => parseBookingOutcome(await transport.call('rebook', request)),

    getPortal: async (token) => {
      const wire = parseWirePortal(await transport.call('getPortal', { token }));
      return portalView(wire, await getPublicPage(wire.slug));
    },

    getFormContext: async (token) => {
      const booking = await getBooking(token);
      const profile = await getPublicPage(booking.slug);
      let form = null;
      try {
        form = parseWireFormContext(await transport.call('getFormContext', { token }));
      } catch (error) {
        // No health form published: the check-in and the data request still work with the key from her page.
        if (!(error instanceof ApiError && error.code === 'notFound')) throw error;
      }
      return formContext(booking, form, profile.inboxKey);
    },

    submitSealed: async (token, envelope) => {
      await transport.call('submitSealed', { token, envelope });
    },
  };
}

/** The real API for this build (base URL from the build configuration). No browser-side Firebase SDK (D46). */
export const api: Api = createApi(
  createTransport({ baseUrl: config.apiBase }),
);
