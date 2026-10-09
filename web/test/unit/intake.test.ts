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

  it('lists every required question left open, and nothing else: no signature, no consent to tick (D55)', () => {
    const problems = intakeProblems(makeState({ answers: {} }), questions);
    expect(problems).toEqual([
      { field: 'question', key: 'allergies' },
      { field: 'question', key: 'conditions' },
      { field: 'question', key: 'adultOnly' },
    ]);
  });

  it('a minor visit asks only for the young person\'s name on top of the questions: no guardian signature', () => {
    const state = makeState({ isForMinor: true, answers: { allergies: true, conditions: ['asthma'], guardianNote: 'ok' } });
    expect(intakeProblems(state, questions)).toEqual([{ field: 'minorName' }]);
    expect(intakeProblems({ ...state, minorName: 'Bia' }, questions)).toEqual([]);
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
  const input = { context: makeContext(), localeId: 'pt-BR', now };

  it('carries the booking, the answers and the time, and no consent, agreement or signature of any kind (D55)', () => {
    const payload = buildIntakePayload(makeState(), input);
    expect(payload).toEqual({
      schema: 2,
      bookingId: 'booking-1',
      localeId: 'pt-BR',
      formVersion: 'v7',
      answers: { allergies: false, conditions: ['none'], adultOnly: 'fine' },
      isForMinor: false,
      submittedAt: now.toISOString(),
    });
    for (const gone of ['consent', 'signaturePng', 'clientName', 'guardianName', 'typedSignature', 'textVersion']) {
      expect(JSON.stringify(payload)).not.toContain(gone);
    }
  });

  it('leaves out an unanswered optional question and the questions of the other audience', () => {
    const payload = buildIntakePayload(makeState({ answers: { allergies: false, conditions: ['none'], adultOnly: '  trimmed  ', guardianNote: 'minor only', medications: '   ' } }), input);
    expect(payload.answers).toEqual({ allergies: false, conditions: ['none'], adultOnly: 'trimmed' });
  });

  it('for a minor, carries the young person\'s name trimmed and the minor questions only; no guardian text or name', () => {
    const state = makeState({
      isForMinor: true,
      minorName: ' Bia ',
      answers: { allergies: false, conditions: ['none'], guardianNote: 'ok', adultOnly: 'ignored' },
    });
    const payload = buildIntakePayload(state, input);
    expect(payload).toMatchObject({ isForMinor: true, minorName: 'Bia' });
    expect(payload).not.toHaveProperty('guardianName');
    expect(payload.answers).not.toHaveProperty('adultOnly');
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
