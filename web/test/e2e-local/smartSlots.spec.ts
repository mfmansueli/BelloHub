// D56 against the real functions: Maria has a 30-minute visit of her own from 09:35 to 10:05 (published as a busy
// stretch, no name), her buffer is 15 minutes, and Rita books the 75-minute Deep Cleansing. The page offers 10:20,
// anchored right after the visit and its buffer, although the 15-minute grid says 10:15 and 10:30; the times that
// would leave a gap nobody can book wait behind "Show all times", and the anchored one is booked for real.

import { chooseDayAhead, dateKeyIn, expect, open, test } from './support';

const UID = 'demo-maria';
const SLUG = 'maria';
const ZONE = 'America/Sao_Paulo';
const DEEP_CLEANSING = '33333333-3333-4333-8333-333333333333';
const EMAIL_CODE = '123456';
const CLIENT = { name: 'Rita Gomes', phone: '11 97654 3210', email: 'rita@example.com' } as const;
/** Maria works Tuesday to Saturday. */
const WORKING_DAYS = new Set(['Tue', 'Wed', 'Thu', 'Fri', 'Sat']);

/** The first working day at least three days ahead, and how many days ahead it is. */
function targetDay(): { key: string; offset: number } {
  for (let offset = 3; offset < 14; offset += 1) {
    const instant = Date.now() + offset * 86_400_000;
    const weekday = new Intl.DateTimeFormat('en-US', { timeZone: ZONE, weekday: 'short' }).format(new Date(instant));
    if (WORKING_DAYS.has(weekday)) return { key: dateKeyIn(ZONE, instant), offset };
  }
  throw new Error('no working day ahead');
}

/** A São Paulo wall-clock time of `key` as the instant the page uses (São Paulo has no daylight saving: UTC-3). */
function at(key: string, clock: string): string {
  const [hours, minutes] = clock.split(':').map(Number);
  return new Date(Date.parse(`${key}T00:00:00.000Z`) + ((hours ?? 0) + 3) * 3_600_000 + (minutes ?? 0) * 60_000).toISOString();
}

test('a 75-minute service is offered right after a 30-minute visit, at the anchored time, and books', async ({ page, store }) => {
  const { key, offset } = targetDay();
  await store.setBusy(UID, [{ start: at(key, '09:35'), end: at(key, '10:05'), kind: 'appointment' }]);

  await open(page, `/${SLUG}`);
  await page.getByTestId(`service-${DEEP_CLEANSING}`).click();
  await page.getByTestId('continue').click();
  await chooseDayAhead(page, ZONE, offset, offset);

  const anchored = page.getByTestId(`slot-${at(key, '10:20')}`);
  await expect(anchored).toBeVisible();
  await expect(page.getByTestId(`slot-${at(key, '10:15')}`)).toHaveCount(0); // inside the buffer after her visit
  await expect(page.getByTestId(`slot-${at(key, '10:30')}`)).toHaveCount(0); // would leave a 10-minute gap

  // Every free time stays one tap away, and is just as bookable.
  await page.getByTestId('show-all-times').click();
  await expect(page.getByTestId(`slot-${at(key, '10:30')}`)).toBeVisible();
  await expect(page.getByTestId('show-all-times')).toHaveCount(0);

  await anchored.click();
  await page.getByTestId('continue').click();
  await expect(page.getByTestId('name')).toBeVisible();
  await page.getByTestId('name').fill(CLIENT.name);
  await page.getByTestId('phone').fill(CLIENT.phone);
  await page.getByTestId('email').fill(CLIENT.email);
  await page.getByTestId('send-code').click();
  await expect(page.getByTestId('code')).toBeVisible();
  // The countdown starts when the server answered: only then does the code exist.
  await expect(page.getByTestId('resend-timer')).toBeVisible();
  await page.getByTestId('code').fill(EMAIL_CODE);
  await page.getByTestId('verify').click();
  await expect(page.getByTestId('confirm')).toBeVisible();
  await page.getByTestId('confirm').click();
  await expect(page.getByTestId('booking-card')).toBeVisible();

  const booked = (await store.bookings()).find((booking) => booking.data['startsAt'] === at(key, '10:20'));
  expect(booked?.data).toMatchObject({ serviceId: DEEP_CLEANSING, durationMinutes: 75, status: 'confirmed' });
});
