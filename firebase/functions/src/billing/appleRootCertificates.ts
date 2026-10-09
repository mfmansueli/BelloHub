import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';

/**
 * Apple's root certificates (public, DER encoded, from https://www.apple.com/certificateauthority/) as the files a human
 * put in `APPLE_ROOT_CERTS_DIR` (H14): every `.cer` / `.der` there, deployed with the functions. An absent or empty
 * directory means "not configured": the verifier then stays `UnconfiguredAppStoreVerifier` and no plan ever unlocks.
 */
export function loadAppleRootCertificates(directory: string): Buffer[] {
  if (!directory || !existsSync(directory) || !statSync(directory).isDirectory()) return [];
  return readdirSync(directory)
    .filter((name) => /\.(cer|der)$/i.test(name))
    .sort()
    .map((name) => readFileSync(join(directory, name)));
}
