import { readFileSync } from 'node:fs';

import { bookEverything, bookUntilResult, chooseService, chooseSlot, confirmFirstVisit, DEFAULTS, EMAIL_CODE, fillYou, verify } from './flows';
import { expect, mainText, noHorizontalScroll, open, test } from './support';

test.describe('booking (Bk-1 to Bk-8)', () => {
  test('books a service with an add-on and a guest, in sequence, and shows the confirmation @core', async ({ page, mock, slugFor }) => {
    const slug = slugFor('maria');
    const startsAt = await bookEverything(page, slug, { serviceId: 'glow', addOns: ['brow'], guests: 1 });

    await expect(page.getByTestId('booking-card')).toContainText('Glow Facial');
    await expect(page.getByTestId('personal-link')).toBeVisible();
    await noHorizontalScroll(page);

    const [booking] = await mock.bookings(slug);
    expect(booking).toMatchObject({
      status: 'confirmed',
      serviceId: 'glow',
      addOnIds: ['brow'],
      // The server keeps a guest count, never guest names (API.md 5.8).
      guests: 1,
      // 60 minutes of facial plus 15 of eyebrow tint, for two people one after the other.
      durationMinutes: 150,
      client: { name: DEFAULTS.name, phone: '+5511987654321' },
    });
    expect(new Date(booking?.startsAt ?? '').toISOString()).toBe(startsAt);
  });

  test('the confirmation links to the appointment and offers a calendar file', async ({ page, slugFor }) => {
    await bookEverything(page, slugFor('maria'));
    await page.getByTestId('add-calendar').click();
    await expect(page.getByTestId('calendar-sheet')).toBeVisible();
    const download = page.waitForEvent('download');
    await page.getByTestId('ics-download').click();
    const file = await download;
    expect(file.suggestedFilename()).toMatch(/\.ics$/);
    // D50: the calendar entry carries the public booking page, never the manage link.
    const ics = readFileSync((await file.path()), 'utf8');
    expect(ics).toContain(`/${slugFor('maria')}`);
    expect(ics).not.toContain('/m/');
    expect(decodeURIComponent((await page.getByTestId('google-calendar').getAttribute('href')) ?? '')).not.toContain('/m/');
    await page.keyboard.press('Escape');
    await page.getByTestId('view-appointment').click();
    await expect(page.getByTestId('actions')).toBeVisible();
  });

  test('verifies by e-mail code only and sends no phone verification (D46)', async ({ page, mock, slugFor, guard }) => {
    const slug = slugFor('maria');
    await chooseService(page, slug);
    await chooseSlot(page);
    await fillYou(page);
    await expect(page.getByTestId('use-sms')).toHaveCount(0);
    await verify(page, { code: EMAIL_CODE });
    await confirmFirstVisit(page);
    await expect(page.getByTestId('booking-card')).toBeVisible();
    expect((await mock.bookings(slug))[0]?.client.email).toBe(DEFAULTS.email);
    // Only our own origin was called, and only the e-mail code functions (no SMS function, no identity provider).
    const origin = new URL(page.url()).origin;
    expect(guard.requests.every((request) => request.url.startsWith(origin))).toBe(true);
    expect(guard.requests.some((request) => /sendSmsCode|verifySmsCode|identitytoolkit|recaptcha/i.test(request.url))).toBe(false);
  });

  test('a wrong code is explained and the right one then works', async ({ page, slugFor }) => {
    await chooseService(page, slugFor('maria'));
    await chooseSlot(page);
    await fillYou(page);
    await verify(page, { code: '000000' });
    await expect(page.getByRole('alert')).toBeVisible();
    await page.getByTestId('code').fill(EMAIL_CODE);
    await page.getByTestId('verify').click();
    await expect(page.getByTestId('confirm')).toBeVisible();
  });

  test('a time taken by someone else meanwhile is explained and the next times are offered', async ({ page, mock, slugFor }) => {
    const slug = slugFor('maria');
    await chooseService(page, slug);
    const slots = page.locator('[data-testid^="slot-"]');
    await expect(slots.first()).toBeVisible();
    const chosen = ((await slots.first().getAttribute('data-testid')) ?? '').replace('slot-', '');
    await slots.first().click();
    // Another client books exactly that time while this one is still on the page.
    await mock.seed({ slug, startsInMinutes: (Date.parse(chosen) - Date.now()) / 60_000, serviceId: 'brazilian', name: 'Someone Else', phone: '+5511900000123' });
    await page.getByTestId('continue').click();
    await expect(page.getByTestId('slot-taken')).toBeVisible();
    // The page is still on the time step and the taken time is gone from the list.
    await expect(page.getByTestId(`slot-${chosen}`)).toHaveCount(0);
  });

  test('the waiting list takes a name and a phone and nothing else', async ({ page, mock, slugFor }) => {
    const slug = slugFor('maria');
    await chooseService(page, slug);
    await expect(page.locator('[data-testid^="slot-"]').first()).toBeVisible();
    await page.getByTestId('waitlist-open').click();
    await page.getByTestId('wait-name').fill('Helena Duarte');
    await page.getByTestId('wait-phone').fill('11 98765 4321');
    await page.getByTestId('wait-submit').click();
    await expect(page.getByTestId('waitlist-done')).toBeVisible();
    const [entry] = await mock.waitlist(slug);
    expect(entry).toMatchObject({ slug, name: 'Helena Duarte', phone: '+5511987654321', serviceId: 'brazilian' });
    expect(entry?.['dayFrom']).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    expect(entry?.['dayTo']).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });
});

