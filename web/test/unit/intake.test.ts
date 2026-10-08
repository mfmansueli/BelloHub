import { describe, expect, it } from 'vitest';

import type { FormContext, FormQuestion } from '../../src/api/types';
import { EMPTY_INTAKE, buildIntakePayload, intakeProblems, isAnswered, toggleChoice, visibleQuestions, type IntakeState } from '../../src/routes/form/payload';
import { groupByDay } from '../../src/app/booking/slotDays';

function question(key: string, extra: Partial<FormQuestion> = {}): FormQuestion {
  return { key, kind: 'text', label: { en: key }, ...extra };
}

const questions: FormQuestion[] = [
  question('allergies', { kind: 'yesNo', required: true }),
  question('medications', { kind: 'text' }),
  question('conditions', { kind: 'multiChoice', required: true, options: [{ value: 'none', label: { en: 'None' } }, { value: 'asthma', label: { en: 'Asthma' } }] }),
  question('guardianNote', { audience: 'minor', required: true }),
  question('adultOnly', { audience: 'adult', required: true }),
];

function makeContext(): FormContext {
  return {
    professional: { slug: 'maria', displayName: 'Maria Bello', firstName: 'Maria', locales: ['en'], defaultLocale: 'en', regionCode: 'BR', timeZoneID: 'America/Sao_Paulo', currencyCode: 'BRL' },
    bookingId: 'booking-1',
    client: { firstName: 'Ana' },
    inboxKey: { keyId: 'AAAAAAAAAAA', alg: 'hpke-v1', pub: 'x' },
    intake: { available: true, completedWithin12Months: false, formVersion: 'v7', questions },
    checkIn: { available: false },
  };
}

function makeState(extra: Partial<IntakeState> = {}): IntakeState {
  return {
    ...EMPTY_INTAKE,
    answers: { allergies: false, conditions: ['none'], adultOnly: 'fine' },
    typedSignature: 'Ana Souza',
    consent: true,
    ...extra,
  };
}

describe('the health form rules', () => {
  it('shows the questions of the audience: adult visit hides minor ones and the other way round', () => {
    expect(visibleQuestions(questions, false).map((q) => q.key)).toEqual(['allergies', 'medications', 'conditions', 'adultOnly']);
    expect(visibleQuestions(questions, true).map((q) => q.key)).toEqual(['allergies', 'medications', 'conditions', 'guardianNote']);
  });

  it('counts false as an answer, but not an empty string or an empty list', () => {
    expect(isAnswered(false)).toBe(true);
    expect(isAnswered(true)).toBe(true);
    expect(isAnswered('')).toBe(false);
    expect(isAnswered('   ')).toBe(false);
    expect(isAnswered('x')).toBe(true);
    expect(isAnswered([])).toBe(false);
    expect(isAnswered(['a'])).toBe(true);
    expect(isAnswered(undefined)).toBe(false);
  });

  it('a complete adult form has no problems', () => {
    expect(intakeProblems(makeState(), questions)).toEqual([]);
  });

  it('lists every required question left open, the signature and the consent', () => {
    const problems = intakeProblems(makeState({ answers: {}, typedSignature: ' ', consent: false }), questions);
    expect(problems).toEqual([
      { field: 'question', key: 'allergies' },
      { field: 'question', key: 'conditions' },
      { field: 'question', key: 'adultOnly' },
      { field: 'typedSignature' },
      { field: 'consent' },
    ]);
  });

  it('a minor visit asks for the young person and the guardian instead of a typed signature', () => {
    const state = makeState({ isForMinor: true, answers: { allergies: true, conditions: ['asthma'], guardianNote: 'ok' }, typedSignature: '' });
    expect(intakeProblems(state, questions)).toEqual([{ field: 'minorName' }, { field: 'guardianName' }]);
    const done = { ...state, minorName: 'Bia', guardianName: 'Ana Souza (mother)' };
    expect(intakeProblems(done, questions)).toEqual([]);
  });

  it('none is exclusive in a multiple choice', () => {
    expect(toggleChoice([], 'asthma')).toEqual(['asthma']);
    expect(toggleChoice(['asthma'], 'none')).toEqual(['none']);
    expect(toggleChoice(['none'], 'asthma')).toEqual(['asthma']);
    expect(toggleChoice(['asthma', 'other'], 'asthma')).toEqual(['other']);
  });
});

