// D47: the rules that apply to one booking, from the time it was made. They are worded from the policy SNAPSHOT the
// server keeps on the booking (`getBooking.policy`, API.md 5.11), never from the professional's current page, and
// only from fields the API actually publishes: a consequence the policy does not state (for example that a late
// cancellation counts as a missed appointment) is never claimed. Pure, so the wording rules have one owner and a test.

import type { PolicyValues } from './policy';

export interface RuleDescriptor {
  /** The i18n key of the sentence. */
  readonly key: string;
  /** Which values the sentence needs; the component formats them for the language. */
  readonly uses: readonly ('window' | 'minutes' | 'count')[];
  readonly count?: number;
}

export function bookingRules(policy: PolicyValues): RuleDescriptor[] {
  const rules: RuleDescriptor[] = [{ key: 'br.free', uses: ['window'] }];
  if (!policy.clientCanReschedule) {
    rules.push({ key: 'br.noReschedule', uses: [] });
  } else {
    if (typeof policy.maxReschedules === 'number') rules.push({ key: 'br.rescheduleLimit', uses: ['count'], count: policy.maxReschedules });
    rules.push({ key: policy.afterWindowReschedule === 'request' ? 'br.afterRescheduleRequest' : 'br.afterRescheduleMessage', uses: [] });
  }
  rules.push({ key: policy.afterWindowCancel === 'allow' ? 'br.afterCancelAllow' : 'br.afterCancelMessage', uses: [] });
  if (policy.askConfirmation) rules.push({ key: 'br.confirm', uses: [] });
  rules.push({ key: 'br.late', uses: ['minutes'] });
  // Only when the policy itself says so. The published policy of API.md 5.11 has no such field today, so this line
  // does not appear until the server publishes it.
  if (policy.lateCancelCounts === true) rules.push({ key: 'br.lateCounts', uses: [] });
  return rules;
}