test.describe('approval, no-show protection and pause (Bk-10)', () => {
  test('a new client of a professional who confirms new clients is told it is waiting for approval, and nothing more', async ({ page, mock, slugFor }) => {
    const slug = slugFor('maria-approval');
    await bookUntilResult(page, slug);
    await expect(page.getByTestId('review-reason')).toBeVisible();
    const text = await mainText(page);
    expect(text).toMatch(/confirm/i);
    // D42: the page never mentions money, plans or limits to the client.
    expect(text).not.toMatch(/subscription|upgrade|premium|paywall|\bplan\b|registration|10 clients|limit reached/i);
    expect((await mock.bookings(slug))[0]?.status).toBe('pendingApproval');
  });

  test('a client past the no-show limit with "approve new bookings" waits for approval, and the page cannot tell why', async ({ page, slugFor }) => {
    await bookUntilResult(page, slugFor('maria-noshow'), { phone: '11 90000 0001' });
    // API.md 5.8: the response never says which rule asked for approval, so the words are the same for everyone.
    await expect(page.getByTestId('review-reason')).toBeVisible();
    await expect(page.getByTestId('review-reason')).not.toContainText(/missed|no-show|did not take place/i);
  });

  test('a client past the no-show limit with "pause online" is sent to message the professional', async ({ page, slugFor }) => {
    const slug = slugFor('maria-noshow');
    await chooseService(page, slug);
    await chooseSlot(page);
    await fillYou(page, { phone: '11 90000 0002' });
    await verify(page);
    await confirmFirstVisit(page);
    await expect(page.getByTestId('blocked-text')).toBeVisible();
    await expect(page.getByTestId('message-pro')).toBeVisible();
  });

  test('a paused page shows a kind message and no way to book', async ({ page, slugFor }) => {
    await open(page, `/${slugFor('maria-paused')}`);
    await expect(page.getByTestId('paused')).toBeVisible();
    await expect(page.getByTestId('book')).toHaveCount(0);
    await expect(page.getByTestId('message-pro')).toBeVisible();
  });
});

test.describe('finding a booking again (Bk-11)', () => {
  test('an e-mail and a code open the upcoming booking', async ({ page, mock, slugFor }) => {
    const slug = slugFor('maria');
    await mock.seed({ slug, startsInMinutes: 60 * 50, email: 'helena@example.com' });
    await open(page, `/${slug}/find`);
    await page.getByTestId('email').fill('helena@example.com');
    await page.getByTestId('send-code').click();
    await page.getByTestId('code').fill(EMAIL_CODE);
    await page.getByTestId('find').click();
    await expect(page.getByTestId('found-count')).toBeVisible();
    await page.getByTestId('found-booking').first().click();
    await expect(page.getByTestId('actions')).toBeVisible();
  });
});
