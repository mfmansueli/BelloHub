import { expect, mainText, noHorizontalScroll, open, test } from './support';

const HOUR = 60;

test.describe('managing a booking from its link (Bk-9)', () => {
  test('shows the booking, the policy note and the actions, and never puts the token in an API URL', async ({ page, mock, guard, slugFor }) => {
    const slug = slugFor('maria');
    const { token } = await mock.seed({ slug, startsInMinutes: 50 * HOUR });
    await open(page, `/m/${token}`);
    await expect(page.getByTestId('booking-card')).toBeVisible();
    await expect(page.getByTestId('policy-note')).toContainText(/free/i);
    await expect(page.getByTestId('actions')).toBeVisible();
    await noHorizontalScroll(page);
    const apiCalls = guard.requests.filter((request) => new URL(request.url).pathname.startsWith('/api/'));
    expect(apiCalls.length).toBeGreaterThan(0);
    for (const call of apiCalls) expect(call.url, 'a token in a URL would end up in logs and referrers').not.toContain(token);
  });

  test('confirms presence with one tap', async ({ page, mock, slugFor }) => {
    const slug = slugFor('maria');
    const { token } = await mock.seed({ slug, startsInMinutes: 20 * HOUR });
    await open(page, `/m/${token}`);
    await page.getByTestId('attend-yes').click();
    await expect(page.getByTestId('attend-thanks')).toBeVisible();
    await expect.poll(async () => (await mock.bookings(slug))[0]?.clientConfirmedAt).not.toBeNull();
  });

  test('says "I cannot come" and points to reschedule or cancel', async ({ page, mock, slugFor }) => {
    const { token } = await mock.seed({ slug: slugFor('maria'), startsInMinutes: 20 * HOUR });
    await open(page, `/m/${token}`);
    await page.getByTestId('attend-no').click();
    await expect(page.getByTestId('attend-no-text')).toBeVisible();
  });

  test('tells the professional the client is running late and shows the grace', async ({ page, mock, slugFor }) => {
    const slug = slugFor('maria');
    const { token } = await mock.seed({ slug, startsInMinutes: 1 * HOUR });
    await open(page, `/m/${token}`);
    await page.getByTestId('late-10').click();
    await expect(page.getByTestId('late')).toContainText(/10/);
    await expect.poll(async () => (await mock.bookings(slug))[0]?.lateByMinutes).toBe(10);
  });

  test('an unknown link and an expired one look the same, and a malformed path is not found', async ({ page, mock, slugFor }) => {
    // A guessed token must not tell the guesser whether it ever existed.
    await open(page, '/m/AAAAAAAAAAAAAAAAAAAAAA');
    await expect(page.getByTestId('expired')).toBeVisible();
    const expired = await mock.seedExpired(slugFor('maria'));
    await open(page, `/m/${expired}`);
    await expect(page.getByTestId('expired')).toBeVisible();
    // API.md section 3: an error never names the professional, so there is nobody to message from here.
    await expect(page.getByTestId('message-pro')).toHaveCount(0);
    await open(page, '/m/short');
    await expect(page.getByTestId('not-found')).toBeVisible();
  });

  test('a strict professional sends reschedule and late cancellations to WhatsApp', async ({ page, mock, slugFor }) => {
    const { token } = await mock.seed({ slug: slugFor('maria-strict'), startsInMinutes: 5 * HOUR });
    await open(page, `/m/${token}`);
    await expect(page.getByTestId('reschedule')).toHaveAttribute('href', /^https:\/\/wa\.me\/\d+\?text=/);
    await expect(page.getByTestId('cancel')).toHaveAttribute('href', /^https:\/\/wa\.me\/\d+\?text=/);
  });
});

