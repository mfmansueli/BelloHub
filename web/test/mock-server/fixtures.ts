// The professionals the mock API knows. Each slug is one scenario, so Playwright tests can run in parallel without
// touching each other's state: the slug picks the behavior (approval, pause, no-show limit, strict policy...).
// Profiles are the `PublicProfile` of API.md section 4, exactly as the app would publish them.

import type { InboxKey, WireProfile } from '../../src/api/types';
import type { PolicyValues } from '../../src/lib/policy';
import { LOCALE_IDS } from '../../src/lib/locales';

export const DEFAULT_POLICY: PolicyValues = {
  freeWindowHours: 24,
  clientCanReschedule: true,
  maxReschedules: 2,
  afterWindowCancel: 'allow',
  afterWindowReschedule: 'request',
  askConfirmation: true,
  graceMinutes: 15,
};

/** The text her app would publish for each localization of a policy (the page only displays it, line by line). */
export function rulesFor(policy: PolicyValues): Record<string, string> {
  const en = [
    'After you book, a personal link arrives on WhatsApp. Use it any time to cancel or reschedule. No app or password.',
    `Free changes up to ${policy.freeWindowHours} hours before. ${policy.afterWindowCancel === 'allow' ? 'After that you can still cancel here, and Maria is told right away.' : 'After that, please message Maria.'}`,
    policy.clientCanReschedule ? 'You can reschedule up to 2 times.' : 'To reschedule, please message Maria.',
    'After 3 missed appointments without a message, Maria confirms your new bookings herself.',
  ];
  const pt = [
    'Depois de agendar, você recebe um link pessoal no WhatsApp. Use quando quiser para cancelar ou remarcar. Sem app e sem senha.',
    `Alterações sem custo até ${policy.freeWindowHours} horas antes. Depois disso, você ainda pode cancelar por aqui e a Maria é avisada na hora.`,
    'Você pode remarcar até 2 vezes.',
    'Após 3 faltas sem aviso, a Maria confirma seus novos agendamentos pessoalmente.',
  ];
  const ar = [
    'بعد الحجز يصلك رابط شخصي على واتساب. استخدمه في أي وقت للإلغاء أو إعادة الجدولة. بلا تطبيق وبلا كلمة مرور.',
    `التغييرات مجانية حتى ${policy.freeWindowHours} ساعة قبل الموعد. بعد ذلك يمكنك الإلغاء من هنا وتصل ماريا رسالة فورًا.`,
    'يمكنك إعادة الجدولة حتى مرتين.',
    'بعد 3 مواعيد فائتة دون إبلاغ، تؤكد ماريا حجوزاتك الجديدة بنفسها.',
  ];
  return { en: en.join('\n'), 'pt-BR': pt.join('\n'), ar: ar.join('\n') };
}

export const SEED_INBOX_LABEL = 'bellohub/mock/inbox-seed';

export interface Scenario {
  readonly slug: string;
  readonly profile: (inboxKey: InboxKey) => WireProfile;
  /** Phones that already are clients of this professional (so `requiresApproval` does not apply to them). */
  readonly knownClients: readonly string[];
  /** Phones that reached the no-show limit, with the action she chose. */
  readonly noShow: Readonly<Record<string, 'approveNewBookings' | 'pauseOnline'>>;
  /** Whether a first intake was already sealed within 12 months for this professional's bookings. */
  readonly intakeCompleted?: boolean;
  /** WhatsApp automation (D31) is on for this professional. */
  readonly whatsAppAutomation?: boolean;
  /** Whether she published a health form. */
  readonly intakeAvailable?: boolean;
}

