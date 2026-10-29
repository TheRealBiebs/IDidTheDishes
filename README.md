# I Did The Dishes

A mobile-friendly household chore app using React, Supabase, and GitHub Pages.

Android app: see [ANDROID.md](ANDROID.md) for installing the APK, native NFC, and Android Studio development.

Live: https://therealbiebs.github.io/IDidTheDishes/

## Develop in VS Code

Use Node.js 22.12 or newer. npm comes with Node.js.

```sh
npm install
npm run dev
```

Open the local URL printed in the terminal. Saved changes update the development preview.

```sh
npm run build
npm run preview
```

The production output is `dist/`. GitHub Actions uses `npm ci` and deploys every push to `main`.

## Household themes and teams

Open **Your household → Theme & teams** as the household owner. Choose **Harry Potter · Wizarding Houses**, **The Cat’s Meow**, **Squeaky Clean**, or **Busy Mom & Dad**. The theme applies to everyone viewing that household, with its own dashboard styling, decorative art, text, and point jars. New households can choose their theme during creation and automatically receive four matching starter teams.

Every theme supports custom teams. Owners can add teams, rename them, set the exact gem-filling colour with a colour picker or hex code, choose an emblem, and assign members to teams. Members can choose their own team from the dashboard. Up to 20 teams are supported; the tube display scrolls horizontally when needed.

Theme changes preserve team IDs, custom names, colours, memberships, and points. **Add starter teams** adds the current theme’s suggestions without replacing existing teams and can be repeated without duplicates. Teams can be archived only after their members have moved elsewhere. Archived teams can be reactivated through the editor.

`household_teams` has household-scoped RLS and read-only browser grants. Theme/team mutations are owner-only RPCs; team selection checks membership and the team’s household. The owner can assign another member’s team, while ordinary members may only change their own. A composite foreign key prevents cross-household team assignments. Colours are restricted to six-digit hex values and team names are unique within a household, ignoring case. `supabase/household-themes.sql` documents the applied addition.

Existing wizarding house selections were migrated to configurable teams, preserving their names, colours, and member assignments. The legacy house-choice API remains compatible, while the app uses the generic `choose_team` API. Current-week points follow the member’s current team in every theme; personal points and completion records are unchanged.

The main components are `src/HouseholdThemes.jsx` and `src/themes.css`. `src/WizardTheme.jsx` supplies the shared glass/gem artwork and wizard decorations. The light themes use original cat, sponge, bubble, heart, and coffee artwork; no third-party brand assets are embedded. Motion respects reduced-motion settings.

## The wizarding theme

The app has a dark wizarding-school theme with CSS firelight, house banners, brass/glass counters, and faceted SVG gemstones. Motion respects the device’s **Reduce motion** preference. No audio or flashing effects are used.

On the dashboard, choose **Choose your team** (or change it under **Your household**). The wizarding starter teams are Gryffindor, Slytherin, Ravenclaw, and Hufflepuff. These are now ordinary configurable teams; owners can rename them or change their colours just like teams in every other theme.

The four house tubes show the sum of current members’ server-issued points for the current week. The personal vault shows your own contribution in your house’s gemstone color. Changing houses moves your current-week points to the new house; personal points and completion history stay unchanged. Unsorted points remain personal until the member chooses a house. Tube capacity scales upward as points increase, and the displayed scale makes the fill level explicit. Scores still reset each Monday using the household time zone.

`src/WizardTheme.jsx` contains the crests, banners, torches, tube/gem rendering, and house picker. `src/wizard.css` supplies the theme across sign-in, dashboard, chores, and dialogs. The applied database addition is documented in `supabase/wizard-houses.sql`.

## First household

1. Create an account and confirm your email. Sign in once on each browser/device; sessions persist until sign-out or browser storage/session expiry.
2. Create a household with its name, your display name, and the household time zone. A user can belong to multiple households.
3. Start by setting up one or more chore stickers. Household owners manage sticker settings: chore name, location, points, a household-wide daily limit, eligible members, and active/paused state.
4. Open a sticker’s settings and write its unique HTTPS URL as an NDEF **URL record** onto an NFC sticker. Supported Android browsers offer **Write NFC sticker**. On iPhone, copy the URL into an NFC-writing app. Choose rewritable NDEF stickers and test your phone/tag combination before deploying them around the house.
5. Share the household invitation link. Invitations can be replaced by the owner; an old link then stops working. Anyone with a valid link can join, so share privately.
6. Tap a programmed sticker, open the phone’s NFC link prompt, and the app logs the chore for the signed-in user. If signed out, the pending tag remains in the URL until sign-in. Browsers cannot prove a physical scan: opening a copied sticker URL also counts.
7. View household points and chore counts for the current Monday-based week, today’s totals, recent activity, and a private notification inbox.

NFC links use query parameters rather than path routing so they work on GitHub Pages. Settings changes keep the sticker URL stable. A new sticker gets a separate token.

The database enforces authorization, points, timestamps, and daily limits. It locks the sticker row while recording a completion, so concurrent scans cannot exceed the household limit. A request ID makes retries idempotent; a 30-second per-user/tag cooldown protects against repeated phone reads. Limits reset at midnight in the household’s configured time zone. Historical points and chore names remain snapshots even after settings change.

## Google sign-in

The sign-in and create-account screens include **Continue with Google**, using Supabase OAuth. NFC and invitation links are preserved across the redirect on the same device. Google profile names prefill household onboarding; authorization still comes from database membership, never profile metadata. Only the standard identity scopes are used.

One-time provider setup:

