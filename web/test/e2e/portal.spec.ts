import { expect, open, test } from './support';

const HOUR = 60;

test.describe('the client portal (Cl-2) and rebooking (Cl-3)', () => {
  test('lists the next session, the care notes and the journey in tabs a keyboard can move through', async ({ page, mock, slugFor }) => {
    // A client with nothing shared yet: each tab explains what will appear there.
    const portalToken = await mock.seedPortal(slugFor('maria'));
    await open(page, `/p/${portalToken}`);
    await expect(page.getByTestId('next-session')).toBeVisible();
    const first = page.getByTestId('tab-appts');
    await first.focus();
    await page.keyboard.press('ArrowRight');
    await expect(page.getByTestId('tab-journey')).toHaveAttribute('aria-selected', 'true');
    await expect(page.getByTestId('journey-empty')).toBeVisible();
    await page.keyboard.press('ArrowRight');
    await expect(page.getByTestId('tab-care')).toHaveAttribute('aria-selected', 'true');
    await expect(page.getByTestId('care-empty')).toBeVisible();
    await page.keyboard.press('Home');
    await expect(page.getByTestId('tab-appts')).toHaveAttribute('aria-selected', 'true');
  });

  test('shows what the professional shared after a visit: the note and the care steps', async ({ page, mock, slugFor }) => {
    const { portalToken } = await mock.seed({ slug: slugFor('maria'), startsInMinutes: -24 * HOUR, status: 'completed' });
    await open(page, `/p/${portalToken}`);
    await page.getByTestId('tab-journey').click();
    await expect(page.getByRole('tabpanel')).toContainText('Your skin responded well');
    await page.getByTestId('tab-care').click();
    await expect(page.getByRole('tabpanel')).toContainText('sunscreen');
  });

  test('rebooks in two taps for a client the professional already knows @core', async ({ page, mock, slugFor }) => {
    const slug = slugFor('maria');
    const { portalToken } = await mock.seed({ slug, startsInMinutes: -24 * HOUR, status: 'completed' });
    await open(page, `/p/${portalToken}/rebook`);
    const slots = page.locator('[data-testid^="slot-"]');
    await expect(slots.first()).toBeVisible();
    await slots.first().click();
    await page.getByTestId('rebook').click();
    await expect(page.getByTestId('done-card')).toBeVisible();
    const bookings = await mock.bookings(slug);
    expect(bookings.filter((booking) => booking.status === 'confirmed')).toHaveLength(1);
    await page.getByTestId('view-appointment').click();
    await expect(page.getByTestId('actions')).toBeVisible();
  });

  test('when the professional confirms new bookings, rebooking is a request and says so kindly', async ({ page, mock, slugFor }) => {
    const slug = slugFor('maria');
    await mock.seed({ slug, startsInMinutes: -24 * HOUR, status: 'completed', phone: '+5511987654321' });
    const portalToken = await mock.seedPortal(slug, 'Ana', '+5511987654321', 'approval');
    await open(page, `/p/${portalToken}/rebook`);
    await expect(page.getByTestId('gate')).toBeVisible();
    const slots = page.locator('[data-testid^="slot-"]');
    await expect(slots.first()).toBeVisible();
    await slots.first().click();
    await page.getByTestId('rebook').click();
    await expect(page.getByTestId('done-text')).toContainText(/confirm/i);
    expect((await mock.bookings(slug)).map((booking) => booking.status).sort()).toEqual(['completed', 'pendingApproval']);
  });

  test('when online booking is paused for this client, rebooking is a message and no times are offered', async ({ page, mock, slugFor }) => {
    const portalToken = await mock.seedPortal(slugFor('maria'), 'Ana', '+5511987654321', 'paused');
    await open(page, `/p/${portalToken}/rebook`);
    await expect(page.getByTestId('gate')).toBeVisible();
    await expect(page.getByTestId('message-pro')).toBeVisible();
    await expect(page.locator('[data-testid^="slot-"]')).toHaveCount(0);
  });
});
