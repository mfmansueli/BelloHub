// The professionals the mock API knows. Each slug is one scenario, so Playwright tests can run in parallel without
// touching each other's state: the slug picks the behavior (approval, pause, no-show limit, strict policy...).

import type { InboxKey, PublicProfile, RuleLine } from '../../src/api/types';
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
  lateCancelCounts: true,
  noShowLimit: 3,
};

/** The text her app would publish for each localization of a policy (the page only displays it). */
export function rulesFor(policy: PolicyValues): Record<string, RuleLine[]> {
  const en: RuleLine[] = [
    { kind: 'link', text: 'After you book, a personal link arrives on WhatsApp. Use it any time to cancel or reschedule. No app or password.' },
    {
      kind: 'changes',
      text: `Free changes up to ${policy.freeWindowHours} hours before. ${policy.afterWindowCancel === 'allow' ? 'After that you can still cancel here, and Maria is told right away.' : 'After that, please message Maria.'}`,
    },
    { kind: 'reschedule', text: policy.clientCanReschedule ? 'You can reschedule up to 2 times.' : 'To reschedule, please message Maria.' },
    { kind: 'noShow', text: 'After 3 missed appointments without a message, Maria confirms your new bookings herself.' },
  ];
  const pt: RuleLine[] = [
    { kind: 'link', text: 'Depois de agendar, você recebe um link pessoal no WhatsApp. Use quando quiser para cancelar ou remarcar. Sem app e sem senha.' },
    { kind: 'changes', text: `Alterações sem custo até ${policy.freeWindowHours} horas antes. Depois disso, você ainda pode cancelar por aqui e a Maria é avisada na hora.` },
    { kind: 'reschedule', text: 'Você pode remarcar até 2 vezes.' },
    { kind: 'noShow', text: 'Após 3 faltas sem aviso, a Maria confirma seus novos agendamentos pessoalmente.' },
  ];
  const ar: RuleLine[] = [
    { kind: 'link', text: 'بعد الحجز يصلك رابط شخصي على واتساب. استخدمه في أي وقت للإلغاء أو إعادة الجدولة. بلا تطبيق وبلا كلمة مرور.' },
    { kind: 'changes', text: `التغييرات مجانية حتى ${policy.freeWindowHours} ساعة قبل الموعد. بعد ذلك يمكنك الإلغاء من هنا وتصل ماريا رسالة فورًا.` },
    { kind: 'reschedule', text: 'يمكنك إعادة الجدولة حتى مرتين.' },
    { kind: 'noShow', text: 'بعد 3 مواعيد فائتة دون إبلاغ، تؤكد ماريا حجوزاتك الجديدة بنفسها.' },
  ];
  return { en, 'pt-BR': pt, ar };
}

export const SEED_INBOX_LABEL = 'bellohub/mock/inbox-seed';

export interface Scenario {
  readonly slug: string;
  readonly profile: (inboxKey: InboxKey) => PublicProfile;
  /** Phones that already are clients of this professional (so `confirmNewClients` does not apply to them). */
  readonly knownClients: readonly string[];
  /** Phones that reached the no-show limit, with the action she chose. */
  readonly noShow: Readonly<Record<string, 'approveNewBookings' | 'pauseOnline'>>;
  /** Whether a first intake was already sealed within 12 months for this professional's bookings. */
  readonly intakeCompleted?: boolean;
}

function base(slug: string, inboxKey: InboxKey, overrides: Partial<PublicProfile> = {}, policy: PolicyValues = DEFAULT_POLICY): PublicProfile {
  return {
    slug,
    displayName: 'Maria Beauty',
    firstName: 'Maria',
    whatsappE164: '+5511987654321',
    locales: [...LOCALE_IDS],
    defaultLocale: 'pt-BR',
    regionCode: 'BR',
    timeZoneID: 'America/Sao_Paulo',
    currencyCode: 'BRL',
    city: 'São Paulo',
    headline: { 'pt-BR': 'Esteticista · São Paulo', en: 'Esthetician · São Paulo', ar: 'أخصائية تجميل · ساو باولو' },
    bio: {
      'pt-BR': 'Limpezas de pele calmas e cuidadosas para peles sensíveis e reativas. Somente com horário marcado.',
      en: 'Calm, careful facials for sensitive and reactive skin. By appointment.',
      ar: 'جلسات عناية هادئة ودقيقة للبشرة الحساسة والمتفاعلة. بموعد مسبق فقط.',
    },
    tags: ['Sensitive skin', 'Glow facials', 'Acne care'],
    credentials: {
      verifiedByPro: true,
      items: [
        { title: 'Aesthetics technical course', institution: 'Senac SP', year: 2019 },
        { title: 'Dermaplaning certification', year: 2022 },
        { title: 'Biosafety training', year: 2024 },
      ],
    },
    services: [
      { id: 'glow', name: 'Glow Facial', durationMinutes: 60, priceDisplay: 'show', priceAmount: 70 },
      { id: 'brazilian', name: 'Brazilian Glow', durationMinutes: 90, priceDisplay: 'show', priceAmount: 120 },
      { id: 'deep', name: 'Deep Cleansing', durationMinutes: 75, priceDisplay: 'startingFrom', priceAmount: 80 },
      { id: 'p360', name: 'Protocol 360', durationMinutes: 120, priceDisplay: 'onRequest' },
    ],
    addOns: [
      { id: 'brow', name: 'Eyebrow tint', minutes: 15, priceAmount: 20 },
      { id: 'led', name: 'LED light', minutes: 15, priceAmount: 25 },
      { id: 'mask', name: 'Hand and arm massage', minutes: 10, priceAmount: 15 },
    ],
    rules: rulesFor(policy),
    policy,
    booking: { accepting: true, confirmNewClients: false, maxGuests: 2, maxDaysAhead: 60, askFirstVisitQuestions: true, waitlist: true },
    inboxKey,
    channels: { whatsAppAutomation: false, emailCode: true },
    ...overrides,
  };
}

export function scenarios(): Scenario[] {
  const known = ['+5511900000099'];
  return [
    { slug: 'maria', profile: (key) => base('maria', key), knownClients: known, noShow: {} },
    {
      slug: 'maria-approval',
      profile: (key) => base('maria-approval', key, { booking: { accepting: true, confirmNewClients: true, maxGuests: 1, maxDaysAhead: 60, waitlist: true } }),
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
      profile: (key) => base('maria-paused', key, { booking: { accepting: false, pausedUntil: '2026-12-12', confirmNewClients: false, maxGuests: 0, maxDaysAhead: 60, waitlist: false } }),
      knownClients: known,
      noShow: {},
    },
    {
      slug: 'maria-auto',
      profile: (key) => base('maria-auto', key, { channels: { whatsAppAutomation: true, emailCode: true } }),
      knownClients: known,
      noShow: {},
    },
    {
      slug: 'maria-strict',
      profile: (key) => base('maria-strict', key, {}, { ...DEFAULT_POLICY, clientCanReschedule: false, afterWindowCancel: 'message', afterWindowReschedule: 'message', lateCancelCounts: false }),
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
          defaultLocale: 'pt-PT',
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
          defaultLocale: 'ar',
          whatsappE164: '+966512345678',
        }),
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
