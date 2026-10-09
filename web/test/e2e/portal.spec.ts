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

  test('links to no form, check-in or data page: those open only from a booking\'s own link (D52)', async ({ page, mock, slugFor }) => {
    const { portalToken } = await mock.seed({ slug: slugFor('maria'), startsInMinutes: -24 * HOUR, status: 'completed' });
    await open(page, `/p/${portalToken}`);
    await expect(page.getByTestId('next-session')).toBeVisible();
    for (const tab of ['tab-appts', 'tab-journey', 'tab-care']) {
      await page.getByTestId(tab).click();
      const hrefs = await page.locator('a[href]').evaluateAll((anchors) => anchors.map((anchor) => anchor.getAttribute('href') ?? ''));
      expect(hrefs.filter((href) => /\/(form|checkin|data)(\/|$|\?)/.test(href))).toEqual([]);
    }
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
    // The visit of a month ago stays `confirmed` (the API has no "completed": `phase` says it); one new booking ahead.
    expect(bookings.filter((booking) => booking.status === 'confirmed' && Date.parse(booking.startsAt) > Date.now())).toHaveLength(1);
    await page.getByTestId('view-appointment').click();
    await expect(page.getByTestId('actions')).toBeVisible();
  });

  // API.md 5.13: the portal does not say beforehand whether a pause or an approval applies; the server's answer does.
  test('when the professional confirms new bookings, the answer is a request and the page says so kindly', async ({ page, mock, slugFor }) => {
    const slug = slugFor('maria');
    await mock.seed({ slug, startsInMinutes: -24 * HOUR, status: 'completed', phone: '+5511987654321' });
    const portalToken = await mock.seedPortal(slug, 'Ana', '+5511987654321', 'approval');
    await open(page, `/p/${portalToken}/rebook`);
    const slots = page.locator('[data-testid^="slot-"]');
    await expect(slots.first()).toBeVisible();
    await slots.first().click();
    await page.getByTestId('rebook').click();
    await expect(page.getByTestId('done-text')).toContainText(/confirm/i);
    expect((await mock.bookings(slug)).map((booking) => booking.status).sort()).toEqual(['confirmed', 'pendingApproval']);
  });

  test('when online booking is paused for this client, the answer is a pause and a way to message', async ({ page, mock, slugFor }) => {
    const portalToken = await mock.seedPortal(slugFor('maria'), 'Ana', '+5511987654321', 'paused');
    await open(page, `/p/${portalToken}/rebook`);
    const slots = page.locator('[data-testid^="slot-"]');
    await expect(slots.first()).toBeVisible();
    await slots.first().click();
    await page.getByTestId('rebook').click();
    await expect(page.getByTestId('done-text')).toContainText(/paused/i);
    await expect(page.getByTestId('message-pro')).toBeVisible();
  });
});
