// An optional drawn signature (docs/10 section 5): a canvas, a PNG of at most 64 KB. The typed name is the
// signature that counts; this only adds to it, so it is skippable and never required.

import type { JSX } from 'preact';
import { useEffect, useRef } from 'preact/hooks';

import { useT } from '../i18n';
import { Button } from './Button';

/** Base64 of the PNG must stay within 64 KB (docs/06 section 3.4). */
export const MAX_SIGNATURE_BASE64 = 64 * 1024;

interface Props {
  /** Called with the PNG as base64 after each stroke, and with null when cleared or too large. */
  readonly onChange: (png: string | null) => void;
  readonly label: string;
}

export function SignaturePad({ onChange, label }: Props): JSX.Element {
  const t = useT();
  const canvas = useRef<HTMLCanvasElement>(null);
  const drawing = useRef(false);
  const dirty = useRef(false);

  useEffect(() => {
    const element = canvas.current;
    if (element === null) return;
    // A fixed bitmap size keeps the PNG small whatever the screen: 560 by 140 is plenty for a signature.
    element.width = 560;
    element.height = 140;
    const context = element.getContext('2d');
    if (context !== null) {
      context.lineWidth = 3;
      context.lineCap = 'round';
      context.lineJoin = 'round';
      // Dark ink on the paper-colored canvas in both appearances (the PNG is read on the professional's side).
      context.strokeStyle = getComputedStyle(element).getPropertyValue('--hero-gradient-end').trim() || 'black';
    }
  }, []);

  const point = (event: PointerEvent): { x: number; y: number } => {
    const element = canvas.current;
    if (element === null) return { x: 0, y: 0 };
    const box = element.getBoundingClientRect();
    return { x: ((event.clientX - box.left) / box.width) * element.width, y: ((event.clientY - box.top) / box.height) * element.height };
  };

  const finish = (): void => {
    if (!drawing.current) return;
    drawing.current = false;
    const element = canvas.current;
    if (element === null || !dirty.current) return;
    const dataUrl = element.toDataURL('image/png');
    const base64 = dataUrl.slice(dataUrl.indexOf(',') + 1);
    onChange(base64.length <= MAX_SIGNATURE_BASE64 ? base64 : null);
  };

  return (
    <div class="stack-sm">
      <p class="strong" id="sign-label">{label}</p>
      <canvas
        ref={canvas}
        class="sign"
        role="img"
        aria-labelledby="sign-label"
        data-testid="signature-canvas"
        onPointerDown={(event) => {
          event.preventDefault();
          event.currentTarget.setPointerCapture(event.pointerId);
          drawing.current = true;
          dirty.current = true;
          const context = event.currentTarget.getContext('2d');
          const { x, y } = point(event);
          context?.beginPath();
          context?.moveTo(x, y);
          context?.lineTo(x + 0.01, y);
          context?.stroke();
        }}
        onPointerMove={(event) => {
          if (!drawing.current) return;
          const context = event.currentTarget.getContext('2d');
          const { x, y } = point(event);
          context?.lineTo(x, y);
          context?.stroke();
        }}
        onPointerUp={finish}
        onPointerCancel={finish}
      />
      <Button
        variant="tertiary"
        inline
        onClick={() => {
          const element = canvas.current;
          element?.getContext('2d')?.clearRect(0, 0, element.width, element.height);
          dirty.current = false;
          onChange(null);
        }}
        testId="signature-clear"
      >
        {t('cl4.drawClear')}
      </Button>
    </div>
  );
}
