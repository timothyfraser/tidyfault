# tidyfault website

Vite + React home page for tidyfault. Plain JS/JSX, no CSS framework.

```bash
npm ci
npm run build    # writes src/design/tokens.css from src/design/tokens.json, then vite build
npm run dev      # local dev server
npm run verify   # Playwright check of the built site (needs chromium under /opt/pw-browsers)
```

- `src/design/tokens.json` is the design tokens; `scripts/tokens-to-css.mjs` turns it into
  `src/design/tokens.css` (custom properties, light on `:root`, dark under `[data-theme="dark"]`
  and `prefers-color-scheme: dark`). Components use the variables, never hard-coded hex values.
- `scripts/verify-site.mjs` loads the page at 1280 and 390 px, fails on console errors, checks
  that every in-page link resolves, checks for horizontal overflow, and saves screenshots to
  `/tmp/web01-shots/`. Pass `--url` to test a running server.
- The Run button is disabled for now; live runtimes arrive later.
