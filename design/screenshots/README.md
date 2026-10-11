# Screenshots

One image per approved screen, named `<group>-<number>_<Screen>.png` (for example `02-01_Home.png` is screen `2.1`). 390×844 pt at 2×, default state of each board, rendered from the prototype with the real runtime.

Caveats:
- Fraunces and DM Sans could not be loaded in the rendering environment; headings fall back to a serif and text to a similar sans. **Use the real fonts from `docs/08-DESIGN-SYSTEM.md`.**
- Where a screen has several states (sheets, steps, variants) only the default state is captured; read the board's HTML and `docs/screens/HANDOFF.md` ("Estados") for the rest.
- The tab bar is composited onto the five tab roots; in the app use the system `TabView`.
- Motion is not visible in stills; see `docs/09-MOTION.md`.
