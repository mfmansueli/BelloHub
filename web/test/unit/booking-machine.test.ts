import { describe, expect, it } from 'vitest';

import type { BookingResult, PublicAddOn, PublicService } from '../../src/api/types';
import {
  allowedStep,
  emptyDraft,
  initialState,
  proofTarget,
  reduce,
  stepNumber,
  type BookingEvent,
  type BookingState,
} from '../../src/app/booking/machine';
import { parseDraft, serializeDraft } from '../../src/app/booking/store';
import { selectedAddOns, servicePrice, totals } from '../../src/app/booking/summary';

const KEY = 'fixed-key';

function start(): BookingState {
  return initialState(emptyDraft('maria', 'BR', KEY));
}

function run(events: BookingEvent[], from: BookingState = start()): BookingState {
  return events.reduce(reduce, from);
}

const slot: BookingEvent = { type: 'chooseSlot', startsAt: '2026-10-01T18:00:00Z', holdId: 'h1', holdExpiresAt: '2026-10-01T10:05:00Z' };
const details: BookingEvent = { type: 'setDetails', name: 'Helena Duarte', phoneCountry: 'BR', phoneInput: '11 98765 4321', email: '' };
const proof = { kind: 'sms', idToken: 'tok' } as const;

describe('booking state machine (docs/10 section 3)', () => {
  it('walks service -> time -> you -> verify -> questions -> confirmed', () => {
    let state = run([{ type: 'chooseService', serviceId: 'brazilian', addOnIds: [] }]);
    expect(state.phase).toBe('time');
    state = run([slot], state);
    expect(state.phase).toBe('you');
    state = run([details], state);
    expect(state.draft.name).toBe('Helena Duarte');
    state = run([{ type: 'verified', proof, target: proofTarget(state.draft) }], state);
    expect(state.phase).toBe('questions');
    const confirmed: BookingResult = { status: 'confirmed', manageToken: 'abc', booking: {} as never };
    state = run([{ type: 'result', result: confirmed }], state);
    expect(state.phase).toBe('confirmed');
  });

  it('keeps the chosen time when she re-picks the same service and add-ons', () => {
    let state = run([{ type: 'chooseService', serviceId: 'a', addOnIds: ['x', 'y'] }, slot]);
    state = run([{ type: 'chooseService', serviceId: 'a', addOnIds: ['y', 'x'] }], state);
    expect(state.draft.startsAt).toBe('2026-10-01T18:00:00Z');
    expect(state.draft.holdId).toBe('h1');
  });

  it('drops the time and the hold when the service, the add-ons or the guests change (the duration changed)', () => {
    const base = run([{ type: 'chooseService', serviceId: 'a', addOnIds: [] }, slot]);
    for (const event of [
      { type: 'chooseService', serviceId: 'b', addOnIds: [] },
      { type: 'chooseService', serviceId: 'a', addOnIds: ['x'] },
      { type: 'setGuests', guests: 1, guestNames: ['Ana'] },
    ] as BookingEvent[]) {
      const next = run([event], base);
      expect(next.draft.startsAt).toBeNull();
      expect(next.draft.holdId).toBeNull();
    }
  });

  it('keeps one name per guest and forgets them when she goes back to coming alone', () => {
    let state = run([{ type: 'setGuests', guests: 2, guestNames: ['Ana'] }]);
    expect(state.draft.guestNames).toEqual(['Ana', '']);
    state = run([{ type: 'setGuests', guests: 0, guestNames: ['Ana'] }], state);
    expect(state.draft.guestNames).toEqual([]);
  });

  it('a verification proof is void as soon as the phone, the email or the channel changes, but not the name', () => {
    let state = run([{ type: 'chooseService', serviceId: 'a', addOnIds: [] }, slot, details]);
    state = run([{ type: 'verified', proof, target: proofTarget(state.draft) }], state);
    const renamed = run([{ ...details, name: 'Helena D.' }], state);
    expect(renamed.proof).not.toBeNull();
    const rephoned = run([{ ...details, phoneInput: '11 91111 2222' }], state);
    expect(rephoned.proof).toBeNull();
    const withEmail = run([{ ...details, email: 'h@example.com' }], state);
    expect(withEmail.proof).toBeNull();
    const otherChannel = run([{ type: 'setChannel', channel: 'email' }], state);
    expect(otherChannel.proof).toBeNull();
  });

  it('maps each answer of the server to a screen', () => {
    const base = run([{ type: 'chooseService', serviceId: 'a', addOnIds: [] }, slot, details]);
    expect(run([{ type: 'result', result: { status: 'pendingApproval', reason: 'newClient' } }], base).phase).toBe('review');
    expect(run([{ type: 'result', result: { status: 'paused', scope: 'client' } }], base).phase).toBe('blocked');
    const taken = run([{ type: 'result', result: { status: 'slotTaken', nextSlots: ['2026-10-01T19:00:00Z'] } }], base);
    expect(taken.phase).toBe('time');
    expect(taken.slotTaken?.nextSlots).toEqual(['2026-10-01T19:00:00Z']);
    expect(taken.draft.startsAt).toBeNull();
    expect(taken.draft.holdId).toBeNull();
  });

  it('clears the "just taken" notice once she chooses a time again', () => {
    let state = run([{ type: 'chooseService', serviceId: 'a', addOnIds: [] }, { type: 'slotTaken', nextSlots: [] }]);
    expect(state.slotTaken).not.toBeNull();
    state = run([slot], state);
    expect(state.slotTaken).toBeNull();
  });

  it('back goes one step and re-asks nothing already known', () => {
    expect(run([{ type: 'back' }], { ...start(), phase: 'time' }).phase).toBe('service');
    expect(run([{ type: 'back' }], { ...start(), phase: 'you' }).phase).toBe('time');
    expect(run([{ type: 'back' }], { ...start(), phase: 'verify' }).phase).toBe('you');
    expect(run([{ type: 'back' }], { ...start(), phase: 'questions' }).phase).toBe('you');
  });

  it('reset starts a clean attempt with a new idempotency key', () => {
    const done = run([{ type: 'chooseService', serviceId: 'a', addOnIds: [] }, slot, details]);
    const fresh = run([{ type: 'reset' }], done);
    expect(fresh.draft.serviceId).toBeNull();
    expect(fresh.draft.name).toBe('');
    expect(fresh.draft.idempotencyKey).not.toBe(KEY);
    expect(fresh.draft.phoneCountry).toBe('BR');
  });

  it('numbers the five progress segments', () => {
    expect(['service', 'time', 'you', 'verify', 'questions'].map((p) => stepNumber(p as never))).toEqual([1, 2, 3, 4, 5]);
  });
});

