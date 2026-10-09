// Talks to the deployed entry points the way the web app and the iPhone do: the callable protocol over HTTPS, against
// the Functions emulator (docs/11 section 10). Nothing here imports server code, so these tests catch wiring errors that
// the in-process suites cannot: a function missing from index.ts, a wrong region, a rule that rejects the Admin SDK.

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { PROJECT_ID } from './emulator.js';

interface EmulatorConfig {
  emulators: { functions: { port: number }; auth: { port: number } };
}

const config = JSON.parse(readFileSync(fileURLToPath(new URL('../../../firebase.test.json', import.meta.url)), 'utf8')) as EmulatorConfig;
export const FUNCTIONS_BASE = `http://127.0.0.1:${config.emulators.functions.port}/${PROJECT_ID}/europe-west1`;
const AUTH_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST ?? `127.0.0.1:${config.emulators.auth.port}`;

export interface CallResult {
  status: number;
  /** `result` of a success. */
  result?: unknown;
  /** `error.message`: the stable code. */
  code?: string;
  details?: unknown;
  errorStatus?: string;
  headers: Headers;
}

export interface CallOptions {
  idToken?: string;
  appCheck?: string;
  origin?: string;
  forwardedFor?: string;
}

/** `POST <base>/<name>` with `{ "data": ... }`, exactly as API.md section 1 describes. */
export async function callFunction(name: string, data: unknown, options: CallOptions = {}): Promise<CallResult> {
  const response = await fetch(`${FUNCTIONS_BASE}/${name}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(options.idToken ? { Authorization: `Bearer ${options.idToken}` } : {}),
      ...(options.appCheck ? { 'X-Firebase-AppCheck': options.appCheck } : {}),
      ...(options.origin ? { Origin: options.origin } : {}),
      ...(options.forwardedFor ? { 'X-Forwarded-For': options.forwardedFor } : {})
    },
    body: JSON.stringify({ data })
  });
  const body = (await response.json().catch(() => ({}))) as {
    result?: unknown;
    error?: { message?: string; status?: string; details?: unknown };
  };
  return {
    status: response.status,
    ...(body.result !== undefined ? { result: body.result } : {}),
    ...(body.error?.message ? { code: body.error.message } : {}),
    ...(body.error?.details !== undefined ? { details: body.error.details } : {}),
    ...(body.error?.status ? { errorStatus: body.error.status } : {}),
    headers: response.headers
  };
}

export async function callOk<T>(name: string, data: unknown, options: CallOptions = {}): Promise<T> {
  const result = await callFunction(name, data, options);
  if (result.status !== 200) throw new Error(`${name} failed: ${result.status} ${result.code ?? ''}`);
  return result.result as T;
}

async function identity<T>(path: string, body: unknown): Promise<T> {
  const response = await fetch(`http://${AUTH_HOST}/identitytoolkit.googleapis.com/v1/${path}?key=fake-api-key`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  });
  if (!response.ok) throw new Error(`auth emulator ${path}: ${response.status}`);
  return (await response.json()) as T;
}

/** A professional's ID token: a custom-token sign-in for a uid (what the phone sign-in yields, minus the SMS step). */
export async function signInProfessional(customToken: string): Promise<string> {
  const { idToken } = await identity<{ idToken: string }>('accounts:signInWithCustomToken', { token: customToken, returnSecureToken: true });
  return idToken;
}

/** A client's phone sign-in through the Auth emulator: send the SMS, read the fixed code it offers, confirm it. */
export async function signInWithPhone(phoneNumber: string): Promise<string> {
  const { sessionInfo } = await identity<{ sessionInfo: string }>('accounts:sendVerificationCode', { phoneNumber, recaptchaToken: 'emulator' });
  const codes = (await (await fetch(`http://${AUTH_HOST}/emulator/v1/projects/${PROJECT_ID}/verificationCodes`)).json()) as {
    verificationCodes: { phoneNumber: string; code: string; sessionInfo: string }[];
  };
  const code = codes.verificationCodes.filter((entry) => entry.sessionInfo === sessionInfo).at(-1)?.code;
  if (!code) throw new Error('the Auth emulator offered no code');
  const { idToken } = await identity<{ idToken: string }>('accounts:signInWithPhoneNumber', { sessionInfo, code });
  return idToken;
}

/** Waits for a condition (never a fixed sleep): triggers in the emulator run a moment after the write that causes them. */
export async function waitUntil<T>(read: () => Promise<T | undefined | false>, timeoutMs = 20_000): Promise<T> {
  const started = Date.now();
  for (;;) {
    const value = await read();
    if (value !== undefined && value !== false) return value;
    if (Date.now() - started > timeoutMs) throw new Error('timed out waiting for the condition');
    await new Promise((resolve) => setTimeout(resolve, 200));
  }
}
