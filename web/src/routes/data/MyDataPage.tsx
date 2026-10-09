// Cl-7: "Your information". What the professional keeps about her (named, never shown), and two requests: a copy
// of her data and its deletion (docs/06 section 3.4). A request is sealed in her browser like a health form (kind
// `datarequest`), so even that the server cannot read; it carries her name and the phone she booked with so the
// professional can find her record. The page never offers to delete the professional's records itself.

import type { JSX } from 'preact';
import { useRef, useState } from 'preact/hooks';

import { api } from '../../api/client';
import { ApiError } from '../../api/errors';
import type { FormContext, SealedEnvelope } from '../../api/types';
import { TokenLayout } from '../../app/TokenLayout';
import { manageRoute } from '../../app/router';
import { SealError } from '../../crypto/envelope';
import { sealInBrowser, sendEnvelope } from '../../crypto/submit';
import { Button, LinkButton } from '../../components/Button';
import { ErrorNotice, Notice } from '../../components/Feedback';
import { PhoneField, TextArea, TextField } from '../../components/Field';
import { Icon, type IconName } from '../../components/Icon';
import { Footer, ProHeader, Screen, Title, useDocumentTitle } from '../../components/Layout';
import { LegalDocumentView } from '../../components/Legal';
import { Sheet } from '../../components/Sheet';
import { useI18n } from '../../i18n';
import { ltr } from '../../lib/bidi';
import { normalizePhone, phoneRegion } from '../../lib/phone';

export function MyDataPage({ token }: { token: string }): JSX.Element {
  return (
    <TokenLayout load={() => api.getFormContext(token)} deps={[token]} professionalOf={(context) => context.professional}>
      {(context) => <MyData token={token} context={context} />}
    </TokenLayout>
  );
}

type Request = 'copy' | 'delete';

function MyData({ token, context }: { token: string; context: FormContext }): JSX.Element {
  const { t } = useI18n();
  const pro = context.professional;
  const [open, setOpen] = useState<Request | null>(null);
  const [sent, setSent] = useState<ReadonlySet<Request>>(new Set());
  useDocumentTitle(t('cl7.title'));

  const rows: readonly { icon: IconName; title: string; sub: string }[] = [
    { icon: 'user', title: t('cl7.contact'), sub: t('cl7.contactSub') },
    {
      icon: 'shield',
      title: t('cl7.health'),
      sub: t('cl7.healthSub', { name: pro.firstName }),
    },
    { icon: 'doc', title: t('cl7.records'), sub: t('cl7.recordsSub', { name: pro.firstName }) },
    { icon: 'image', title: t('cl7.photos'), sub: t('cl7.photosSub', { name: pro.firstName }) },
  ];

  return (
    <Screen top={<header class="topbar"><ProHeader professional={pro} /></header>}>
      <div>
        <Title>{t('cl7.title')}</Title>
        <p class="lead">{t('cl7.sub', { name: pro.firstName })}</p>
      </div>

      <section aria-labelledby="keeps-title">
        <h2 id="keeps-title" class="section">{t('cl7.keeps', { name: pro.firstName })}</h2>
        <ul class="card card-flush list mt-sm">
          {rows.map((row) => (
            <li key={row.title} class="list-row">
              <Icon name={row.icon} />
              <span class="grow"><b>{row.title}</b><span class="sub">{row.sub}</span></span>
            </li>
          ))}
        </ul>
      </section>

      <section aria-labelledby="choices-title">
        <h2 id="choices-title" class="section">{t('cl7.choices')}</h2>
        <div class="card mt-sm">
          <b class="strong">{t('cl7.portfolio', { name: pro.firstName })}</b>
          <p class="meta">{t('cl7.portfolioSub', { name: pro.firstName })}</p>
        </div>
      </section>

      <div class="stack-sm">
        <Button variant="secondary" disabled={sent.has('copy')} onClick={() => { setOpen('copy'); }} testId="ask-copy">
          <Icon name="download" />
          {sent.has('copy') ? t('cl7.sentCopy', { name: pro.firstName }) : t('cl7.copy', { name: pro.firstName })}
        </Button>
        <Button variant="tertiary" disabled={sent.has('delete')} onClick={() => { setOpen('delete'); }} testId="ask-delete">
          {sent.has('delete') ? t('cl7.sentDelete', { name: pro.firstName }) : t('cl7.delete', { name: pro.firstName })}
        </Button>
      </div>

      <details class="well">
        <summary class="strong">{t('cl7.how')}</summary>
        <div class="mt-sm">
          <LegalDocumentView document="data-requests" professionalName={pro.displayName} />
        </div>
      </details>

      <p class="well well-icon">
        <Icon name="lock" />
        <span>
          {t('cl7.sealed', { name: pro.firstName })} <span data-testid="key-id">{t('cl4.keyId', { keyId: ltr(context.inboxKey.keyId) })}</span>
        </span>
      </p>
      <LinkButton to={manageRoute(token)} variant="tertiary">{t('cl4.back')}</LinkButton>
      <Footer />

      {open === null ? null : (
        <RequestSheet
          kind={open}
          token={token}
          context={context}
          onClose={() => { setOpen(null); }}
          onSent={() => { setSent((current) => new Set([...current, open])); setOpen(null); }}
        />
      )}
    </Screen>
  );
}

