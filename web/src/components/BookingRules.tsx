// "These are the rules that apply to this booking, from the time you booked" (D47). Worded from the booking's own
// policy snapshot (lib/bookingRules.ts), shown on the confirmation and on the management page.

import type { JSX } from 'preact';

import { useFormatter } from '../app/context';
import { useI18n } from '../i18n';
import { bookingRules } from '../lib/bookingRules';
import type { PolicyValues } from '../lib/policy';
import { Icon } from './Icon';

export function BookingRules({ policy, professionalFirstName }: { policy: PolicyValues; professionalFirstName: string }): JSX.Element {
  const { t } = useI18n();
  const format = useFormatter();
  return (
    <section class="card" aria-labelledby="rules-title" data-testid="booking-rules">
      <h2 id="rules-title" class="strong">
        {t('br.title')}
      </h2>
      <ul class="check-list mt-sm">
        {bookingRules(policy).map((rule) => (
          <li key={rule.key}>
            <Icon name="check" />
            <span>
              {t(rule.key, {
                name: professionalFirstName,
                window: format.hours(policy.freeWindowHours),
                minutes: format.minutes(policy.graceMinutes),
                count: rule.count ?? 0,
              })}
            </span>
          </li>
        ))}
      </ul>
    </section>
  );
}
