import type { Firestore } from 'firebase-admin/firestore';
import { Timestamp } from 'firebase-admin/firestore';

import { C } from '../lib/docs.js';
import type { EmailMessage, EmailProvider } from './EmailProvider.js';

/**
 * Emulator only: it "sends" by counting. It records neither the address nor the text, so even the emulator's data never
 * holds a code or a link. The codes of the emulator are fixed (`FIXED_EMAIL_CODE`), so nothing needs to read them.
 */
export class EmulatorEmailProvider implements EmailProvider {
  constructor(private readonly db: Firestore) {}

  async send(_message: EmailMessage): Promise<void> {
    await this.db.collection(C.emulatorOutbox).add({ type: 'email', at: Timestamp.now() });
  }
}
