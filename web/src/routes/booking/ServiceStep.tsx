// Bk-2: choose a service and the extras that add time (D19). Guests are chosen here too, not on the details
// screen as in the prototype, because they add time and the times offered on the next screen depend on the total.

import type { JSX } from 'preact';
import { useState } from 'preact/hooks';

import type { PublicProfile } from '../../api/types';
import { useFormatter } from '../../app/context';
import { navigate, slugRoute } from '../../app/router';
import { useBooking } from '../../app/booking/store';
import { priceText } from '../../app/booking/priceText';
import { selectedAddOns, servicePrice, totals } from '../../app/booking/summary';
import { FLOW_STEPS } from '../../app/booking/machine';
import { Button } from '../../components/Button';
import { Chip, Option } from '../../components/Choices';
import { Screen, TopBar, Title, useDocumentTitle } from '../../components/Layout';
import { Notice } from '../../components/Feedback';
import { useI18n } from '../../i18n';

export function ServiceStep({ profile }: { profile: PublicProfile }): JSX.Element {
  const { t } = useI18n();
  const format = useFormatter();
  const [state, dispatch] = useBooking(profile.slug, profile.regionCode);
  const [missing, setMissing] = useState(false);
  useDocumentTitle(t('bk2.title'));

  const { draft } = state;
  const service = profile.services.find((candidate) => candidate.id === draft.serviceId);
  const chosenAddOns = selectedAddOns(profile.addOns, draft.addOnIds);
  const summary = service === undefined ? null : totals(service, chosenAddOns, draft.guests);
  const maxGuests = profile.booking.maxGuests;

  const bar = (
    <>
      <div class="bar-note" aria-live="polite" data-testid="summary">
        {service === undefined ? (
          <span>{t('bk2.pick')}</span>
        ) : (
          <>
            <b class="strong">
              <bdi>{service.name}</bdi>
              {chosenAddOns.length > 0 ? <> + <bdi>{format.list(chosenAddOns.map((addOn) => addOn.name))}</bdi></> : null}
            </b>
            <br />
            {[format.minutes(summary?.totalMinutes ?? 0), priceText(summary?.price ?? null, format, t)].filter(Boolean).join(' · ')}
          </>
        )}
      </div>
      <Button
        disabled={service === undefined}
        testId="continue"
        onClick={() => {
          if (service === undefined) {
            setMissing(true);
            return;
          }
          dispatch({ type: 'chooseService', serviceId: service.id, addOnIds: draft.addOnIds });
          navigate(slugRoute(profile.slug, 'time'));
        }}
      >
        {t('common.continue')}
      </Button>
    </>
  );

  return (
    <Screen top={<TopBar back={slugRoute(profile.slug)} step={{ current: 1, total: FLOW_STEPS }} />} bar={bar}>
      <div>
        <Title>{t('bk2.title')}</Title>
        <p class="lead">{t('bk2.with', { name: profile.displayName })}</p>
      </div>

      {missing && service === undefined ? (
        <Notice kind="warning" icon="alert" live="assertive" testId="service-missing">
          {t('bk2.pickError')}
        </Notice>
      ) : null}

      <fieldset>
        <legend class="sr-only">{t('bk2.title')}</legend>
        {profile.services.map((candidate) => (
          <Option
            key={candidate.id}
            type="radio"
            name="service"
            value={candidate.id}
            checked={candidate.id === draft.serviceId}
            title={candidate.name}
            detail={format.minutes(candidate.durationMinutes)}
            price={priceText(servicePrice(candidate), format, t)}
            testId={`option-${candidate.id}`}
            onChange={() => {
              dispatch({ type: 'preselect', serviceId: candidate.id });
              setMissing(false);
            }}
          />
        ))}
      </fieldset>

      {profile.addOns.length === 0 ? null : (
        <fieldset>
          <legend class="section">{t('bk2.addOns')}</legend>
          <p class="lead mt-sm">{t('bk2.addOnsHint')}</p>
          <div class="mt-md">
            {profile.addOns.map((addOn) => (
              <Option
                key={addOn.id}
                type="checkbox"
                name="addon"
                value={addOn.id}
                checked={draft.addOnIds.includes(addOn.id)}
                title={addOn.name}
                detail={`+${format.minutes(addOn.minutes)}`}
                price={addOn.priceAmount === undefined ? undefined : format.money(addOn.priceAmount)}
                testId={`addon-${addOn.id}`}
                onChange={(on) => {
                  const next = on ? [...draft.addOnIds, addOn.id] : draft.addOnIds.filter((id) => id !== addOn.id);
                  dispatch({ type: 'setAddOns', addOnIds: next });
                }}
              />
            ))}
          </div>
        </fieldset>
      )}

      {maxGuests === 0 ? null : (
        <fieldset>
          <legend class="section">{t('bk2.guests.title')}</legend>
          <p class="lead mt-sm">{t('bk2.guests.hint', { name: profile.firstName })}</p>
          <div class="chips mt-md" role="group" aria-label={t('bk2.guests.title')}>
            {[0, 1, 2].filter((count) => count <= maxGuests).map((count) => (
              <Chip
                key={count}
                pressed={draft.guests === count}
                testId={`guests-${count}`}
                onToggle={() => {
                  dispatch({ type: 'setGuests', guests: count, guestNames: draft.guestNames });
                }}
              >
                {count === 0 ? t('bk2.guests.none') : t('bk2.guests.plus', { count })}
              </Chip>
            ))}
          </div>
        </fieldset>
      )}
    </Screen>
  );
}
