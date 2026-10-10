// verify-fallback against the real functions: "I didn't get the code" -> "Confirm on WhatsApp" makes an unverified
// request (pendingApproval, flagged, with a reference), and a client who booked with a code books again on the same
// page without one (trusted device). docs/agent-notes/verify-fallback.md.

import type { Page } from '@playwright/test';

import { chooseDayAhead, expect, open, test } from './support';

const SLUG = 'maria';
const ZONE = 'America/Sao_Paulo';
const EMAIL_CODE = '123456';

async function toDetails(page: Page, client: { name: string; phone: string; email: string }, daysAhead: number): Promise<void> {
  await open(page, `/${SLUG}`);
  await page.locator('[data-testid^="service-"]').first().click();
  await page.getByTestId('continue').click();
  await chooseDayAhead(page, ZONE, daysAhead);
  const slots = page.locator('[data-testid^="slot-"]');
  await expect(slots.first()).toBeVisible();
  await slots.first().click();
  await page.getByTestId('continue').click();
  await expect(page.getByTestId('name')).toBeVisible();
  await page.getByTestId('name').fill(client.name);
  await page.getByTestId('phone').fill(client.phone);
  await page.getByTestId('email').fill(client.email);
  await page.getByTestId('send-code').click();
}

test('a client whose code never came confirms on WhatsApp: an unverified request with a reference', async ({ page, store }) => {
  const client = { name: 'Lia Prado', phone: '11 96543 2109', email: 'lia@example.com' };
  await page.clock.install();
  await toDetails(page, client, 4);
  await expect(page.getByTestId('code')).toBeVisible();
  await page.clock.fastForward(31_000);
  await page.getByTestId('no-code').click();
  await page.getByTestId('confirm-whatsapp').click();

  const reference = (await page.getByTestId('reference').textContent())?.trim() ?? '';
  expect(reference).toMatch(/^[2-9A-HJKMNP-Z]{5}$/);
  expect(decodeURIComponent((await page.getByTestId('send-whatsapp').getAttribute('href')) ?? '')).toContain(reference);

  const booking = (await store.bookings()).find((entry) => (entry.data['client'] as { email?: string } | undefined)?.email === client.email);
  expect(booking?.data).toMatchObject({ status: 'pendingApproval', verification: 'whatsapp', reference });
});

test('a client who booked with a code books again on the same page without one', async ({ page, store }) => {
  const client = { name: 'Nina Alves', phone: '11 95432 1098', email: 'nina@example.com' };
  await toDetails(page, client, 5);
  await page.getByTestId('code').fill(EMAIL_CODE);
  await page.getByTestId('verify').click();
  await page.getByTestId('confirm').click();
  await expect(page.getByTestId('booking-card')).toBeVisible();

  await toDetails(page, client, 6);
  await expect(page.getByTestId('confirm')).toBeVisible();
  await expect(page.getByTestId('code')).toHaveCount(0);
  await page.getByTestId('confirm').click();
  await expect(page.getByTestId('booking-card')).toBeVisible();

  const mine = (await store.bookings()).filter((entry) => (entry.data['client'] as { email?: string } | undefined)?.email === client.email);
  expect(mine.map((entry) => entry.data['status'])).toEqual(['confirmed', 'confirmed']);
});