describe('allowedStep: a refresh or a pasted link never lands past what she chose', () => {
  it('sends her back to the first missing piece', () => {
    expect(allowedStep('time', start())).toBe('service');
    expect(allowedStep('you', start())).toBe('service');
    const withService = run([{ type: 'chooseService', serviceId: 'a', addOnIds: [] }]);
    expect(allowedStep('you', withService)).toBe('time');
    expect(allowedStep('verify', withService)).toBe('time');
    const withSlot = run([slot], withService);
    expect(allowedStep('verify', withSlot)).toBe('you');
    const withDetails = run([details], withSlot);
    expect(allowedStep('verify', withDetails)).toBe('verify');
    expect(allowedStep('questions', withDetails)).toBe('verify');
    expect(allowedStep('booked', withDetails)).toBe('service');
    expect(allowedStep('review', withDetails)).toBe('service');
  });

  it('lets her into the questions only with a proof', () => {
    let state = run([{ type: 'chooseService', serviceId: 'a', addOnIds: [] }, slot, details]);
    state = run([{ type: 'verified', proof, target: proofTarget(state.draft) }], state);
    expect(allowedStep('questions', state)).toBe('questions');
  });

  it('shows the review page only after the server asked for one', () => {
    const state = run([{ type: 'result', result: { status: 'pendingApproval', reason: 'noShowLimit' } }]);
    expect(allowedStep('review', state)).toBe('review');
  });
});

