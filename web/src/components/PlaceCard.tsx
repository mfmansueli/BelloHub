// Where she works (owner, 2026-10-11): the lines her app wrote, the "how to find us" note and the two map links, built
// from the address alone. Shown on the booking page only when she made it public, and on the confirmation and the
// management page when the server sends it (a confirmed booking, lib/location on the server).

import type { JSX } from 'preact';

import type { PublicLocation } from '../api/types';
import { useI18n } from '../i18n';
import { ExternalLink } from './Button';
import { Icon } from './Icon';

export function PlaceCard({ location }: { readonly location: PublicLocation }): JSX.Element {
  const { t } = useI18n();
  return (
    <section class="card stack-sm" aria-labelledby="place-title" data-testid="place">
      <h2 id="place-title" class="strong row-flex">
        <Icon name="pin" />
        {t('loc.title')}
      </h2>
      <p data-testid="place-lines">
        {location.lines.map((line, index) => (
          <span key={index}>
            {index > 0 ? <br /> : null}
            <bdi>{line}</bdi>
          </span>
        ))}
      </p>
      {location.directions === undefined ? null : (
        <p class="meta" data-testid="place-directions">
          <bdi>{location.directions}</bdi>
        </p>
      )}
      <p class="place-links">
        <ExternalLink href={location.maps.apple} class="link-button" testId="map-apple">
          {t('loc.appleMaps')}
        </ExternalLink>
        <ExternalLink href={location.maps.google} class="link-button" testId="map-google">
          {t('loc.googleMaps')}
        </ExternalLink>
      </p>
    </section>
  );
}