function base(slug: string, inboxKey: InboxKey, overrides: Partial<WireProfile> = {}, policy: PolicyValues = DEFAULT_POLICY): WireProfile {
  return {
    schemaVersion: 1,
    slug,
    displayName: 'Maria Beauty',
    businessName: 'Studio Maria',
    whatsappE164: '+5511987654321',
    locales: [...LOCALE_IDS],
    regionCode: 'BR',
    timeZoneID: 'America/Sao_Paulo',
    currencyCode: 'BRL',
    city: 'São Paulo',
    bio: 'Calm, careful facials for sensitive and reactive skin.\nBy appointment.',
    credentials: [
      { title: 'Aesthetics technical course', institution: 'Senac SP', year: 2019 },
      { title: 'Dermaplaning certification', year: 2022 },
      { title: 'Biosafety training', year: 2024 },
    ],
    services: [
      { id: 'glow', name: 'Glow Facial', durationMinutes: 60, price: { display: 'show', amount: 70 } },
      { id: 'brazilian', name: 'Brazilian Glow', durationMinutes: 90, price: { display: 'show', amount: 120 } },
      { id: 'deep', name: 'Deep Cleansing', durationMinutes: 75, price: { display: 'startingFrom', amount: 80 } },
      { id: 'p360', name: 'Protocol 360', durationMinutes: 120, price: { display: 'onRequest' } },
    ],
    addOns: [
      { id: 'brow', name: 'Eyebrow tint', minutes: 15, priceText: '+ R$ 20' },
      { id: 'led', name: 'LED light', minutes: 15, priceText: '+ R$ 25' },
      { id: 'mask', name: 'Hand and arm massage', minutes: 10, priceText: '+ R$ 15' },
    ],
    booking: { acceptingBookings: true, requiresApproval: false, maxGuests: 2, maxDaysAhead: 60 },
    policy,
    rulesText: rulesFor(policy),
    inboxKey,
    updatedAt: '2026-10-01T12:00:00.000Z',
    ...overrides,
  };
}

function withoutWhatsApp(profile: WireProfile): WireProfile {
  return Object.fromEntries(Object.entries(profile).filter(([key]) => key !== 'whatsappE164')) as unknown as WireProfile;
}

export function scenarios(): Scenario[] {
  const known = ['+5511900000099'];
  return [
    { slug: 'maria', profile: (key) => base('maria', key), knownClients: known, noShow: {} },
    {
      slug: 'maria-approval',
      profile: (key) => base('maria-approval', key, { booking: { acceptingBookings: true, requiresApproval: true, maxGuests: 1, maxDaysAhead: 60 } }),
      knownClients: known,
      noShow: {},
    },
    {
      slug: 'maria-noshow',
      profile: (key) => base('maria-noshow', key),
      knownClients: known,
      noShow: { '+5511900000001': 'approveNewBookings', '+5511900000002': 'pauseOnline' },
    },
    {
      slug: 'maria-paused',
      profile: (key) => base('maria-paused', key, { booking: { acceptingBookings: false, pausedUntil: '2026-12-12T12:00:00.000Z', requiresApproval: false, maxGuests: 0, maxDaysAhead: 60 } }),
      knownClients: known,
      noShow: {},
    },
    {
      slug: 'maria-auto',
      profile: (key) => base('maria-auto', key),
      knownClients: known,
      noShow: {},
      whatsAppAutomation: true,
    },
    {
      slug: 'maria-strict',
      profile: (key) => base('maria-strict', key, {}, { ...DEFAULT_POLICY, clientCanReschedule: false, afterWindowCancel: 'message', afterWindowReschedule: 'message' }),
      knownClients: known,
      noShow: {},
    },
    {
      slug: 'maria-lisbon',
      profile: (key) =>
        base('maria-lisbon', key, {
          regionCode: 'PT',
          timeZoneID: 'Europe/Lisbon',
          currencyCode: 'EUR',
          city: 'Lisboa',
          locales: ['pt-PT', 'en'],
          whatsappE164: '+351912345678',
        }),
      knownClients: known,
      noShow: {},
    },
    {
      slug: 'maria-riyadh',
      profile: (key) =>
        base('maria-riyadh', key, {
          regionCode: 'SA',
          timeZoneID: 'Asia/Riyadh',
          currencyCode: 'SAR',
          city: 'الرياض',
          locales: ['ar', 'en'],
          whatsappE164: '+966512345678',
        }),
      knownClients: known,
      noShow: {},
    },
    {
      // No public WhatsApp number: "I didn't get the code" offers no WhatsApp way (API.md 5.8 `whatsapp`).
      slug: 'maria-nowa',
      profile: (key) => withoutWhatsApp(base('maria-nowa', key)),
      knownClients: known,
      noShow: {},
    },
    {
      slug: 'maria-done',
      profile: (key) => base('maria-done', key),
      knownClients: known,
      noShow: {},
      intakeCompleted: true,
    },
  ];
}
