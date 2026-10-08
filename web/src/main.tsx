import './styles/tokens.generated.css';
import './styles/base.css';
import './styles/components.css';

import { render } from 'preact';

import { App } from './app/App';
import { loadPublicPage } from './app/pageData';
import { routeStore, startRouter } from './app/router';
import { initialLanguage, setLanguage } from './i18n';

async function start(): Promise<void> {
  // Ask for the professional's page and the first language at the same time: they do not depend on each other.
  const route = routeStore.get();
  if (route.kind === 'slug') loadPublicPage(route.slug).catch(() => undefined);
  await setLanguage(initialLanguage());
  const root = document.getElementById('app');
  if (root !== null) render(<App />, root);
  startRouter();
}

void start();
