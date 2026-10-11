import type { PublicProfileOutput } from '../contracts/profile.js';
import type { PublicProfileDoc } from './docs.js';
import { ms } from './store.js';

/** The stored profile as the API returns it: Timestamps become ISO instants. */
export function profileView(doc: PublicProfileDoc): PublicProfileOutput {
  const { booking, updatedAt, ...rest } = doc;
  const { pausedUntil, ...bookingRest } = booking;
  return {
    ...rest,
    booking: { ...bookingRest, ...(pausedUntil ? { pausedUntil: new Date(ms(pausedUntil)).toISOString() } : {}) },
    updatedAt: new Date(ms(updatedAt)).toISOString()
  };
}
