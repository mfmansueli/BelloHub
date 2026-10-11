// Bk-7: a few non-clinical questions for the first visit, then the booking is created. Health answers are never
// asked here: they exist only in the sealed form (docs/10 section 2), and this screen says so. D45: the page does not
// ask "how did you hear" or "been before" (the professional asks in person); only the optional note travels (API.md 5.8).

import type { JSX } from 'preact';
import { useEffect, useState } from 'preact/hooks';

import type { PublicProfile } from '../../api/types';
import { navigate, slugRoute } from '../../app/router';
import { allowedStep, EMPTY_FIRST_VISIT, FLOW_STEPS } from '../../app/booking/machine';
import { useBooking } from '../../app/booking/store';
import { Button } from '../../components/Button';
import { ErrorNotice } from '../../components/Feedback';
import { TextArea } from '../../components/Field';
import { Screen, Title, TopBar, useDocumentTitle } from '../../components/Layout';
import { useRules } from '../../components/RuleList';
import { useI18n } from '../../i18n';
import { NOTE_MAX_LENGTH, submitBooking } from './submit';

export function FirstVisitStep({ profile }: { profile: PublicProfile }): JSX.Element | null {
  const { t, locale } = useI18n();
  const [state, dispatch] = useBooking(profile.slug, profile.regionCode);
  const rules = useRules(profile.rules, profile);
  const answers = state.firstVisit;
  useDocumentTitle(t('bk7.title', { name: profile.firstName }));

  const redirect = allowedStep('questions', state) !== 'questions';
  useEffect(() => {
    if (redirect) navigate(slugRoute(profile.slug, 'verify'), true);
  }, [redirect, profile.slug]);

  const [busy, setBusy] = useState<'confirm' | 'skip' | null>(null);
  const [failure, setFailure] = useState<unknown>(null);
  if (redirect) return null;

  const service = profile.services.find((candidate) => candidate.id === state.draft.serviceId);

  const finish = async (withAnswers: boolean): Promise<void> => {
    setBusy(withAnswers ? 'confirm' : 'skip');
    setFailure(null);
    try {
      await submitBooking(profile, state, locale, withAnswers ? answers : EMPTY_FIRST_VISIT, dispatch);
    } catch (error) {
      setFailure(error);
    } finally {
      setBusy(null);
    }
  };

  return (
    <Screen
      top={<TopBar back={slugRoute(profile.slug, 'you')} step={{ current: 5, total: FLOW_STEPS }} />}
      bar={
        <>
          <p class="bar-note" lang={rules.lang}>
            {t('bk7.agree', { name: profile.firstName, line: '' }).trim()}
          </p>
          <Button busy={busy === 'confirm'} onClick={() => { void finish(true); }} testId="confirm">
            {t('bk7.confirm')}
          </Button>
          <Button variant="tertiary" busy={busy === 'skip'} onClick={() => { void finish(false); }} testId="skip">
            {t('bk7.skip')}
          </Button>
        </>
      }
    >
      <div>
        <Title>{t('bk7.title', { name: profile.firstName })}</Title>
        <p class="lead">{t('bk7.sub', { service: service?.name ?? '' })}</p>
      </div>

      <TextArea
        label={t('bk7.note', { name: profile.firstName })}
        value={answers.note}
        onInput={(note) => { dispatch({ type: 'setFirstVisit', answers: { ...answers, note } }); }}
        placeholder={t('bk7.notePlaceholder')}
        hint={t('bk7.noteWarn', { name: profile.firstName })}
        maxLength={NOTE_MAX_LENGTH}
        sensitive
        testId="preferences"
      />

      <ErrorNotice error={failure} />
    </Screen>
  );
}