1. Choose/create a project in [Google Auth Platform](https://console.cloud.google.com/auth/overview). Configure branding and audience. In Data Access, use only the standard `openid`, email, and profile scopes. While in Testing, add the Google accounts that will use the app as test users.
2. Create a **Web application** OAuth client.
3. Authorized JavaScript origins: `https://therealbiebs.github.io` and, for local development, `http://127.0.0.1:5173`.
4. Authorized redirect URI: `https://oqciivgizvuzuxxzhglq.supabase.co/auth/v1/callback`.
5. Enable Google in [Supabase Auth Providers](https://supabase.com/dashboard/project/oqciivgizvuzuxxzhglq/auth/providers?provider=Google), save the Client ID and Client Secret there, and keep nonce checking enabled. The secret must never be added to frontend code, Git, or `VITE_*` variables.
6. Supabase Site URL and allowed redirect URLs must include the live site and local development URL as listed below.

Until the provider is enabled, the button explains that setup is still needed. Google sign-in does not depend on custom SMTP. Email/password confirmations and password resets still do. Final verification requires a real Google-account sign-in after provider setup.

## Phone notifications

Open **Your household → Enable phone notifications** on each device. A successful chore creates an inbox notification for every *other* member and queues a push for their opted-in devices.

On iPhone/iPad, Web Push requires a supported iOS/iPadOS version (16.4+) and adding the site to the **Home Screen**, opening it from there, and granting notifications. On other platforms, use a browser with Web Push support. NFC links may open the regular browser rather than the Home Screen app; those contexts may require separate sign-ins. Device permissions, Focus modes, network state, and OS/browser policies affect delivery.

`public/sw.js` handles background push and notification clicks. The service worker does not cache private household data and does not provide offline chore logging. A successful online server response is required before points are awarded.

The `chore-push` Supabase Edge Function uses standard Web Push/VAPID. It authenticates database requests with a random webhook secret. VAPID private keys and that secret are stored in **Supabase Vault**, never in browser code or Git. Only the service role can retrieve the runtime secrets. The public key lives in `src/push-config.json`.

Notification jobs wake the sender immediately via `pg_net`; `pg_cron` retries pending work every minute with exponential backoff (up to five attempts). Expired subscriptions are removed. Push delivery is best effort; inbox notifications remain available. The queue retries may occasionally duplicate a push after an interrupted delivery; notification IDs are stable to let the service worker replace duplicates.

## Supabase setup and configuration

Project: **IDidTheDishes** (`oqciivgizvuzuxxzhglq`) on the Free plan.

The existing live project already has the schema, Realtime publication, Vault secrets, retry schedule, and Edge Function deployed. Do not rerun schema files against it.

The SQL sources are `supabase/app-schema.sql`, `supabase/dashboard.sql`, and `supabase/push-hardening.sql`; Supabase migration history records the applied changes. The legacy `supabase/schema.sql` is only the old hello-world demo.

Auth URL configuration:

- Site URL: `https://therealbiebs.github.io/IDidTheDishes/`
- Allowed redirect: `https://therealbiebs.github.io/IDidTheDishes/`
- Development redirect: `http://127.0.0.1:5173/**`

**Remaining setup: custom SMTP.** Supabase’s default mail service only delivers to project-team addresses and has a small rate limit. Configure custom SMTP under Supabase Auth before inviting ordinary household users; sign-up confirmations and password resets depend on it. Email confirmations remain enabled. See [Supabase SMTP setup](https://supabase.com/docs/guides/auth/auth-smtp).

`src/supabase-config.json` contains the intentionally public project URL and publishable key. Optional `.env.local` values `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` override them. Vite embeds these into public JavaScript: never use secret/service-role keys in `VITE_*` variables.

Every exposed household table has RLS. Browser roles receive SELECT access only and use validated RPCs for mutations. Privileged functions live in the non-exposed `app_private` schema behind security-invoker public wrappers. Invites, push jobs, and Vault secrets are not browser-readable. The household owner configures tags; membership and authorization never depend on editable user metadata.

The Edge Function source is `supabase/functions/chore-push/index.ts`. Deploy through Supabase with gateway JWT verification disabled because the handler itself authenticates the database webhook secret; anonymous requests receive 401. The function uses the automatically supplied `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` server environment variables.

## Future Android and iPhone apps

No native project or App Store packaging is included. React, Supabase’s HTTPS APIs, and the SQL RPCs can be reused in a future Capacitor app. Browser NFC and Web Push are isolated in `src/platform.js`; native NFC, deep links, secure session storage, and APNs/FCM adapters will require platform work later. Physical URL stickers can remain the entry point. Web Push subscriptions are browser-specific and are not a substitute for native push tokens.

## Verification

The first application release was exercised with disposable QA accounts and two isolated households. Tests covered real password login, household creation/joining, invitation rotation, owner-only settings, cross-household isolation, server-owned awards, eligible members, paused tags, simultaneous scans at the daily limit, idempotency, duplicate-read cooldown, unchanged historical points, dashboard aggregates, inbox recipients, and secret access restrictions.

Browser checks covered desktop/mobile layouts, sticker create/edit, invitation dialogs, automatic URL-triggered logging, and persisted sessions. The database-to-worker webhook and encrypted push path were tested against a deliberately invalid test endpoint; expired subscriptions were removed. Actual NFC hardware and background delivery to a real phone still require an opted-in device test. Temporary QA data is removed before handoff.

References: [Supabase Auth](https://supabase.com/docs/guides/auth), [Row-level security](https://supabase.com/docs/guides/database/postgres/row-level-security), [Apple NFC URL reading](https://developer.apple.com/documentation/corenfc/adding-support-for-background-tag-reading), [WebKit Web Push](https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/), [Capacitor](https://capacitorjs.com/docs).
