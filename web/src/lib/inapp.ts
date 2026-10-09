// In-app browsers (WhatsApp, Instagram, Facebook, Messenger, Line, Snapchat) often block file downloads, `tel:`
// links and storage (docs/10 section 8). The page cannot detect a blocked download, so it recognises the browser and
// says where to open the page instead, offering the Google Calendar link that works everywhere.

const PATTERN = /(FBAN|FBAV|FB_IAB|Instagram|WhatsApp|Line\/|Snapchat|MicroMessenger|Messenger)/i;

export function inAppBrowser(userAgent: string = typeof navigator === 'undefined' ? '' : navigator.userAgent): boolean {
  return PATTERN.test(userAgent);
}
