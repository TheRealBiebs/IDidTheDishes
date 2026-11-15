# Chip In

A mobile-friendly household chore app using React, Supabase, and GitHub Pages.

Android app: see [ANDROID.md](ANDROID.md) for installing the APK, native NFC, and Android Studio development.

Household reward systems: see [REWARD-SYSTEMS.md](REWARD-SYSTEMS.md) for gemstone points, the gold-star calendar, and the adventurer preview scaffold.

Chore configuration includes signed **Point adjustments** for Shabbily, Good enough, To perfection, Quick maintenance, Standard, and Nightmare / disaster area. All default to zero. The selected quality and starting-condition adjustments combine with the base reward, with a minimum total of zero. For example, base 10 + perfection 5 + nightmare 8 awards 23 points. Leaving traits unselected adds nothing.

Each completion snapshots its base reward and adjustment rules when logged. Changing or clearing optional ratings recalculates that same completion instead of adding another reward; later configuration changes affect new completions only. Rating edits also correct archived weekly point totals and winners. Gold-star calendars still award one star per completion, and unexpected-chore roulette rewards remain unchanged. Backend reference: `supabase/chore-trait-rewards.sql`; rollback verification: `supabase/verify-chore-trait-rewards.sql`.

Household admins: see [HOUSEHOLD-ADMINS.md](HOUSEHOLD-ADMINS.md) for co-admins, transfers, and membership approval.

Household creation includes a reward-system selector: gemstone points, a gold-star calendar, or the adventurer preview. The choice, theme, and selected starter chores are saved together. Admins can change the reward system later under **Your household**.

Admins can also choose **Your household → Delete household** and type its exact name to confirm. This permanently removes the household's shared chores, teams, history, invitations, and notifications for all members. Accounts and other households remain. Its preloaded stickers become unassigned and reusable, including permanently locked stickers. The applied backend addition is documented in `supabase/household-lifecycle.sql`.

Preloaded stickers: see [PRELOADED-STICKERS.md](PRELOADED-STICKERS.md) for the platform-admin workshop, optional permanent locking, household claims, release requests, and starter chores.

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

Open **Your household → Theme & teams** as the household admin. Choose **Wizard Adventure**, **The Cat’s Meow**, **Squeaky Clean**, or **Busy Mom & Dad**. The theme applies to everyone viewing that household, with its own dashboard styling, decorative art, text, and point jars. New households can choose their theme during creation and automatically receive four matching starter teams.

Every theme supports custom teams. Admins can add teams, rename them, set the exact gem-filling colour with a colour picker or hex code, choose an emblem, and assign members to teams. Members can choose their own team from the dashboard. Up to 20 teams are supported; the tube display scrolls horizontally when needed.

Theme changes preserve team IDs, custom names, colours, memberships, and points. **Add starter teams** adds the current theme’s suggestions without replacing existing teams and can be repeated without duplicates. Teams can be archived only after their members have moved elsewhere. Archived teams can be reactivated through the editor.

`household_teams` has household-scoped RLS and read-only browser grants. Theme/team mutations are admin-only RPCs; team selection checks membership and the team’s household. An admin can assign another member’s team, while ordinary members may only change their own. A composite foreign key prevents cross-household team assignments. Colours are restricted to six-digit hex values and team names are unique within a household, ignoring case. `supabase/household-themes.sql` documents the applied addition.

Existing wizard-team selections were migrated to configurable teams, preserving their names, colours, and member assignments. The legacy house-choice API remains compatible, while the app uses the generic `choose_team` API. Current-week points follow the member’s current team in every theme; personal points and completion records are unchanged.

The main components are `src/HouseholdThemes.jsx` and `src/themes.css`. `src/WizardTheme.jsx` supplies the shared glass/gem artwork and wizard decorations. The light themes use original cat, sponge, bubble, heart, and coffee artwork; no third-party brand assets are embedded. Motion respects reduced-motion settings.

## Weekly competition

