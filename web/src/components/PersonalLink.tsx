// The personal link is the key to her booking (docs/06 section 5), so the page makes it easy to keep: shown in full,
// one tap to copy, and selectable for the browsers that refuse the clipboard.

import type { JSX } from 'preact';
import { useRef, useState } from 'preact/hooks';

import { useT } from '../i18n';
import { Button } from './Button';
import { Icon } from './Icon';

export function PersonalLink({ url }: { url: string }): JSX.Element {
  const t = useT();
  const [status, setStatus] = useState<'idle' | 'copied' | 'manual'>('idle');
  const code = useRef<HTMLElement>(null);

  const copy = async (): Promise<void> => {
    try {
      await navigator.clipboard.writeText(url);
      setStatus('copied');
    } catch {
      // The clipboard can be blocked (in-app browsers, insecure origins): select the text so she can copy it by hand.
      const element = code.current;
      if (element !== null) {
        const range = document.createRange();
        range.selectNodeContents(element);
        const selection = window.getSelection();
        selection?.removeAllRanges();
        selection?.addRange(range);
      }
      setStatus('manual');
    }
  };

  return (
    <div class="stack-sm">
      <p class="strong">
        {t('bk8.link.label')}
      </p>
      <code class="well ltr link-url" ref={code} data-testid="personal-link">
        {url}
      </code>
      <Button variant="secondary" inline onClick={() => { void copy(); }} testId="copy-link">
        <Icon name="copy" />
        {t('bk8.link.copy')}
      </Button>
      <p class="meta" role="status" data-testid="copy-status">
        {status === 'copied' ? t('bk8.link.copied') : status === 'manual' ? t('bk8.link.manual') : ''}
      </p>
    </div>
  );
}
