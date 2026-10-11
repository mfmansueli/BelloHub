import { randomUUID } from 'node:crypto';

import { createBooking } from '../../src/public/createBooking.js';
import type { BookingDoc } from '../../src/lib/docs.js';
import { refs } from '../../src/lib/store.js';
import type { TestEnv } from './env.js';
import { FRIDAY_10, SERVICE } from './seed.js';
import type { Professional } from './seed.js';

export const ANA = { name: 'Ana Costa', phone: '+5511987654321', email: undefined as string | undefined };
export const BIA = { name: 'Bia Lima', phone: '+5511976543210', email: undefined as string | undefined };

export interface BookingResult {
  status: 'confirmed' | 'pendingApproval';
  bookingId: string;
  manageToken: string;
  startsAt: string;
  endsAt: string;
  timeZoneID: string;
  serviceName: string;
  emailSent: boolean;
  reference?: string;
  requestExpiresAt?: string;
  deviceToken?: string;
  deviceTokenExpiresAt?: string;
}

export type Outcome = BookingResult | { status: 'slotTaken'; alternatives: string[] } | { status: 'paused'; pausedUntil?: string };

export interface BookOptions {
  startsAt?: string;
  serviceId?: string;
  addOnIds?: string[];
  guests?: 0 | 1 | 2;
  client?: { name: string; phone: string; email?: string | undefined };
  idempotencyKey?: string;
  holdKey?: string;
  note?: string;
  slug?: string;
  verification?:
    | { method: 'phone'; idToken: string }
    | { method: 'email'; proof: string }
    | { method: 'device'; token: string }
    | { method: 'whatsapp' };
  ip?: string;
}

/** A createBooking call as the web app would make it, for a phone that has just verified by SMS. */
export async function book(env: TestEnv, pro: Professional, options: BookOptions = {}): Promise<Outcome> {
  const client = options.client ?? ANA;
  const input = {
    slug: options.slug ?? pro.slug,
    serviceId: options.serviceId ?? SERVICE.glowFacial,
    ...(options.addOnIds ? { addOnIds: options.addOnIds } : {}),
    ...(options.guests !== undefined ? { guests: options.guests } : {}),
    startsAt: options.startsAt ?? FRIDAY_10,
    client: { name: client.name, phone: client.phone, ...(client.email ? { email: client.email } : {}), locale: 'pt-BR' },
    ...(options.note ? { note: options.note } : {}),
    verification: options.verification ?? { method: 'phone', idToken: env.phoneToken(client.phone) },
    idempotencyKey: options.idempotencyKey ?? randomUUID(),
    ...(options.holdKey ? { holdKey: options.holdKey } : {})
  };
  return (await env.call(createBooking, input, { ip: options.ip })) as Outcome;
}

export async function bookingDoc(env: TestEnv, bookingId: string): Promise<BookingDoc> {
  const snap = await refs(env.deps.db).booking(bookingId).get();
  return snap.data() as BookingDoc;
}

export function asBooked(outcome: Outcome): BookingResult {
  if (outcome.status !== 'confirmed' && outcome.status !== 'pendingApproval') {
    throw new Error(`expected a booking, got ${outcome.status}`);
  }
  return outcome;
}
