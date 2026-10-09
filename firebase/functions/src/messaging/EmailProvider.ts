export interface EmailMessage {
  to: string;
  subject: string;
  /** Plain text only: booking facts and a link, never clinical content (docs/06 section 8). */
  text: string;
}

/**
 * A transactional email service reached over HTTPS. The code depends only on this interface; the vendor is chosen by
 * a human (H7) and gets its adapter in this folder. The vendor must have signed a data processing agreement.
 */
export interface EmailProvider {
  send(message: EmailMessage): Promise<void>;
}
