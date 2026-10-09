// Cl-5: the skin check-in after a visit (docs/10 section 5). One tap says how it feels; a note and a photo are
// optional. The answer, the note and the photo are sealed in her browser like the health form: nothing she says
// here is readable by the server. The photo is re-encoded in a canvas (JPEG, at most 1.5 MB), which drops EXIF.

import type { JSX } from 'preact';
import { useRef, useState } from 'preact/hooks';

import { ApiError } from '../../api/errors';
import { api } from '../../api/client';
import type { FormContext, SealedEnvelope } from '../../api/types';
import { TokenLayout } from '../../app/TokenLayout';
import { manageRoute } from '../../app/router';
import { SealError, type Feeling } from '../../crypto/envelope';
import { sealInBrowser, sendEnvelope } from '../../crypto/submit';
import { Button, LinkButton } from '../../components/Button';
import { ErrorNotice, Notice, Seal } from '../../components/Feedback';
import { TextField } from '../../components/Field';
import { Icon } from '../../components/Icon';
import { Footer, ProHeader, Screen, Title, useDocumentTitle } from '../../components/Layout';
import { useI18n } from '../../i18n';
import { ltr } from '../../lib/bidi';
import { reencodePhoto, type EncodedPhoto } from '../../lib/image';

const FEELINGS: readonly { value: Feeling; key: string; tone: 'good' | 'okay' | 'irritated' | 'reaction' }[] = [
  { value: 'good', key: 'cl5.good', tone: 'good' },
  { value: 'okay', key: 'cl5.okay', tone: 'okay' },
  { value: 'irritated', key: 'cl5.irritated', tone: 'irritated' },
  { value: 'reaction', key: 'cl5.reaction', tone: 'reaction' },
];

export function CheckInPage({ token }: { token: string }): JSX.Element {
  return (
    <TokenLayout load={() => api.getFormContext(token)} deps={[token]} professionalOf={(context) => context.professional}>
      {(context) => <CheckIn token={token} context={context} />}
    </TokenLayout>
  );
}

