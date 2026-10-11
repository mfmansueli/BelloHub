// Cl-4: the health form, sealed in her browser (docs/06 section 3, docs/10 section 5).
//
//  - The questions come from the professional's template; the answers live in this component's state only.
//    No localStorage, sessionStorage, cookie, URL, console or error report ever sees one.
//  - Autofill and spellcheck are off on every field that can hold a health answer.
//  - On submit the answers become one JSON payload, sealed with the professional's public key by hpke-js (a lazy
//    chunk), and the only thing that leaves the browser is the envelope.
//  - No consent text, agreement or signature (D55): consents are the professional's own business, handled in person.
//    A visit for someone under 18 only switches the questions and asks the young person's name.

import type { JSX } from 'preact';
import { useRef, useState } from 'preact/hooks';

import { ApiError } from '../../api/errors';
import type { FormContext } from '../../api/types';
import { TokenLayout } from '../../app/TokenLayout';
import { manageRoute } from '../../app/router';
import { api } from '../../api/client';
import { SealError } from '../../crypto/envelope';
import { sealInBrowser, sendEnvelope } from '../../crypto/submit';
import type { SealedEnvelope } from '../../api/types';
import { Button, LinkButton } from '../../components/Button';
import { Segmented } from '../../components/Choices';
import { ErrorNotice, Notice, Seal } from '../../components/Feedback';
import { TextField } from '../../components/Field';
import { Icon } from '../../components/Icon';
import { Footer, ProHeader, Screen, Title, useDocumentTitle } from '../../components/Layout';
import { useI18n } from '../../i18n';
import { ltr } from '../../lib/bidi';
import { EMPTY_INTAKE, buildIntakePayload, intakeProblems, visibleQuestions, type IntakeProblem, type IntakeState } from './payload';
import { QuestionCard } from './QuestionCard';

export function IntakePage({ token }: { token: string }): JSX.Element {
  return (
    <TokenLayout load={() => api.getFormContext(token)} deps={[token]} professionalOf={(context) => context.professional}>
      {(context) => <Intake token={token} context={context} />}
    </TokenLayout>
  );
}

function problemId(problem: IntakeProblem): string {
  switch (problem.field) {
    case 'question':
      return `q-${problem.key}`;
    case 'minorName':
      return 'minor-name';
  }
}