Weeks reset on Monday at midnight in the household's time zone. Gemstone teams compete on chore points; the star calendar and adventurer preview compete on chore counts. Each positively scoring winning team earns **one weekly win point**, tracked separately from chore points. Tied leaders each receive one; an empty or zero-scoring team competition has no winner.

On the first visit after a reset, the app settles completed weeks and shows the latest result with gems bursting from the winning jar, stars leaving the calendar, or a trophy for the adventurer preview. A short server-side claim prevents simultaneous devices from showing the same account's celebration. The app records it as seen after the animation or dismissal; a crashed app can retry after the claim expires. Reduced-motion settings are respected. NFC logging still happens immediately before its weekly overlay.

**Your household → Hall of Fame** shows all-time weekly win points and paginated weekly results. Open a week to see its standings, filter chores by team, and inspect archived details and private photo proof. Scores, team appearance, and chore records are frozen for each result. Team changes and reward-system changes after the boundary cannot rewrite a closed week's result.

Competition history starts with the week this feature is enabled (including chores already logged in that week). Earlier weeks are not reconstructed from today's memberships. Finalization happens on the next household visit, without an extra scheduled service; membership and configuration history preserve the state at the actual boundary even when nobody opens the app that day.

Applied backend references: `supabase/weekly-competition.sql` and `supabase/weekly-celebration-delivery.sql`. `supabase/verify-weekly-competition.sql` contains rolled-back fixtures covering boundaries, membership/configuration changes, single awards, archive immutability, pagination, celebration claims, acknowledgement, and household isolation. Frontend tests cover reward animations, Hall of Fame navigation/filtering, reduced motion, and native scan integration.

## Wizard Adventure visuals

The app has a dark wizard-adventure theme with CSS firelight, house banners, brass/glass counters, and faceted SVG gemstones. Motion respects the device’s **Reduce motion** preference. No audio or flashing effects are used.

On the dashboard, choose **Choose your team** (or change it under **Your household**). The wizard-adventure starter teams are Ember Guild, Moonstone Circle, Stormwatch Order, and Sunstone Fellowship. These are now ordinary configurable teams; admins can rename them or change their colours just like teams in every other theme.

The four house tubes show the sum of current members’ server-issued points for the current week. The personal vault shows your own contribution in your house’s gemstone color. Changing houses moves your current-week points to the new house; personal points and completion history stay unchanged. Unsorted points remain personal until the member chooses a house. Tube capacity scales upward as points increase, and the displayed scale makes the fill level explicit. Scores still reset each Monday using the household time zone.

`src/WizardTheme.jsx` contains the crests, banners, torches, tube/gem rendering, and house picker. `src/wizard.css` supplies the theme across sign-in, dashboard, chores, and dialogs. The applied database addition is documented in `supabase/wizard-houses.sql`.

## First household

1. Create an account and confirm your email. Sign in once on each browser/device; sessions persist until sign-out or browser storage/session expiry.
2. Create a household with its name, your display name, and the household time zone. A user can belong to multiple households.
3. Select any of 12 starter chores during creation, or add custom chores later. Household admins configure chore names, locations, points, shared daily limits, eligible members, and active state.
4. Scan a preloaded, verified sticker as an admin to assign and claim it. Friends do not need to write stickers. Platform admins prepare batches separately in **Tag workshop**; see [PRELOADED-STICKERS.md](PRELOADED-STICKERS.md).
5. Share the household invitation link. Anyone with a valid link can request membership; an admin must approve them. An admin can replace the invitation link. Share links privately.
6. A scan in the installed app records the chore for an authorized member. Browser scans show a preview with an explicit logging action. Signed-out visitors see app information and sign-in options; foreign households can request release. Browsers cannot prove a physical scan: copied URLs also work subject to server checks.
7. View household points and chore counts for the current Monday-based week, today’s totals, recent activity, and a private notification inbox.

