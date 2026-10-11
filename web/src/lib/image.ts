// A photo for the skin check-in (docs/10 section 5): re-encoded in a canvas to a JPEG of at most 1.5 MB, which also
// strips EXIF (location, device) because a canvas never copies metadata. The result is a data URL (the page's CSP
// allows `data:` images, not `blob:`), and it only ever lives in memory.

/** Base64 of the JPEG must stay within 1.5 MB (docs/06 section 3.4); the raw bytes are a third smaller. */
export const MAX_PHOTO_BASE64 = 1_500_000;
const LONGEST_SIDE = 1600;

export function scaledSize(width: number, height: number, longest: number): { width: number; height: number } {
  const scale = Math.min(1, longest / Math.max(width, height));
  return { width: Math.max(1, Math.round(width * scale)), height: Math.max(1, Math.round(height * scale)) };
}

async function decode(file: File): Promise<{ source: CanvasImageSource; width: number; height: number; close: () => void }> {
  if (typeof createImageBitmap === 'function') {
    // `from-image` applies the EXIF orientation before the metadata is dropped, so the photo is not rotated.
    const bitmap = await createImageBitmap(file, { imageOrientation: 'from-image' });
    return { source: bitmap, width: bitmap.width, height: bitmap.height, close: () => { bitmap.close(); } };
  }
  const url = URL.createObjectURL(file);
  try {
    const image = new Image();
    image.decoding = 'async';
    image.src = url;
    await image.decode();
    return { source: image, width: image.naturalWidth, height: image.naturalHeight, close: () => undefined };
  } finally {
    URL.revokeObjectURL(url);
  }
}

export interface EncodedPhoto {
  /** `data:image/jpeg;base64,...` for the preview. */
  readonly dataUrl: string;
  /** The base64 alone, for the sealed payload. */
  readonly base64: string;
}

/** Throws when the file is not an image the browser can decode or cannot be made small enough. */
export async function reencodePhoto(file: File): Promise<EncodedPhoto> {
  const decoded = await decode(file);
  try {
    let side = LONGEST_SIDE;
    for (let attempt = 0; attempt < 6; attempt += 1) {
      const size = scaledSize(decoded.width, decoded.height, side);
      const canvas = document.createElement('canvas');
      canvas.width = size.width;
      canvas.height = size.height;
      const context = canvas.getContext('2d');
      if (context === null) throw new Error('no canvas');
      context.fillStyle = '#ffffff';
      context.fillRect(0, 0, size.width, size.height);
      context.drawImage(decoded.source, 0, 0, size.width, size.height);
      for (const quality of [0.82, 0.7, 0.55]) {
        const dataUrl = canvas.toDataURL('image/jpeg', quality);
        const base64 = dataUrl.slice(dataUrl.indexOf(',') + 1);
        if (base64.length <= MAX_PHOTO_BASE64) return { dataUrl, base64 };
      }
      side = Math.round(side * 0.75);
    }
    throw new Error('too large');
  } finally {
    decoded.close();
  }
}
