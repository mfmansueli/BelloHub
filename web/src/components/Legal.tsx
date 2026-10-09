// Renders a legal text from its block tree. Everything is a text node: there is no HTML in the texts and no
// innerHTML in the page. The professional's name is isolated like every other name.

import type { JSX } from 'preact';

import { useT } from '../i18n';
import { useLegal, type Block, type Inline, type LegalDocument } from '../legal';

export function InlineText({ nodes, professionalName }: { nodes: readonly Inline[]; professionalName: string }): JSX.Element {
  return (
    <>
      {nodes.map((node, index) => {
        switch (node.k) {
          case 't':
            return node.v;
          case 'b':
            return (
              <b key={index} class="strong">
                {node.v}
              </b>
            );
          case 'pro':
            return <bdi key={index}>{professionalName}</bdi>;
          case 'a':
            // Our own pages are shown as plain text, so nothing in a legal text can send a client elsewhere.
            return (
              <span key={index} class="ltr">
                {node.v}
              </span>
            );
        }
      })}
    </>
  );
}

/** Inline nodes as plain text, for a label or an attribute (the professional's name filled in). */
export function inlineString(nodes: readonly Inline[], professionalName: string): string {
  return nodes
    .map((node) => {
      switch (node.k) {
        case 't':
        case 'b':
        case 'a':
          return node.v;
        case 'pro':
          return professionalName;
      }
    })
    .join('');
}

/** The blocks of a text, except the ones the surrounding page already shows (`skip`, for example the title). */
export function LegalBlocks({ blocks, professionalName, skip = [] }: { blocks: readonly Block[]; professionalName: string; skip?: readonly Block['type'][] }): JSX.Element {
  return (
    <div class="legal">
      {blocks.map((block, index) => {
        if (skip.includes(block.type)) return null;
        switch (block.type) {
          case 'h1':
            return <h1 key={index}>{<InlineText nodes={block.text} professionalName={professionalName} />}</h1>;
          case 'p':
            return (
              <p key={index}>
                <InlineText nodes={block.text} professionalName={professionalName} />
              </p>
            );
          case 'ul':
            return (
              <ul key={index}>
                {block.items.map((item, i) => (
                  <li key={i}>
                    <InlineText nodes={item} professionalName={professionalName} />
                  </li>
                ))}
              </ul>
            );
        }
      })}
    </div>
  );
}

/** A whole document, with its own loading and error line. Inside a sheet the sheet already carries the title. */
export function LegalDocumentView({ document, professionalName, withTitle = false }: { document: LegalDocument; professionalName: string; withTitle?: boolean }): JSX.Element {
  const t = useT();
  const state = useLegal(document);
  if (state.status === 'loading') return <p class="meta" aria-busy="true">{t('common.loading')}</p>;
  if (state.status === 'error') return <p class="meta">{t('err.generic')}</p>;
  return <LegalBlocks blocks={state.file.blocks} professionalName={professionalName} skip={withTitle ? [] : ['h1']} />;
}