interface SheetProps {
  readonly kind: Request;
  readonly token: string;
  readonly context: FormContext;
  readonly onClose: () => void;
  readonly onSent: () => void;
}

function RequestSheet({ kind, token, context, onClose, onSent }: SheetProps): JSX.Element {
  const { t } = useI18n();
  const pro = context.professional;
  const [name, setName] = useState('');
  const [country, setCountry] = useState(pro.regionCode);
  const [phone, setPhone] = useState('');
  const [note, setNote] = useState('');
  const [errors, setErrors] = useState<{ name?: string; phone?: string }>({});
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<unknown>(null);
  const [sealFailed, setSealFailed] = useState(false);
  const envelope = useRef<SealedEnvelope | null>(null);

  const submit = async (): Promise<void> => {
    const next: { name?: string; phone?: string } = {};
    if (name.trim().length < 2) next.name = t('cl4.err.name');
    const normalized = normalizePhone(phone, phoneRegion(country));
    if (!normalized.ok) next.phone = t('bk5.err.phone');
    setErrors(next);
    if (Object.keys(next).length > 0 || !normalized.ok) return;
    setBusy(true);
    setFailure(null);
    setSealFailed(false);
    try {
      if (envelope.current === null) {
        const trimmed = note.trim();
        envelope.current = await sealInBrowser({
          kind: 'datarequest',
          payload: { schema: 1 as const, request: kind, name: name.trim(), phone: normalized.e164, ...(trimmed === '' ? {} : { note: trimmed }), submittedAt: new Date().toISOString() },
          inboxKey: context.inboxKey,
        });
      }
      await sendEnvelope(token, envelope.current);
      envelope.current = null;
      onSent();
    } catch (error) {
      if (error instanceof SealError) setSealFailed(true);
      else setFailure(error instanceof ApiError ? error : new ApiError('network'));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Sheet open onClose={onClose} title={kind === 'delete' ? t('cl7.form.title.delete', { name: pro.firstName }) : t('cl7.form.title.copy', { name: pro.firstName })} testId="request-sheet" closeButton={false}>
      <form
        class="stack mt-md"
        noValidate
        onSubmit={(event) => {
          event.preventDefault();
          void submit();
        }}
      >
        <p class="lead">{kind === 'delete' ? t('cl7.form.text.delete', { name: pro.firstName }) : t('cl7.form.text.copy', { name: pro.firstName })}</p>
        <TextField label={t('cl7.form.name')} value={name} onInput={(value) => { envelope.current = null; setName(value); }} sensitive error={errors.name} testId="request-name" />
        <PhoneField label={t('cl7.form.phone')} countryLabel={t('bk5.phoneCountry')} country={country} input={phone} defaultCountry={pro.regionCode} error={errors.phone} testId="request-phone" onChange={(c, p) => { envelope.current = null; setCountry(c); setPhone(p); }} />
        <TextArea label={t('cl7.form.note')} optional value={note} onInput={(value) => { envelope.current = null; setNote(value); }} sensitive maxLength={500} rows={3} testId="request-note" />
        {sealFailed ? <Notice kind="warning" icon="alert" live="assertive">{t('cl4.err.key', { name: pro.firstName })}</Notice> : null}
        <ErrorNotice error={failure} />
        <Button type="submit" busy={busy} testId="send-request">{t('cl7.send')}</Button>
        <Button variant="tertiary" onClick={onClose} testId="cancel-request">{t('common.cancel')}</Button>
      </form>
    </Sheet>
  );
}
