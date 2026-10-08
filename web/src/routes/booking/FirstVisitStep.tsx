// Bk-7: a few non-clinical questions for the first visit, then the booking is created. Health answers are never
// asked here: they exist only in the sealed form (docs/10 section 2), and this screen says so.

import type { JSX } from 'preact';
import { useEffect, useState } from 'preact/hooks';

import type { HeardFrom } from '../../api/types';
import type { PublicProfile } from '../../api/types';
import { navigate, slugRoute } from '../../app/router';
import { allowedStep, FLOW_STEPS } from '../../app/booking/machine';
import { useBooking } from '../../app/booking/store';
import { Button } from '../../components/Button';
import { Chip } from '../../components/Choices';
import { ErrorNotice } from '../../components/Feedback';
import { TextArea } from '../../components/Field';
import { Screen, Title, TopBar, useDocumentTitle } from '../../components/Layout';
import { useRules } from '../../components/RuleList';
import { useI18n } from '../../i18n';
import { submitBooking } from './submit';

const HEARD: readonly { value: HeardFrom; key: string }[] = [
  { value: 'friend', key: 'bk7.heard.friend' },
  { value: 'instagram', key: 'bk7.heard.instagram' },
  { value: 'search', key: 'bk7.heard.search' },
  { value: 'passing', key: 'bk7.heard.passing' },
  { value: 'other', key: 'bk7.heard.other' },
];

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
  const freeLine = rules.lines.find((line) => line.kind === 'changes')?.text ?? '';

  const finish = async (withAnswers: boolean): Promise<void> => {
    setBusy(withAnswers ? 'confirm' : 'skip');
    setFailure(null);
    try {
      await submitBooking(profile, state, locale, withAnswers ? answers : { heardFrom: null, hadBefore: null, note: '' }, dispatch);
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
            {t('bk7.agree', { name: profile.firstName, line: freeLine }).trim()}
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

      <fieldset>
        <legend class="section">{t('bk7.heard', { name: profile.firstName })}</legend>
        <div class="chips mt-md" role="group" aria-label={t('bk7.heard', { name: profile.firstName })}>
          {HEARD.map((option) => (
            <Chip
              key={option.value}
              pressed={answers.heardFrom === option.value}
              testId={`heard-${option.value}`}
              onToggle={() => { dispatch({ type: 'setFirstVisit', answers: { ...answers, heardFrom: answers.heardFrom === option.value ? null : option.value } }); }}
            >
              {t(option.key)}
            </Chip>
          ))}
        </div>
      </fieldset>

      <fieldset>
        <legend class="section">{t('bk7.before')}</legend>
        <div class="chips mt-md" role="group" aria-label={t('bk7.before')}>
          <Chip pressed={answers.hadBefore === true} testId="before-yes" onToggle={() => { dispatch({ type: 'setFirstVisit', answers: { ...answers, hadBefore: answers.hadBefore === true ? null : true } }); }}>
            {t('bk7.before.yes')}
          </Chip>
          <Chip pressed={answers.hadBefore === false} testId="before-no" onToggle={() => { dispatch({ type: 'setFirstVisit', answers: { ...answers, hadBefore: answers.hadBefore === false ? null : false } }); }}>
            {t('bk7.before.no')}
          </Chip>
        </div>
      </fieldset>

      <TextArea
        label={t('bk7.note', { name: profile.firstName })}
        value={answers.note}
        onInput={(note) => { dispatch({ type: 'setFirstVisit', answers: { ...answers, note } }); }}
        placeholder={t('bk7.notePlaceholder')}
        hint={t('bk7.noteWarn', { name: profile.firstName })}
        maxLength={300}
        sensitive
        testId="preferences"
      />

      <ErrorNotice error={failure} />
    </Screen>
  );
}
