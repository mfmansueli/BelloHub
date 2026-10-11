// Where she works, as a booking e-mail shows it (owner, 2026-10-11: "the confirmation does not say where the place
// is"). The app wrote the lines and built the two map links from the address; this only lays them out, in the text
// part as plain lines (each link alone on its line, so every mail app makes it a link) and in the HTML part as a box.

export interface EmailPlace {
  /** "Where", in the reader's language. */
  title: string;
  lines: readonly string[];
  directions?: string | undefined;
  /** The two map links with their app names: Apple's, then Google's. */
  links: readonly { label: string; url: string }[];
}

/** The text block: the heading, the lines, the note, then each map app's name and its link on the next line. */
export function placeText(place: EmailPlace): string {
  const parts = [place.title, ...place.lines, ...(place.directions ? [place.directions] : [])];
  for (const link of place.links) parts.push(`${link.label}:`, link.url);
  return parts.join('\n');
}

/** `body` with the place right after its first paragraph (the service and the time), where a reader looks for it. */
export function withPlace(body: string, place: EmailPlace | undefined): string {
  if (!place) return body;
  const paragraphs = body.split('\n\n');
  return [paragraphs[0] ?? '', placeText(place), ...paragraphs.slice(1)].filter((part) => part.length > 0).join('\n\n');
}