function CheckIn({ token, context }: { token: string; context: FormContext }): JSX.Element {
  const { t } = useI18n();
  const pro = context.professional;
  const [feeling, setFeeling] = useState<Feeling | null>(null);
  const [note, setNote] = useState('');
  const [photo, setPhoto] = useState<EncodedPhoto | null>(null);
  const [photoError, setPhotoError] = useState(false);
  const [missing, setMissing] = useState(false);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<unknown>(null);
  const [sealFailed, setSealFailed] = useState(false);
  const [done, setDone] = useState<Feeling | null>(null);
  const envelope = useRef<SealedEnvelope | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);
  useDocumentTitle(done === null ? t('cl5.title') : t('cl5.thanks', { name: context.client.firstName }));

  if (!context.checkIn.available) {
    return (
      <Screen top={<header class="topbar"><ProHeader professional={pro} /></header>}>
        <div class="state">
          <Title>{t('cl5.closed.title')}</Title>
          <p class="lead">{t('cl5.closed.text', { name: pro.firstName })}</p>
          <LinkButton to={manageRoute(token)} variant="secondary">{t('cl5.back')}</LinkButton>
        </div>
      </Screen>
    );
  }

  if (done !== null) {
    const care = done === 'irritated' || done === 'reaction';
    return (
      <Screen top={<header class="topbar"><ProHeader professional={pro} /></header>}>
        <div class="stack">
          <Seal />
          <Title>{t('cl5.thanks', { name: context.client.firstName })}</Title>
          <p class="lead" data-testid="checkin-reply">{care ? t('cl5.reply.care', { name: pro.firstName }) : t('cl5.reply.ok', { name: pro.firstName })}</p>
        </div>
        <LinkButton to={manageRoute(token)} testId="back-to-appointment">{t('cl5.back')}</LinkButton>
        <Footer />
      </Screen>
    );
  }

  const choose = async (file: File | undefined): Promise<void> => {
    if (file === undefined) return;
    setPhotoError(false);
    try {
      envelope.current = null;
      setPhoto(await reencodePhoto(file));
    } catch {
      setPhoto(null);
      setPhotoError(true);
    }
  };

  const send = async (): Promise<void> => {
    if (feeling === null) {
      setMissing(true);
      return;
    }
    setBusy(true);
    setFailure(null);
    setSealFailed(false);
    try {
      if (envelope.current === null) {
        const trimmed = note.trim();
        const payload = {
          schema: 1 as const,
          bookingId: context.bookingId,
          feeling,
          ...(trimmed === '' ? {} : { note: trimmed }),
          ...(photo === null ? {} : { photoJpeg: photo.base64 }),
          submittedAt: new Date().toISOString(),
        };
        envelope.current = await sealInBrowser({ kind: 'checkin', payload, inboxKey: context.inboxKey, hasPhoto: photo !== null });
      }
      await sendEnvelope(token, envelope.current);
      envelope.current = null;
      setNote('');
      setPhoto(null);
      setDone(feeling);
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

  const worried = feeling === 'irritated' || feeling === 'reaction';
  return (
    <Screen
      top={<header class="topbar"><ProHeader professional={pro} /></header>}
      bar={<Button busy={busy} onClick={() => { void send(); }} testId="send-checkin">{t('cl5.send', { name: pro.firstName })}</Button>}
    >
      <div>
        <Title>{t('cl5.title')}</Title>
        <p class="lead">{t('cl5.sub', { name: context.client.firstName, service: context.checkIn.serviceName ?? '' })}</p>
      </div>

      <fieldset>
        <legend class="sr-only">{t('cl5.title')}</legend>
        <div class="stack-sm" role="radiogroup" aria-label={t('cl5.title')}>
          {FEELINGS.map((option) => (
            <label key={option.value} class="option">
              <input type="radio" name="feeling" value={option.value} checked={feeling === option.value} data-testid={`feeling-${option.value}`} onChange={() => { setFeeling(option.value); setMissing(false); envelope.current = null; }} />
              <span class="mark" aria-hidden="true" />
              <span class="body"><b>{t(option.key)}</b></span>
            </label>
          ))}
        </div>
      </fieldset>
      {missing ? <Notice kind="warning" icon="alert" live="assertive" testId="feeling-missing">{t('cl5.err.pick')}</Notice> : null}

      {worried ? (
        <Notice kind="safety" icon="alert" live="polite" testId="worried">
          {t('cl5.worried', { name: pro.firstName })}
        </Notice>
      ) : null}

      <TextField label={t('cl5.anything')} optional value={note} onInput={(value) => { envelope.current = null; setNote(value); }} placeholder={t('cl5.notePlaceholder')} sensitive testId="checkin-note" />

      <div class="stack-sm">
        {photo === null ? null : (
          <div class="photo">
            <img src={photo.dataUrl} alt={t('cl5.photoAlt')} data-testid="photo-preview" />
          </div>
        )}
        <input
          ref={fileInput}
          class="sr-only"
          type="file"
          accept="image/*"
          id="photo-input"
          // The visible "Add a photo" button opens this picker; the input itself is out of the reading order.
          aria-hidden="true"
          tabIndex={-1}
          data-testid="photo-input"
          onChange={(event) => {
            void choose(event.currentTarget.files?.[0]);
            event.currentTarget.value = '';
          }}
        />
        <div class="row-flex">
          <Button variant="secondary" inline onClick={() => { fileInput.current?.click(); }} testId="add-photo">
            <Icon name="camera" />
            {photo === null ? t('cl5.addPhoto') : t('cl5.photoAdded')}
          </Button>
          {photo === null ? null : (
            <Button variant="tertiary" inline onClick={() => { envelope.current = null; setPhoto(null); }} testId="remove-photo">
              {t('cl5.removePhoto')}
            </Button>
          )}
        </div>
        {photoError ? <p class="field-error" role="alert"><Icon name="alert" /><span>{t('cl5.err.photo')}</span></p> : null}
      </div>

      {sealFailed ? <Notice kind="warning" icon="alert" live="assertive" testId="seal-failed">{t('cl4.err.key', { name: pro.firstName })}</Notice> : null}
      <ErrorNotice error={failure} />

      <p class="well well-icon">
        <Icon name="lock" />
        <span>
          {t('cl5.sealNote', { name: pro.firstName })} <span data-testid="key-id">{t('cl4.keyId', { keyId: ltr(context.inboxKey.keyId) })}</span>
        </span>
      </p>
    </Screen>
  );
}
