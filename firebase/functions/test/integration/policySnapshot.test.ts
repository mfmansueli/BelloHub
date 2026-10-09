import { beforeEach, describe, expect, it } from 'vitest';

import type { ContactDoc } from '../../src/lib/docs.js';
import { refs } from '../../src/lib/store.js';
import { publishAvailability } from '../../src/owner/publishAvailability.js';
import { publishProfile } from '../../src/owner/publishProfile.js';
import { cancelBooking } from '../../src/token/cancelBooking.js';
import { getBooking } from '../../src/token/getBooking.js';
import { ANA, asBooked, BIA, book, bookingDoc } from '../support/booking.js';
import { createTestEnv, resetEmulators } from '../support/env.js';
import { mariaAvailability, mariaProfile, ownerContext, seedProfessional } from '../support/seed.js';
import type { Professional } from '../support/seed.js';

// D47: cancellation and no-show policies apply from the moment of booking. Each booking keeps the policy, the rule
// texts and the "late cancellation counts" setting it was made under; a later publish changes only new bookings.

const env = createTestEnv();
let pro: Professional;
const HOUR = 3_600_000;
/** Saturday 2026-10-03 10:00 in Sao Paulo: 46 hours after "now". */
const START = '2026-10-03T13:00:00.000Z';
const LATER = '2026-10-03T17:00:00.000Z';

const POLICY_A = {
  freeWindowHours: 24 as const,
  clientCanReschedule: true,
  maxReschedules: 2,
  afterWindowCancel: 'allow' as const,
  afterWindowReschedule: 'request' as const,
  askConfirmation: true,
  graceMinutes: 15
};
const RULES_A = { 'pt-BR': 'Regras A: alteracoes gratis ate 24 horas antes.', en: 'Rules A: changes are free up to 24 hours before.' };
const POLICY_B = { ...POLICY_A, freeWindowHours: 48 as const, afterWindowCancel: 'message' as const, maxReschedules: 0 };
const RULES_B = { 'pt-BR': 'Regras B: alteracoes gratis ate 48 horas antes.', en: 'Rules B: changes are free up to 48 hours before.' };

beforeEach(async () => {
  await resetEmulators(env);
  env.clock.set(Date.UTC(2026, 9, 1, 15, 0));
  pro = await seedProfessional(env, {
    profile: { policy: POLICY_A, rulesText: RULES_A },
    availability: { noShow: { isOn: true, limit: 3, action: 'tell', lateCancelCounts: false, countingMonths: 12 } }
  });
});

async function publishB(): Promise<void> {
  await env.call(publishProfile, { profile: mariaProfile(pro.inboxKey, { policy: POLICY_B, rulesText: RULES_B }) }, ownerContext(pro.uid));
  await env.call(
    publishAvailability,
    mariaAvailability({ noShow: { isOn: true, limit: 3, action: 'tell', lateCancelCounts: true, countingMonths: 12 } }),
    ownerContext(pro.uid)
  );
}

interface View {
  policy: { freeWindowHours: number; afterWindowCancel: string; maxReschedules?: number };
  rulesText: Record<string, string>;
  lateCancelCounts: boolean;
  actions: { cancel: string; reschedule: string };
}

const view = async (token: string): Promise<View> => (await env.call(getBooking, { token })) as View;

describe('the policy snapshot (D47)', () => {
  it('keeps policy A on a booking made under A after B is published, and gives a new booking B', async () => {
    const first = asBooked(await book(env, pro, { startsAt: START }));

    await publishB();
    const second = asBooked(await book(env, pro, { client: BIA, startsAt: LATER }));

    const underA = await view(first.manageToken);
    expect(underA.policy).toEqual(POLICY_A);
    expect(underA.rulesText).toEqual(RULES_A);
    expect(underA.lateCancelCounts).toBe(false);

    const underB = await view(second.manageToken);
    expect(underB.policy).toEqual(POLICY_B);
    expect(underB.rulesText).toEqual(RULES_B);
    expect(underB.lateCancelCounts).toBe(true);

    const storedA = await bookingDoc(env, first.bookingId);
    expect(storedA.policy).toEqual(POLICY_A);
    expect(storedA.rulesText).toEqual(RULES_A);
    expect(storedA.noShowPolicy).toEqual({ isOn: true, lateCancelCounts: false });
  });

  it('evaluates what the client may do by the rules of booking time, not the current page', async () => {
    const first = asBooked(await book(env, pro, { startsAt: START }));
    await publishB();
    const second = asBooked(await book(env, pro, { client: BIA, startsAt: LATER }));

    // 36 hours before the first (40 before the second): inside A's 24 h window, outside B's 48 h window.
    env.clock.set(Date.parse(START) - 36 * HOUR);

    expect((await view(first.manageToken)).actions).toMatchObject({ cancel: 'free', reschedule: 'direct' });
    expect((await view(second.manageToken)).actions).toMatchObject({ cancel: 'askByMessage', reschedule: 'message' });
    await expect(env.call(cancelBooking, { token: second.manageToken })).rejects.toMatchObject({ code: 'NOT_ALLOWED' });
    expect(await env.call(cancelBooking, { token: first.manageToken })).toEqual({ status: 'cancelled', isLateCancellation: false });
  });

  it('records a late cancellation as a mark only when the no-show policy of booking time counted it', async () => {
    const first = asBooked(await book(env, pro, { startsAt: START }));
    await env.call(
      publishAvailability,
      mariaAvailability({ noShow: { isOn: true, limit: 3, action: 'tell', lateCancelCounts: true, countingMonths: 12 } }),
      ownerContext(pro.uid)
    );
    const second = asBooked(await book(env, pro, { client: BIA, startsAt: LATER }));

    env.clock.set(Date.parse(START) - 10 * HOUR);
    await env.call(cancelBooking, { token: first.manageToken, acceptLateWarning: true });
    env.clock.set(Date.parse(LATER) - 10 * HOUR);
    await env.call(cancelBooking, { token: second.manageToken, acceptLateWarning: true });

    const marks = async (phoneHash: string) => ((await refs(env.deps.db).contact(pro.uid, phoneHash).get()).data() as ContactDoc | undefined)?.marks ?? [];
    expect((await bookingDoc(env, first.bookingId)).isLateCancellation).toBe(true);
    expect(await marks((await bookingDoc(env, first.bookingId)).phoneHash)).toEqual([]);
    expect(await marks((await bookingDoc(env, second.bookingId)).phoneHash)).toMatchObject([{ kind: 'lateCancel' }]);
    expect(ANA.phone).not.toBe(BIA.phone);
  });

  it('falls back to the page texts for a booking stored before the snapshot existed', async () => {
    const first = asBooked(await book(env, pro, { startsAt: START }));
    await refs(env.deps.db).booking(first.bookingId).update({ rulesText: null, noShowPolicy: null });
    await env.deps.db.runTransaction(async (tx) => {
      const ref = refs(env.deps.db).booking(first.bookingId);
      const data = (await tx.get(ref)).data() ?? {};
      delete data.rulesText;
      delete data.noShowPolicy;
      tx.set(ref, data);
    });
    await publishB();

    const legacy = await view(first.manageToken);
    expect(legacy.policy).toEqual(POLICY_A);
    expect(legacy.rulesText).toEqual(RULES_B);
    expect(legacy.lateCancelCounts).toBe(false);
  });
});
