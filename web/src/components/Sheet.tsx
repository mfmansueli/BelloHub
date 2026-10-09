// A bottom sheet on the native <dialog>: the browser traps focus, closes on Escape, makes the page behind inert and
// gives focus back on close. Custom only for the look (handle, radius, blur), not for any behavior.

import type { ComponentChildren, JSX } from 'preact';
import { useEffect, useId, useRef } from 'preact/hooks';

import { useT } from '../i18n';
import { Button } from './Button';

interface SheetProps {
  readonly open: boolean;
  readonly onClose: () => void;
  readonly title: string;
  readonly children: ComponentChildren;
  readonly testId?: string;
  /** Show the Done button at the bottom (default). Sheets with their own actions turn it off. */
  readonly closeButton?: boolean;
}

export function Sheet({ open, onClose, title, children, testId, closeButton = true }: SheetProps): JSX.Element {
  const t = useT();
  const ref = useRef<HTMLDialogElement>(null);
  const titleId = useId();

  useEffect(() => {
    const dialog = ref.current;
    if (dialog === null) return;
    if (open && !dialog.open) dialog.showModal();
    if (!open && dialog.open) dialog.close();
  }, [open]);

  return (
    <dialog
      ref={ref}
      class="sheet"
      aria-labelledby={titleId}
      data-testid={testId}
      onClose={onClose}
      onClick={(event) => {
        // A click on the dialog box itself (not on its content) is a click on the backdrop.
        if (event.target === ref.current) onClose();
      }}
    >
      {open ? (
        <>
          <div class="sheet-handle" aria-hidden="true" />
          <h2 id={titleId}>{title}</h2>
          {children}
          {closeButton ? (
            <div class="mt-sm">
              <Button variant="tertiary" onClick={onClose} testId={testId === undefined ? undefined : `${testId}-close`}>
                {t('common.done')}
              </Button>
            </div>
          ) : null}
        </>
      ) : null}
    </dialog>
  );
}