function Intake({ token, context }: { token: string; context: FormContext }): JSX.Element {
  const { t, locale } = useI18n();
  const pro = context.professional;
  const [state, setState] = useState<IntakeState>(EMPTY_INTAKE);
  const [redo, setRedo] = useState(false);
  const [showErrors, setShowErrors] = useState(false);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<unknown>(null);
  const [sealFailed, setSealFailed] = useState(false);
  const [done, setDone] = useState(false);
  const envelope = useRef<SealedEnvelope | null>(null);
  useDocumentTitle(done ? t('cl4.thanks') : t('cl4.title'));

  const questions = context.intake.questions;
  const problems = intakeProblems(state, questions);
  const set = (change: Partial<IntakeState>): void => {
    // A changed answer makes a sealed envelope stale: seal again from what is on the screen.
    envelope.current = null;
    setState((current) => ({ ...current, ...change }));
  };

  if (!context.intake.available) {
    return (
      <Screen top={<header class="topbar"><ProHeader professional={pro} /></header>}>
        <FullNote title={t('cl4.closed.title')} text={t('cl4.closed.text', { name: pro.firstName })} back={token} />
      </Screen>
    );
  }

  if (done) {
    return (
      <Screen top={<header class="topbar"><ProHeader professional={pro} /></header>}>
        <div class="stack">
          <Seal />
          <Title>{t('cl4.thanks')}</Title>
          <p class="lead" data-testid="sealed-message">{t('cl4.sealed', { name: pro.firstName })}</p>
        </div>
        <LinkButton to={manageRoute(token)} testId="back-to-appointment">{t('cl4.back')}</LinkButton>
        <Footer />
      </Screen>
    );
  }

  if (context.intake.completedWithin12Months && !redo) {
    return (
      <Screen top={<header class="topbar"><ProHeader professional={pro} /></header>}>
        <div class="stack">
          <Title>{t('cl4.already.title')}</Title>
          <p class="lead" data-testid="already">{t('cl4.already.text', { name: pro.firstName })}</p>
        </div>
        <div class="stack-sm">
          <LinkButton to={manageRoute(token)}>{t('cl4.back')}</LinkButton>
          <Button variant="tertiary" onClick={() => { setRedo(true); }} testId="redo">{t('cl4.redo')}</Button>
        </div>
        <Footer />
      </Screen>
    );
  }

  const submit = async (): Promise<void> => {
    if (problems.length > 0) {
      setShowErrors(true);
      const first = problems[0];
      if (first !== undefined) window.setTimeout(() => { document.getElementById(problemId(first))?.focus(); }, 0);
      return;
    }
    setBusy(true);
    setFailure(null);
    setSealFailed(false);
    try {
      if (envelope.current === null) {
        const payload = buildIntakePayload(state, { context, localeId: locale, now: new Date() });
        envelope.current = await sealInBrowser({ kind: 'intake', payload, inboxKey: context.inboxKey });
      }
      await sendEnvelope(token, envelope.current);
      // Done: nothing she typed stays in memory.
      envelope.current = null;
      setState(EMPTY_INTAKE);
      setDone(true);
    } catch (error) {
      if (error instanceof SealError) setSealFailed(true);
      else if (error instanceof ApiError && error.code === 'keyMismatch') {
        // Her key was rotated since this page loaded: the sealed bytes are for the old key. Forget them and her
        // cached page, so a retry seals to the key a reload brings.
        envelope.current = null;
        api.forgetPublicPage(pro.slug);
        setSealFailed(true);
      } else setFailure(error instanceof ApiError ? error : new ApiError('network'));
    } finally {
      setBusy(false);
    }
  };

  const error = (problem: IntakeProblem['field'], text: string): string | undefined => (showErrors && problems.some((p) => p.field === problem) ? text : undefined);

  return (
    <Screen top={<header class="topbar"><ProHeader professional={pro} /></header>} bar={<Button busy={busy} onClick={() => { void submit(); }} testId="submit-intake">{busy ? t('cl4.sealing') : t('cl4.submit', { name: pro.firstName })}</Button>}>
      <div>
        <Title>{t('cl4.title')}</Title>
        <p class="lead">{t('cl4.sub', { name: pro.firstName })}</p>
      </div>

      {visibleQuestions(questions, state.isForMinor).map((question) => (
        <QuestionCard
          key={question.key}
          question={question}
          value={state.answers[question.key]}
          pageDefault={pro.defaultLocale}
          showError={showErrors}
          onChange={(value) => {
            const others = Object.entries(state.answers).filter(([key]) => key !== question.key);
            set({ answers: Object.fromEntries(value === undefined ? others : [...others, [question.key, value]]) });
          }}
        />
      ))}

      <fieldset class="question">
        <legend class="label">{t('cl4.minor.title')}</legend>
        <Segmented
          name="minor"
          legend={t('cl4.minor.title')}
          value={state.isForMinor ? 'yes' : 'no'}
          options={[{ value: 'no', label: t('common.no') }, { value: 'yes', label: t('common.yes') }]}
          onChange={(value) => { set({ isForMinor: value === 'yes' }); }}
          testId="minor"
        />
        {state.isForMinor ? (
          <div class="stack mt-md">
            <p class="meta">{t('cl4.minor.text')}</p>
            <TextField label={t('cl4.minor.name')} id="minor-name" value={state.minorName} onInput={(value) => { set({ minorName: value }); }} sensitive error={error('minorName', t('cl4.err.name'))} testId="minor-name" />
          </div>
        ) : null}
      </fieldset>

      {sealFailed ? <Notice kind="warning" icon="alert" live="assertive" testId="seal-failed">{t('cl4.err.key', { name: pro.firstName })}</Notice> : null}
      <ErrorNotice error={failure} />
      {failure === null ? null : <p class="meta" data-testid="retry-hint">{t('cl4.err.send')}</p>}

      <p class="well well-icon">
        <Icon name="lock" />
        <span>
          {t('cl4.keyHelp', { name: pro.firstName })} <span data-testid="key-id">{t('cl4.keyId', { keyId: ltr(context.inboxKey.keyId) })}</span>
        </span>
      </p>
    </Screen>
  );
}

function FullNote({ title, text, back }: { title: string; text: string; back: string }): JSX.Element {
  const { t } = useI18n();
  return (
    <div class="state">
      <Title>{title}</Title>
      <p class="lead">{text}</p>
      <LinkButton to={manageRoute(back)} variant="secondary">{t('cl4.back')}</LinkButton>
    </div>
  );
}
