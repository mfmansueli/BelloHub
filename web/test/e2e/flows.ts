// The booking flow as a person walks it, in small steps so each spec can stop where it needs to.

import { expect, tap, open } from './support';
import type { Page } from '@playwright/test';

export interface BookingInput {
  readonly serviceId?: string;
  readonly addOns?: readonly string[];
  readonly guests?: number;
  readonly name?: string;
  /** What is typed into the phone field (the country is the professional's). */
  readonly phone?: string;
  readonly email?: string;
  readonly channel?: 'sms' | 'email';
  /** The code typed on the verify step. */
  readonly code?: string;
  /** Which of the offered slots to take (0 is the first). */
  readonly slotIndex?: number;
}

export const DEFAULTS = {
  serviceId: 'brazilian',
  name: 'Helena Duarte',
  phone: '11 98765 4321',
  email: 'helena@example.com',
} as const;

export const SMS_CODE = '123456';
export const EMAIL_CODE = '654321';

/** Bk-1 to Bk-2: choose the service, add-ons and guests, then continue. */
export async function chooseService(page: Page, slug: string, input: BookingInput = {}): Promise<void> {
  await open(page, `/${slug}`);
  await page.getByTestId(`service-${input.serviceId ?? DEFAULTS.serviceId}`).click();
  for (const addOn of input.addOns ?? []) await tap(page, `addon-${addOn}`);
  if ((input.guests ?? 0) > 0) await page.getByTestId(`guests-${input.guests}`).click();
  await page.getByTestId('continue').click();
}

/** Bk-4: choose a slot (the page keeps it on hold) and continue. Returns the ISO instant of the slot taken. */
export async function chooseSlot(page: Page, slotIndex = 0): Promise<string> {
  const slots = page.locator('[data-testid^="slot-"]');
  await expect(slots.first()).toBeVisible();
  const slot = slots.nth(slotIndex);
  const testId = (await slot.getAttribute('data-testid')) ?? '';
  await slot.click();
  await page.getByTestId('continue').click();
  return testId.replace('slot-', '');
}

/** Bk-5: who is coming. */
export async function fillYou(page: Page, input: BookingInput = {}): Promise<void> {
  await expect(page.getByTestId('name')).toBeVisible();
  await page.getByTestId('name').fill(input.name ?? DEFAULTS.name);
  await page.getByTestId('phone').fill(input.phone ?? DEFAULTS.phone);
  if (input.email !== undefined || input.channel === 'email') await page.getByTestId('email').fill(input.email ?? DEFAULTS.email);
  await page.getByTestId('send-code').click();
}

/** Bk-6: the code, from SMS or email. */
export async function verify(page: Page, input: BookingInput = {}): Promise<void> {
  await expect(page.getByTestId('code')).toBeVisible();
  if (input.channel === 'email') await page.getByTestId('use-email').click();
  await page.getByTestId('code').fill(input.code ?? (input.channel === 'email' ? EMAIL_CODE : SMS_CODE));
  await page.getByTestId('verify').click();
}

/** Bk-7: the optional first-visit questions, answered, then confirm. */
export async function confirmFirstVisit(page: Page): Promise<void> {
  await expect(page.getByTestId('confirm')).toBeVisible();
  await page.getByTestId('confirm').click();
}

/** Every step up to pressing "Confirm"; whatever the server answers is for the test to check. Returns the slot. */
export async function bookUntilResult(page: Page, slug: string, input: BookingInput = {}): Promise<string> {
  await chooseService(page, slug, input);
  const startsAt = await chooseSlot(page, input.slotIndex ?? 0);
  await fillYou(page, input);
  await verify(page, input);
  await confirmFirstVisit(page);
  return startsAt;
}

/** The whole path to the confirmation. Returns the ISO instant booked. */
export async function bookEverything(page: Page, slug: string, input: BookingInput = {}): Promise<string> {
  const startsAt = await bookUntilResult(page, slug, input);
  await expect(page.getByTestId('booking-card')).toBeVisible();
  return startsAt;
}