NFC links use query parameters rather than path routing so they work on GitHub Pages. Settings changes keep the physical sticker URL stable. Only registered, verified inventory can be claimed. Release preserves the original chore history and makes the physical URL available for another household.

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

Every exposed household table has RLS. Browser roles receive SELECT access only and use validated RPCs for mutations. Privileged functions live in the non-exposed `app_private` schema behind security-invoker public wrappers. Invites, push jobs, and Vault secrets are not browser-readable. The household admin configures tags; membership and authorization never depend on editable user metadata.

The Edge Function source is `supabase/functions/chore-push/index.ts`. Deploy through Supabase with gateway JWT verification disabled because the handler itself authenticates the database webhook secret; anonymous requests receive 401. The function uses the automatically supplied `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` server environment variables.

## Chore cooldowns

Household admins can choose Automatic, Custom duration, or No cooldown when configuring a chore that can be done more than once daily. Automatic is 720 minutes divided by the daily limit, rounded to the nearest minute (three per day means four hours). Changing the daily limit updates the automatic wait. Custom waits range from 1 to 1440 minutes.

The wait is shared across all household members and measured from the latest completion, including across midnight. The daily household cap still applies. Scan retries return the same completion without awarding points again, and optional details do not start another cooldown. Single-completion daily chores use the daily cap alone. Existing repeatable chores default to Automatic.

Apply `supabase/chore-cooldowns.sql` after the existing schema updates. `cooldown_minutes` stores NULL for Automatic, zero for disabled, or a positive custom duration. Legacy save/claim RPCs remain available; the new `save_tag_with_cooldown` and `claim_sticker_with_cooldown` RPCs include the setting. `supabase/verify-chore-cooldowns.sql` exercises household enforcement, expiry, overrides, claims, legacy compatibility, permissions, and idempotency with rolled-back fixtures.

## Install Chip In as a PWA

On iPhone, open the deployed site in Safari, choose Share → Add to Home Screen, keep Open as Web App enabled if offered, and tap Add. Open Chip In from its new icon, sign in, and enable phone notifications in the Notifications tab. Web Push requires iOS 16.4 or later and permission from the user. Android users can use their browser's Install app/Add to Home screen action. No Apple developer account is needed for the PWA.

Prewritten sticker URLs work with the same accounts and household data as the native app. A sticker opened inside the installed PWA automatically submits an eligible chore. A URL opened in Safari shows the chore with an explicit Log this chore button; users may need to sign in separately in Safari. iOS controls the NFC URL notification and does not expose NFC reading/writing to the web app. Bulk sticker writing remains available on supported Android devices.

Web scan submission IDs persist with the page's history entry so reloading or resuming that entry cannot award the same chore again. A fresh sticker visit creates a new submission. The server still enforces assignments, eligibility, limits, and cooldowns.

Production builds generate a versioned service worker with the public app assets precached. Offline navigation shows a reconnect screen; chore submissions are not queued and are never treated as completed offline. Auth responses, household API data, and photo proof are excluded from caching. An Update Chip In button activates a waiting worker when the user chooses. The two latest app caches are retained to support existing tabs.

Use `npm run build` and `npm run preview` to check installation/service-worker behavior locally. Development mode does not register the production worker. Install guidance appears at login and in the household tab. Real iPhone sign-in, NFC URL handoff, and lock-screen push delivery still require a device check.

## Community leaderboard

The Leaderboard tab starts with a sharing disclosure. A household admin must explicitly join before the household is listed, and each member must accept the disclosure before viewing the community board. Households are private by default. Admins can leave to stop sharing immediately and revoke community access for all household members; rejoining requires fresh viewer consent.

Only household names, active team names, and current-week aggregate chore points are shared, with derived totals/ranks. Weeks reset on Monday in each household's own time zone. The community uses raw chore point totals across reward systems and includes points already earned during the current week when joining. Team totals follow current team membership, matching the live household scoreboard. Individual identities, chore records, comments, and proof photos remain protected by existing RLS.

