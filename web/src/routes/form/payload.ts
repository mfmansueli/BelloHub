// The health form's rules, pure: which questions apply, what is missing, and the `IntakePayload` that gets sealed
// (docs/06 section 3.4). Nothing here stores or sends anything; the answers exist only in the component that calls it.

import type { FormContext, FormQuestion } from '../../api/types';
import type { AnswerValue, IntakePayload } from '../../crypto/envelope';

export interface IntakeState {
  readonly answers: Readonly<Record<string, AnswerValue>>;
  readonly isForMinor: boolean;
  readonly minorName: string;
  /** The guardian's full name and relationship, typed as her signature when the visit is for a minor. */
  readonly guardianName: string;
  /** The client's typed full name: her signature when the visit is for an adult. */
  readonly typedSignature: string;
  readonly consent: boolean;
  /** The guardian's optional agreement to photos of the minor. */
  readonly photosConsent: boolean;
  readonly signaturePng: string | null;
}

export const EMPTY_INTAKE: IntakeState = {
  answers: {},
  isForMinor: false,
  minorName: '',
  guardianName: '',
  typedSignature: '',
  consent: false,
  photosConsent: false,
  signaturePng: null,
};

export function visibleQuestions(questions: readonly FormQuestion[], isForMinor: boolean): FormQuestion[] {
  return questions.filter((question) => question.audience === undefined || (question.audience === 'minor') === isForMinor);
}

export function isAnswered(value: AnswerValue | undefined): boolean {
  if (value === undefined) return false;
  if (typeof value === 'string') return value.trim() !== '';
  if (typeof value === 'boolean') return true;
  return value.length > 0;
}

export type IntakeProblem =
  | { readonly field: 'question'; readonly key: string }
  | { readonly field: 'minorName' }
  | { readonly field: 'guardianName' }
  | { readonly field: 'typedSignature' }
  | { readonly field: 'consent' };

/** What stands between her and "Submit": every required question, the minor's name, the consent and the signature. */
export function intakeProblems(state: IntakeState, questions: readonly FormQuestion[]): IntakeProblem[] {
  const problems: IntakeProblem[] = [];
  for (const question of visibleQuestions(questions, state.isForMinor)) {
    if (question.required === true && !isAnswered(state.answers[question.key])) problems.push({ field: 'question', key: question.key });
  }
  if (state.isForMinor) {
    if (state.minorName.trim().length < 2) problems.push({ field: 'minorName' });
    if (state.guardianName.trim().length < 2) problems.push({ field: 'guardianName' });
  } else if (state.typedSignature.trim().length < 2) {
    problems.push({ field: 'typedSignature' });
  }
  if (!state.consent) problems.push({ field: 'consent' });
  return problems;
}

export interface BuildContext {
  readonly context: FormContext;
  readonly localeId: string;
  /** The version of the consent text that was shown, from the legal file itself. */
  readonly consentVersion: string;
  /** The language of the consent text that was shown (the page language, or English when it was missing). */
  readonly consentLocaleId: string;
  readonly now: Date;
}

export function buildIntakePayload(state: IntakeState, input: BuildContext): IntakePayload {
  const visible = visibleQuestions(input.context.intake.questions, state.isForMinor);
  const answers: Record<string, AnswerValue> = {};
  for (const question of visible) {
    const value = state.answers[question.key];
    // An unanswered optional question is left out, never sent as an empty string.
    if (value !== undefined && isAnswered(value)) answers[question.key] = typeof value === 'string' ? value.trim() : value;
  }
  const signature = state.isForMinor ? state.guardianName.trim() : state.typedSignature.trim();
  const submittedAt = input.now.toISOString();
  return {
    schema: 1,
    bookingId: input.context.bookingId,
    clientName: signature,
    localeId: input.localeId,
    formVersion: input.context.intake.formVersion,
    answers,
    isForMinor: state.isForMinor,
    ...(state.isForMinor ? { minorName: state.minorName.trim(), guardianName: state.guardianName.trim() } : {}),
    consent: {
      textVersion: input.consentVersion,
      textLocaleId: input.consentLocaleId,
      acceptedAt: submittedAt,
      typedSignature: signature,
      ...(state.isForMinor ? { photos: state.photosConsent } : {}),
    },
    ...(state.signaturePng === null ? {} : { signaturePng: state.signaturePng }),
    submittedAt,
  };
}
