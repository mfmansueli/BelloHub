// The booking flow as a state machine (docs/10 section 3): service -> time -> you -> verify -> [questions] ->
// (confirmed | review). Pure: events in, state out, no DOM and no network, so every branch is a unit test.
// The screens only dispatch events and render the state; the server's answer (confirmed, pendingApproval, paused,
// slotTaken) decides the last step, because the page must never learn whether a phone number is already a client.

import type { BookingResult, FirstVisitAnswers, VerificationProof } from '../../api/types';

export type BookingPhase =
  | 'service'
  | 'time'
  | 'you'
  | 'verify'
  | 'questions'
  | 'confirmed'
  | 'review'
  | 'blocked';

export type Channel = 'sms' | 'email';

/** The non-clinical choices that may sit in sessionStorage so a refresh does not lose them. */
export interface Draft {
  readonly slug: string;
  readonly serviceId: string | null;
  readonly addOnIds: readonly string[];
  readonly guests: number;
  /** One name per guest, as many as `guests`. */
  readonly guestNames: readonly string[];
  readonly startsAt: string | null;
  readonly holdId: string | null;
  readonly holdExpiresAt: string | null;
  readonly name: string;
  readonly phoneCountry: string;
  readonly phoneInput: string;
  readonly email: string;
  readonly channel: Channel;
  /** One key for the whole attempt, so a double tap or a retry cannot book twice. */
  readonly idempotencyKey: string;
}

export interface BookingState {
  readonly phase: BookingPhase;
  readonly draft: Draft;
  /** Held in memory only: a code is never stored. */
  readonly proof: VerificationProof | null;
  readonly proofFor: string | null;
  readonly firstVisit: FirstVisitAnswers;
  readonly result: BookingResult | null;
  /** Shown above the times after "that time was just taken". */
  readonly slotTaken: { readonly nextSlots: readonly string[] } | null;
}

export type BookingEvent =
  /** Tapping a service on the public page: it is selected on the next screen, but she has not continued yet. */
  | { readonly type: 'preselect'; readonly serviceId: string }
  | { readonly type: 'setAddOns'; readonly addOnIds: readonly string[] }
  | { readonly type: 'chooseService'; readonly serviceId: string; readonly addOnIds: readonly string[] }
  | { readonly type: 'setGuests'; readonly guests: number; readonly guestNames: readonly string[] }
  | { readonly type: 'chooseSlot'; readonly startsAt: string; readonly holdId: string | null; readonly holdExpiresAt: string | null }
  | { readonly type: 'slotTaken'; readonly nextSlots: readonly string[] }
  | {
      readonly type: 'setDetails';
      readonly name: string;
      readonly phoneCountry: string;
      readonly phoneInput: string;
      readonly email: string;
    }
  | { readonly type: 'setChannel'; readonly channel: Channel }
  | { readonly type: 'verified'; readonly proof: VerificationProof; readonly target: string }
  | { readonly type: 'setFirstVisit'; readonly answers: FirstVisitAnswers }
  | { readonly type: 'result'; readonly result: BookingResult }
  | { readonly type: 'back' }
  | { readonly type: 'reset' };

export const EMPTY_FIRST_VISIT: FirstVisitAnswers = { heardFrom: null, hadBefore: null, note: '' };

export function newIdempotencyKey(): string {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') return crypto.randomUUID();
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;
}

export function emptyDraft(slug: string, defaultCountry: string, idempotencyKey: string = newIdempotencyKey()): Draft {
  return {
    slug,
    serviceId: null,
    addOnIds: [],
    guests: 0,
    guestNames: [],
    startsAt: null,
    holdId: null,
    holdExpiresAt: null,
    name: '',
    phoneCountry: defaultCountry,
    phoneInput: '',
    email: '',
    channel: 'sms',
    idempotencyKey,
  };
}

export function initialState(draft: Draft): BookingState {
  return { phase: 'service', draft, proof: null, proofFor: null, firstVisit: EMPTY_FIRST_VISIT, result: null, slotTaken: null };
}

const sameSet = (a: readonly string[], b: readonly string[]): boolean => a.length === b.length && a.every((id) => b.includes(id));

/** What a proof was issued for: it is void once the phone or the email changes. */
export function proofTarget(draft: Draft): string {
  return `${draft.channel}|${draft.phoneCountry}|${draft.phoneInput.trim()}|${draft.email.trim().toLowerCase()}`;
}