describe('the stored draft', () => {
  it('round-trips and never carries a proof, a code or an answer', () => {
    const draft = run([{ type: 'chooseService', serviceId: 'a', addOnIds: ['x'] }, slot, details]).draft;
    const text = serializeDraft(draft);
    expect(parseDraft(text, 'maria', 'BR')).toEqual(draft);
    for (const forbidden of ['proof', 'token', 'code', 'goals', 'note', 'answer']) expect(text).not.toContain(forbidden);
  });

  it('ignores garbage, another page, another version and wrong types', () => {
    const fresh = (text: string | null): string | null => parseDraft(text, 'maria', 'BR').serviceId;
    expect(fresh(null)).toBeNull();
    expect(fresh('not json')).toBeNull();
    expect(fresh('{"v":2,"draft":{"slug":"maria","serviceId":"a"}}')).toBeNull();
    expect(fresh('{"v":1,"draft":{"slug":"other","serviceId":"a"}}')).toBeNull();
    expect(fresh('{"v":1,"draft":{"slug":"maria","serviceId":42}}')).toBeNull();
    expect(parseDraft('{"v":1,"draft":{"slug":"maria","guests":9,"addOnIds":[1,"x"]}}', 'maria', 'BR')).toMatchObject({ guests: 0, addOnIds: ['x'] });
  });
});

describe('time and price of a booking (D19)', () => {
  const glow: PublicService = { id: 'glow', name: 'Glow Facial', durationMinutes: 60, priceDisplay: 'show', priceAmount: 70 };
  const brazilian: PublicService = { id: 'bg', name: 'Brazilian Glow', durationMinutes: 90, priceDisplay: 'show', priceAmount: 120 };
  const deep: PublicService = { id: 'deep', name: 'Deep Cleansing', durationMinutes: 75, priceDisplay: 'startingFrom', priceAmount: 80 };
  const p360: PublicService = { id: 'p360', name: 'Protocol 360', durationMinutes: 120, priceDisplay: 'onRequest' };
  const hidden: PublicService = { id: 'h', name: 'Hidden', durationMinutes: 30, priceDisplay: 'hide', priceAmount: 10 };
  const brow: PublicAddOn = { id: 'brow', name: 'Eyebrow tint', minutes: 15, priceAmount: 20 };
  const led: PublicAddOn = { id: 'led', name: 'LED light', minutes: 15, priceAmount: 25 };
  const mask: PublicAddOn = { id: 'mask', name: 'Hand mask', minutes: 10 };

  it('adds the minutes and the prices of the add-ons (the prototype: 90 min R$120 + tint = 105 min R$140)', () => {
    expect(totals(brazilian, [], 0)).toEqual({ perPersonMinutes: 90, totalMinutes: 90, people: 1, price: { kind: 'amount', amount: 120 } });
    expect(totals(brazilian, [brow], 0)).toMatchObject({ perPersonMinutes: 105, totalMinutes: 105, price: { kind: 'amount', amount: 140 } });
    expect(totals(brazilian, [brow, led, mask], 0)).toMatchObject({ perPersonMinutes: 130, price: { kind: 'amount', amount: 165 } });
  });

  it('puts guests in sequence: the same visit again, back to back', () => {
    const t = totals(brazilian, [brow], 1);
    expect(t).toMatchObject({ perPersonMinutes: 105, totalMinutes: 210, people: 2, price: { kind: 'amount', amount: 280 } });
    expect(totals(glow, [], 2)).toMatchObject({ totalMinutes: 180, people: 3, price: { kind: 'amount', amount: 210 } });
  });

  it('"from" prices stay "from", "on request" and hidden prices never turn into a number', () => {
    expect(totals(deep, [brow], 0).price).toEqual({ kind: 'startingFrom', amount: 100 });
    expect(totals(p360, [brow], 1).price).toEqual({ kind: 'onRequest' });
    expect(totals(hidden, [brow], 0).price).toBeNull();
    expect(servicePrice({ id: 'x', name: 'x', durationMinutes: 10, priceDisplay: 'show' })).toBeNull();
    expect(servicePrice({ id: 'x', name: 'x', durationMinutes: 10, priceDisplay: 'startingFrom' })).toEqual({ kind: 'onRequest' });
  });

  it('selects add-ons in the order she offers them and ignores ids that vanished', () => {
    expect(selectedAddOns([brow, led, mask], ['mask', 'brow', 'gone']).map((a) => a.id)).toEqual(['brow', 'mask']);
  });
});