test.describe('rescheduling (Cl-9)', () => {
  test('moves a booking inside the free window straight to the new time @core', async ({ page, mock, slugFor }) => {
    const slug = slugFor('maria');
    const { token } = await mock.seed({ slug, startsInMinutes: 50 * HOUR });
    const before = (await mock.bookings(slug))[0]?.startsAt;
    await open(page, `/m/${token}`);
    await page.getByTestId('reschedule').click();
    await expect(page.getByTestId('current-time')).toBeVisible();
    const slots = page.locator('[data-testid^="slot-"]');
    await expect(slots.first()).toBeVisible();
    const target = ((await slots.nth(1).getAttribute('data-testid')) ?? '').replace('slot-', '');
    await slots.nth(1).click();
    await page.getByTestId('confirm-reschedule').click();
    await expect(page.getByTestId('done-text')).toBeVisible();
    const [after] = await mock.bookings(slug);
    expect(after?.startsAt).toBe(new Date(target).toISOString());
    expect(after?.startsAt).not.toBe(before);
    expect(after?.rescheduleCount).toBe(1);
    await page.getByTestId('back-to-appointment').click();
    await expect(page.getByTestId('booking-card')).toContainText(new RegExp(String(new Date(target).getUTCDate())));
  });

  test('after the free window it sends a request the professional answers, and the current time stays held', async ({ page, mock, slugFor }) => {
    const slug = slugFor('maria');
    const { token } = await mock.seed({ slug, startsInMinutes: 5 * HOUR });
    await open(page, `/m/${token}/reschedule`);
    const slots = page.locator('[data-testid^="slot-"]');
    await expect(slots.first()).toBeVisible();
    await slots.first().click();
    await page.getByTestId('note').fill('Something came up at work');
    await page.getByTestId('confirm-reschedule').click();
    await expect(page.getByTestId('done-text')).toBeVisible();
    await expect.poll(async () => (await mock.rescheduleRequests(slug)).length).toBe(1);
    const [booking] = await mock.bookings(slug);
    expect(booking?.status).toBe('confirmed');
  });

  test('after the limit of changes it sends the person to the professional instead', async ({ page, mock, slugFor }) => {
    const { token } = await mock.seed({ slug: slugFor('maria'), startsInMinutes: 50 * HOUR, rescheduleCount: 2 });
    await open(page, `/m/${token}/reschedule`);
    await expect(page.getByTestId('message-pro')).toBeVisible();
    await expect(page.getByTestId('confirm-reschedule')).toHaveCount(0);
  });
});

test.describe('the rules of the booking (D47)', () => {
  test('the management page states the rules that apply from the time of booking, worded from the booking\'s own policy', async ({ page, mock, slugFor }) => {
    const slug = slugFor('maria');
    // The booking was made under a 48-hour window; her page today says 24. The booking keeps its own.
    const { token } = await mock.seed({ slug, startsInMinutes: 80 * HOUR, policy: { freeWindowHours: 48, clientCanReschedule: false, afterWindowCancel: 'message' } });
    await open(page, `/m/${token}`);
    const rules = page.getByTestId('booking-rules');
    await expect(rules).toBeVisible();
    await expect(rules).toContainText('These are the rules that apply to this booking, from the time you booked');
    await expect(rules).toContainText('48 hours');
    await expect(rules).not.toContainText('24 hours');
    await expect(rules).toContainText('message Maria');
    await expect(rules).not.toContainText(/missed|counts as/i);
  });
});

test.describe('cancelling (Cl-6)', () => {
  test('cancels for free with a reason, and offers to book another time @core', async ({ page, mock, slugFor }) => {
    const slug = slugFor('maria');
    const { token } = await mock.seed({ slug, startsInMinutes: 50 * HOUR });
    await open(page, `/m/${token}`);
    await page.getByTestId('cancel').click();
    await expect(page.getByTestId('counts-warning')).toHaveCount(0);
    await page.getByTestId('reason-conflict').click({ force: true });
    await page.getByTestId('confirm-cancel').click();
    await expect(page.getByTestId('done-text')).toBeVisible();
    await expect(page.getByTestId('book-again')).toBeVisible();
    expect((await mock.bookings(slug))[0]?.status).toBe('cancelledByClient');
    await open(page, `/m/${token}`);
    await expect(page.getByTestId('cancelled')).toBeVisible();
  });

  test('a late cancellation states only what the policy states: no claim that it counts as a missed appointment (D47)', async ({ page, mock, guard, slugFor }) => {
    const slug = slugFor('maria');
    const { token } = await mock.seed({ slug, startsInMinutes: 5 * HOUR });
    await open(page, `/m/${token}/cancel`);
    await expect(page.getByTestId('confirm-cancel')).toBeVisible();
    await expect(page.getByTestId('counts-warning')).toHaveCount(0);
    expect(await mainText(page)).not.toMatch(/missed appointment|counts as/i);
    await page.getByTestId('confirm-cancel').click();
    await expect(page.getByTestId('done-text')).toContainText(/counts/i);
    expect((await mock.bookings(slug))[0]?.status).toBe('cancelledByClient');
    // The page told the server it accepted the warning (API.md 5.12), with the request in the body.
    const cancel = guard.requests.find((request) => request.url.endsWith('/api/cancelBooking'));
    expect(JSON.parse(cancel?.body ?? '{}')).toMatchObject({ data: { token, acceptLateWarning: true } });
  });
});