export function reduce(state: BookingState, event: BookingEvent): BookingState {
  const { draft } = state;
  switch (event.type) {
    case 'preselect': {
      if (draft.serviceId === event.serviceId) return state;
      return {
        ...state,
        phase: 'service',
        draft: { ...draft, serviceId: event.serviceId, addOnIds: [], startsAt: null, holdId: null, holdExpiresAt: null },
      };
    }
    case 'setAddOns': {
      if (sameSet(draft.addOnIds, event.addOnIds)) return state;
      return { ...state, draft: { ...draft, addOnIds: [...event.addOnIds], startsAt: null, holdId: null, holdExpiresAt: null } };
    }
    case 'chooseService': {
      const changed = draft.serviceId !== event.serviceId || !sameSet(draft.addOnIds, event.addOnIds);
      // A different service or add-ons means a different total duration: the chosen time and its hold no longer fit.
      const next: Draft = changed
        ? { ...draft, serviceId: event.serviceId, addOnIds: [...event.addOnIds], startsAt: null, holdId: null, holdExpiresAt: null }
        : draft;
      return { ...state, phase: 'time', draft: next, slotTaken: null };
    }
    case 'setGuests': {
      const changed = draft.guests !== event.guests;
      const names = Array.from({ length: event.guests }, (_, index) => event.guestNames[index] ?? '');
      return {
        ...state,
        draft: {
          ...draft,
          guests: event.guests,
          guestNames: names,
          ...(changed ? { startsAt: null, holdId: null, holdExpiresAt: null } : {}),
        },
      };
    }
    case 'chooseSlot':
      return {
        ...state,
        phase: 'you',
        slotTaken: null,
        draft: { ...draft, startsAt: event.startsAt, holdId: event.holdId, holdExpiresAt: event.holdExpiresAt },
      };
    case 'slotTaken':
      return {
        ...state,
        phase: 'time',
        slotTaken: { nextSlots: event.nextSlots },
        draft: { ...draft, startsAt: null, holdId: null, holdExpiresAt: null },
      };
    case 'setDetails': {
      const nextDraft: Draft = {
        ...draft,
        name: event.name,
        phoneCountry: event.phoneCountry,
        phoneInput: event.phoneInput,
        email: event.email,
      };
      const stale = state.proof !== null && state.proofFor !== proofTarget(nextDraft);
      return { ...state, draft: nextDraft, ...(stale ? { proof: null, proofFor: null } : {}) };
    }
    case 'setChannel': {
      const nextDraft: Draft = { ...draft, channel: event.channel };
      const stale = state.proof !== null && state.proofFor !== proofTarget(nextDraft);
      return { ...state, draft: nextDraft, ...(stale ? { proof: null, proofFor: null } : {}) };
    }
    case 'verified':
      return { ...state, phase: 'questions', proof: event.proof, proofFor: event.target };
    case 'setFirstVisit':
      return { ...state, firstVisit: event.answers };
    case 'result': {
      const result = event.result;
      switch (result.status) {
        case 'confirmed':
          return { ...state, phase: 'confirmed', result };
        case 'pendingApproval':
          return { ...state, phase: 'review', result };
        case 'paused':
          return { ...state, phase: 'blocked', result };
        case 'slotTaken':
          return reduce(state, { type: 'slotTaken', nextSlots: result.nextSlots });
      }
      return state;
    }
    case 'back':
      return { ...state, phase: backOf(state.phase) };
    case 'reset':
      return initialState(emptyDraft(draft.slug, draft.phoneCountry));
  }
}

function backOf(phase: BookingPhase): BookingPhase {
  switch (phase) {
    case 'time':
      return 'service';
    case 'you':
      return 'time';
    case 'verify':
      return 'you';
    case 'questions':
      return 'you';
    default:
      return phase;
  }
}

/** The five segments of the progress bar (docs/10 section 3). */
export const FLOW_STEPS = 5;

export function stepNumber(phase: BookingPhase): number {
  switch (phase) {
    case 'service':
      return 1;
    case 'time':
      return 2;
    case 'you':
      return 3;
    case 'verify':
      return 4;
    default:
      return 5;
  }
}

export type FlowStep = 'service' | 'time' | 'you' | 'verify' | 'questions' | 'booked' | 'review';

/** The step a person may be on, given what she has already chosen. Returns where to send her when she is too early. */
export function allowedStep(step: FlowStep, state: BookingState): FlowStep {
  const { draft } = state;
  const hasService = draft.serviceId !== null;
  const hasSlot = draft.startsAt !== null;
  const hasDetails = draft.name.trim() !== '' && draft.phoneInput.trim() !== '';
  switch (step) {
    case 'service':
      return 'service';
    case 'time':
      return hasService ? 'time' : 'service';
    case 'you':
      return !hasService ? 'service' : hasSlot ? 'you' : 'time';
    case 'verify':
      return !hasService ? 'service' : !hasSlot ? 'time' : hasDetails ? 'verify' : 'you';
    case 'questions':
      return state.proof !== null ? 'questions' : !hasService ? 'service' : !hasSlot ? 'time' : hasDetails ? 'verify' : 'you';
    case 'booked':
      return state.result?.status === 'confirmed' ? 'booked' : 'service';
    case 'review':
      return state.result?.status === 'pendingApproval' || state.result?.status === 'paused' ? 'review' : 'service';
  }
}