describe('the sealed intake payload', () => {
  const now = new Date('2026-03-04T10:20:30.000Z');
  const input = { context: makeContext(), localeId: 'pt-BR', consentVersion: '2026-03', consentLocaleId: 'pt-BR', now };

  it('carries the booking, the typed signature as the consent, and the time it was accepted', () => {
    const payload = buildIntakePayload(makeState(), input);
    expect(payload).toMatchObject({
      schema: 1,
      bookingId: 'booking-1',
      clientName: 'Ana Souza',
      localeId: 'pt-BR',
      formVersion: 'v7',
      isForMinor: false,
      consent: { textVersion: '2026-03', textLocaleId: 'pt-BR', acceptedAt: now.toISOString(), typedSignature: 'Ana Souza' },
      submittedAt: now.toISOString(),
    });
    expect(payload).not.toHaveProperty('minorName');
    expect(payload.consent).not.toHaveProperty('photos');
  });

  it('leaves out an unanswered optional question and the questions of the other audience', () => {
    const payload = buildIntakePayload(makeState({ answers: { allergies: false, conditions: ['none'], adultOnly: '  trimmed  ', guardianNote: 'minor only', medications: '   ' } }), input);
    expect(payload.answers).toEqual({ allergies: false, conditions: ['none'], adultOnly: 'trimmed' });
  });

  it('for a minor, the guardian signs and the photo agreement is explicit', () => {
    const state = makeState({
      isForMinor: true,
      minorName: ' Bia ',
      guardianName: ' Ana Souza ',
      photosConsent: false,
      answers: { allergies: false, conditions: ['none'], guardianNote: 'ok', adultOnly: 'ignored' },
    });
    const payload = buildIntakePayload(state, input);
    expect(payload).toMatchObject({ isForMinor: true, minorName: 'Bia', guardianName: 'Ana Souza', clientName: 'Ana Souza' });
    expect(payload.consent).toMatchObject({ typedSignature: 'Ana Souza', photos: false });
    expect(payload.answers).not.toHaveProperty('adultOnly');
  });

  it('adds the drawn signature only when there is one', () => {
    expect(buildIntakePayload(makeState(), input)).not.toHaveProperty('signaturePng');
    expect(buildIntakePayload(makeState({ signaturePng: 'AAAA' }), input)).toMatchObject({ signaturePng: 'AAAA' });
  });
});

describe('groupByDay', () => {
  it('groups by the calendar day in the professional zone, not in UTC, and sorts them', () => {
    // 02:30Z on the 5th is still the 4th evening in Sao Paulo (UTC-3), but already the 5th in Lisbon (UTC+0/+1).
    const slots = ['2026-03-05T02:30:00.000Z', '2026-03-04T13:00:00.000Z', '2026-03-04T21:00:00.000Z'];
    const saoPaulo = groupByDay(slots, 'America/Sao_Paulo');
    expect([...saoPaulo.keys()]).toEqual(['2026-03-04']);
    expect(saoPaulo.get('2026-03-04')).toEqual(['2026-03-04T13:00:00.000Z', '2026-03-04T21:00:00.000Z', '2026-03-05T02:30:00.000Z']);
    const lisbon = groupByDay(slots, 'Europe/Lisbon');
    expect([...lisbon.keys()]).toEqual(['2026-03-04', '2026-03-05']);
  });

  it('is empty for no slots and does not mutate its input', () => {
    expect(groupByDay([], 'UTC').size).toBe(0);
    const slots = ['2026-03-05T10:00:00.000Z', '2026-03-04T10:00:00.000Z'];
    groupByDay(slots, 'UTC');
    expect(slots[0]).toBe('2026-03-05T10:00:00.000Z');
  });
});
