// The health form's rules, pure: which questions apply, what is missing, and the `IntakePayload` that gets sealed
// (docs/06 section 3.4). Nothing here stores or sends anything; the answers exist only in the component that calls it.
// D55: there is no consent text, agreement or signature here. Consents are the professional's own business.

import type { FormContext, FormQuestion } from '../../api/types';
import type { AnswerValue, IntakePayload } from '../../crypto/envelope';

export interface IntakeState {
  readonly answers: Readonly<Record<string, AnswerValue>>;
  readonly isForMinor: boolean;
  readonly minorName: string;
}

export const EMPTY_INTAKE: IntakeState = {
  answers: {},
  isForMinor: false,
  minorName: '',
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

/** `none` is exclusive in a multiple choice: choosing it clears the others, choosing another clears it. */
export function toggleChoice(current: readonly string[], value: string): string[] {
  if (current.includes(value)) return current.filter((item) => item !== value);
  if (value === 'none') return ['none'];
  return [...current.filter((item) => item !== 'none'), value];
}

export type IntakeProblem = { readonly field: 'question'; readonly key: string } | { readonly field: 'minorName' };

/** What stands between her and "Submit": every required question and, for a minor, the minor's name. */
export function intakeProblems(state: IntakeState, questions: readonly FormQuestion[]): IntakeProblem[] {
  const problems: IntakeProblem[] = [];
  for (const question of visibleQuestions(questions, state.isForMinor)) {
    if (question.required === true && !isAnswered(state.answers[question.key])) problems.push({ field: 'question', key: question.key });
  }
  if (state.isForMinor && state.minorName.trim().length < 2) problems.push({ field: 'minorName' });
  return problems;
}

export interface BuildContext {
  readonly context: FormContext;
  readonly localeId: string;
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
  return {
    schema: 2,
    bookingId: input.context.bookingId,
    localeId: input.localeId,
    formVersion: input.context.intake.formVersion,
    answers,
    isForMinor: state.isForMinor,
    ...(state.isForMinor ? { minorName: state.minorName.trim() } : {}),
    submittedAt: input.now.toISOString(),
  };
}
