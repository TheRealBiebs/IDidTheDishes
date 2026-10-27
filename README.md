# Hello, world — React + Supabase + GitHub Pages

A tiny mobile-friendly React app. It reads one greeting from Supabase; visitors cannot write to the database. No server hosting or paid Supabase features are needed.

## Local development in Visual Studio Code

Install Node.js 22.12 or newer and pnpm 11.25.0 if they are not already on your PATH.

```sh
pnpm install
cp .env.example .env.local
pnpm dev
```

On Windows PowerShell, use `Copy-Item .env.example .env.local` for the copy command. Edit `.env.local` with your project's URL and **publishable** key from the Supabase Connect panel, then restart the dev server. The site works before configuration and shows a setup message.

## Supabase

1. Use an existing project on the Free plan, or create a Free project at https://supabase.com/dashboard.
2. Open SQL Editor and run `supabase/schema.sql`.
3. Fill `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` in `.env.local`.
4. Reload the site. The status should say **Connected to Supabase**.

To prove the backend is connected, edit row 1 in the `greetings` table, then click **Refresh greeting**. You can change it back to `Hello, world.` afterward.

Only a publishable key belongs in this frontend. Vite embeds `VITE_*` values into public JavaScript. Never use a secret or service-role key. The included schema enables row-level security and grants visitors SELECT only. Run it against the intended project; it creates or configures the demo `public.greetings` table. Free project quotas and inactivity behavior remain subject to Supabase's current plan.

## GitHub Pages

Target repository: https://github.com/TheRealBiebs/IDidTheDishes

1. Push this project to the repository's `main` branch.
2. Under **Settings → Secrets and variables → Actions → Variables**, create these repository variables:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_PUBLISHABLE_KEY`
3. Under **Settings → Pages → Build and deployment**, select **GitHub Actions**.
4. Run **Deploy to GitHub Pages** from the Actions tab, or push a change to `main`.

Expected URL after a successful deployment: https://therealbiebs.github.io/IDidTheDishes/

The workflow intentionally fails with a clear message if either Supabase variable is missing. Values are baked in at build time: after changing them, rerun the workflow. `base: './'` supports GitHub Pages repository subpaths. This starter has one page and no client-side routes.

## Build

```sh
pnpm build
pnpm preview
```

The deployable static output is `dist/`. The lockfile pins the installed dependencies.

References: [Supabase React guide](https://supabase.com/docs/guides/getting-started/quickstarts/reactjs), [Supabase row-level security](https://supabase.com/docs/guides/database/postgres/row-level-security), [Vite GitHub Pages deployment](https://vite.dev/guide/static-deploy#github-pages).