Following is private to the signed-in account. The Following filter includes selected households and the viewer's own household; its selected view is remembered per account/household in the browser. Rankings retain their overall community position. Results are paginated in groups of 25 and refresh periodically while the tab is visible.

Apply `supabase/community-leaderboard.sql` after the existing schema updates. Enrollment, consent, and follows are stored in private tables accessed only through validated RPCs. `supabase/verify-community-leaderboard.sql` checks consent gates, weekly totals, aggregate-only disclosure, raw-data isolation, personal follows, and withdrawal with rolled-back fixtures.

## Household comments and likes

Use Comments & likes on a completed chore in Recent activity, or expand a completion's details in chore history or the Hall of Fame. Likes can be removed; the first like from each household member notifies the original doer once. Each new comment notifies the doer with the comment text. Self-actions and removed likes do not send notifications. Author notes in the optional completion-details form remain separate from the conversation.

Conversations are household-private and do not affect points or community leaderboard data. Comment threads and like counts update through Realtime, with a visible-page refresh fallback. Comments are limited to 1000 characters and paginated in groups of 50. Submission IDs make comment retries safe after a lost response. Notifications are sent only while the original doer is still a member of the household.

Apply `supabase/chore-conversations.sql` after the previous schema updates. It adds read-protected social tables, mutation RPCs, and the completion ID to claimed push jobs. The `chore-push` Edge Function uses that ID in web and Android notification URLs. The inbox message opens the same completion; native and Google-auth return routing preserve its ID. `supabase/verify-chore-conversations.sql` verifies notification recipients, retry behavior, private access, and unchanged awards using rolled-back fixtures.

## Refuting a completion

Household members can refute another member's completion from its Comments & likes section, with an optional reason of up to 1000 characters. The original doer is notified, and one pending refutation is allowed per completion. Pending refutations leave the reward in place.

Only the original doer can resolve a refutation. Mark redone keeps the existing completion, date, and points without awarding another completion. Remove completion deletes the completion and its reward, frees its schedule/cooldown slot, and corrects any archived weekly snapshots, team scores, and weekly winners. Removal requires a second confirmation in the UI. A resolved request can be retried safely; an old removed scan request cannot recreate the reward. New sticker visits use a fresh request as usual. Refutation request markers remain household-private for retry protection.

Apply `supabase/chore-refutations.sql` after chore conversations. The hosted project applied the schema, resolution logic, and thread/scan integration as three smaller migrations. `supabase/verify-chore-refutations.sql` covers both resolution paths, authorization, duplicate requests, periodic quota release, removed-scan replay denial, archived score correction, and household deletion using rolled-back fixtures.

## Future Android and iPhone apps

The Capacitor Android project is included; see [ANDROID.md](ANDROID.md). The React frontend and Supabase APIs can also be reused for a future iOS project. Building and signing iOS requires macOS/Xcode and Apple provisioning. No iOS packaging is included yet.

## Verification

The first application release was exercised with disposable QA accounts and two isolated households. Tests covered real password login, household creation/joining, invitation rotation, admin-only settings, cross-household isolation, server-owned awards, eligible members, paused tags, simultaneous scans at the daily limit, idempotency, duplicate-read cooldown, unchanged historical points, dashboard aggregates, inbox recipients, and secret access restrictions.

Browser checks covered desktop/mobile layouts, sticker create/edit, invitation dialogs, automatic URL-triggered logging, and persisted sessions. The database-to-worker webhook and encrypted push path were tested against a deliberately invalid test endpoint; expired subscriptions were removed. Actual NFC hardware and background delivery to a real phone still require an opted-in device test. Temporary QA data is removed before handoff.

References: [Supabase Auth](https://supabase.com/docs/guides/auth), [Row-level security](https://supabase.com/docs/guides/database/postgres/row-level-security), [Apple NFC URL reading](https://developer.apple.com/documentation/corenfc/adding-support-for-background-tag-reading), [WebKit Web Push](https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/), [Capacitor](https://capacitorjs.com/docs).
