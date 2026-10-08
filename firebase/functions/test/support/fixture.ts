import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import type { AvailabilitySettings } from '../../src/lib/freeSlots.js';
import type { CancellationPolicy } from '../../src/lib/rules.js';

/** One case of the shared rules fixture, produced by running the iOS Swift rule types (scripts/rules-fixtures). */
export interface FreeSlotsCase {
  name: string;
  input: {
    now: string;
    day: string;
    durationMinutes: number;
    stepMinutes: number;
    settings: AvailabilitySettings;
    appointments: [string, string][];
    blocks: [string, string][];
  };
  expected: string[];
}

export interface CancellationCase {
  name: string;
  policy: CancellationPolicy;
  startsAt: string;
  now: string;
  rescheduleCount: number;
  expected: {
    cancel: string;
    reschedule: string;
    isInsideFreeWindow: boolean;
    cancellationWouldBeLate: boolean;
    hoursUntilStart: number;
  };
}

export interface LateCancellationCase {
  name: string;
  policy: CancellationPolicy;
  startsAt: string;
  cancelledAt: string;
  expected: boolean;
}

export interface RegistrationQuotaCase {
  ledgerCount: number;
  serverCount?: number;
  hasActivePlan: boolean;
  forNewClients: number;
  expected: { decision: 'allowed' | 'needsSubscription' | 'allowedPartially'; count?: number; used: number; remainingFree: number };
}

export interface RulesFixture {
  slotStepMinutes: number;
  freeSlots: FreeSlotsCase[];
  cancellation: CancellationCase[];
  lateCancellation: LateCancellationCase[];
  registrationQuota: RegistrationQuotaCase[];
}

export function loadRulesFixture(): RulesFixture {
  const path = fileURLToPath(new URL('../fixtures/rules.fixture.json', import.meta.url));
  return JSON.parse(readFileSync(path, 'utf8')) as RulesFixture;
}
