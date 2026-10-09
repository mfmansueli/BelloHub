/**
 * The caller's IP from X-Forwarded-For. Google's front end appends the address it saw to whatever the client sent, so
 * the trustworthy entry is counted from the END: with one proxy (`hops` = 1) it is the last one. Anything the client
 * put before it is ignored, so a forged header cannot dodge a rate limit.
 */
export function clientIpFrom(forwardedFor: string | undefined, socketAddress: string | undefined, hops: number): string {
  const entries = (forwardedFor ?? '')
    .split(',')
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0);
  const index = entries.length - Math.max(hops, 1);
  return entries[index] ?? entries[0] ?? socketAddress ?? 'unknown';
}
