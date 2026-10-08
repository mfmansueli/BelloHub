import type { App } from 'firebase-admin/app';
import { getStorage } from 'firebase-admin/storage';

/** Large sealed envelopes live in Cloud Storage as opaque bytes (docs/11 section 2). Only functions touch it. */
export interface BlobStore {
  put(path: string, data: Buffer, contentType: string): Promise<void>;
  get(path: string): Promise<Buffer | null>;
  /** Idempotent: a missing object is not an error. */
  delete(path: string): Promise<void>;
  /** One page of object paths under `prefix`. */
  list(prefix: string, pageToken?: string): Promise<{ paths: string[]; next?: string | undefined }>;
}

/** Cloud Storage through the Admin SDK (bypasses the deny-all Storage rules). */
export class GcsBlobStore implements BlobStore {
  /** `app` and `bucketName` default to the default app and its default bucket; tests name both. */
  constructor(
    private readonly bucketName?: string,
    private readonly app?: App
  ) {}

  private bucket() {
    const storage = getStorage(this.app);
    return this.bucketName ? storage.bucket(this.bucketName) : storage.bucket();
  }

  async put(path: string, data: Buffer, contentType: string): Promise<void> {
    await this.bucket().file(path).save(data, { contentType, resumable: false });
  }

  async get(path: string): Promise<Buffer | null> {
    const file = this.bucket().file(path);
    const [exists] = await file.exists();
    if (!exists) return null;
    const [contents] = await file.download();
    return contents;
  }

  async delete(path: string): Promise<void> {
    await this.bucket().file(path).delete({ ignoreNotFound: true });
  }

  async list(prefix: string, pageToken?: string): Promise<{ paths: string[]; next?: string | undefined }> {
    const [files, nextQuery] = await this.bucket().getFiles({
      prefix,
      maxResults: 200,
      autoPaginate: false,
      ...(pageToken ? { pageToken } : {})
    });
    const next = (nextQuery as { pageToken?: string } | null | undefined)?.pageToken;
    return { paths: files.map((file) => file.name), next };
  }
}
