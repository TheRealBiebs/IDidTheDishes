# Preloaded chore stickers

## Prepare stickers as a platform admin

Platform-admin access is separate from household administration. The selected account, `andrewpbieber@gmail.com`, has access to **Tag workshop** in the app navigation. Ordinary household admins cannot issue inventory or grant themselves platform access.

1. Create a named **writing session**. No sticker count is required.
2. In the Android app, choose the session and press **Start writing** once. Tap a blank NDEF-compatible sticker, wait for verification, then remove it and tap the next. Each sticker gets a newly registered, unique URL. No chore or household is assigned during writing.
3. If a sticker first needs formatting, the writer automatically asks you to remove and retap the same sticker to verify the same URL. It does not advance until verification and registration succeed.
4. Optional permanent locking still requires the irreversible-operation checkbox. Supported tags are locked only after URL readback. Unsupported locking is reported, and the sticker is registered as unlocked.
5. Press **Stop writing** when finished. Resume keeps the pending URL. Failed server acknowledgements retain the verified receipt for retry without rewriting the sticker. Pending reservations remain unclaimable until registered as verified. After reopening the app, use **Verify existing sticker** for a pending physical sticker, or start writing more blanks.
6. Give verified stickers to friends. Scanning an unclaimed sticker as a household admin goes directly to claim/configuration: choose from the household's chore list or configure a new custom chore. Chores with an existing sticker are shown but unavailable until their sticker is released.

The browser workshop can create sessions and export URLs. Physical writing/verification use Android. These continuous-writing changes need a future rebuilt APK; no APK was built for this change. Leaving the workshop or hiding the app stops the writer. While armed, normal scanned links do not navigate away or award chores.

Permanent locking prevents rewriting the physical URL on supported tags. It cannot be undone. Household assignment and chore settings remain changeable in the database, so a locked sticker can still be released and reused. Losing the hosting domain would affect locked stickers; keep these URLs stable. Locking does not prevent somebody copying a URL onto another sticker.

## Create a household and assign chores

Household creation offers 12 starter chores, all optional: dishes, dishwasher, trash, recycling, counters, vacuuming, sweeping, laundry, folding laundry, bathroom, pets, and plants. Select any subset. These create configurable chores without minting sticker URLs. Admins can also add starter chores later or create custom chores.

Use **Scan sticker to assign** on a chore, or scan an unassigned sticker as a household admin. Choose a household you administer and an unassigned chore, or configure a new custom chore. Set points, household-wide daily limit, eligible members, location, and active state, then claim the sticker. Claiming does not log a completion. One issued sticker binds to one chore at a time.

## Scan behavior

| Scanner context | Result |
| --- | --- |
| Signed out, including a phone without the app | Neutral landing page explaining the app and showing an assigned chore's title, with sign-in/sign-up options. |
| Signed in, without a household | Landing page with create/join guidance; household creation preserves the pending sticker. |
| Household admin + ready unassigned sticker | Chore configuration and claim form. |
| Ordinary member + unassigned sticker | Ask a household admin to claim it. |
| Own household's assigned sticker, installed Android app | Record the chore automatically, except an explicit configuration scan. |
| Own household's assigned sticker, browser | Preview with an explicit **Log this chore** action. |
| Another household's assigned sticker | Explain ownership and offer a release request for one of the scanner's households. |
| Unknown URL token or unverified inventory | No claim or chore award. |

Routing uses the authenticated account's membership and the app runtime. Browsers cannot reliably establish whether the native app is installed. Android decides whether a background URL scan opens the app or browser; opening the app before scanning gives reliable foreground native handling. No device fingerprint is used.

Chore titles are intentionally public to people with the URL. Public/foreign previews do not expose household identity, members, locations, points, eligibility, or schedules. The URL is not proof of a physical NFC scan: copying it remains possible. Server authorization and daily limits still apply.

## Release and reuse

An admin can release a sticker from **Chore & sticker**, or review incoming release requests on the chores screen. Only an admin of the current owning household can approve release. A requester cannot take a tag directly. Declining leaves ownership unchanged.

Release makes the same physical URL available for a new claim. The original chore and its completion history stay in the original household. Replacing that chore's sticker does not reset its daily usage. Versioned ownership prevents an old release request from affecting a later claim.

## Backend and verification

Applied SQL sources: `supabase/continuous-sticker-writing.sql`, `supabase/preloaded-stickers.sql`, `sticker-admin-households.sql`, `sticker-inventory-policies.sql`, and `sticker-release-request-feedback.sql`. These are migration references, not scripts to rerun on the existing project. Platform access is stored in a private server-managed table, never user-editable metadata. Inventory is private; clients use guarded RPCs. Existing assigned sticker URLs were migrated and remain valid.

Verification covered rolled-back database fixtures for roles, public privacy, atomic claims, cross-household isolation, release/reclaim, history, and daily limits; 15 unit tests; a production frontend build; and browser fixtures for public/member/admin flows and simulated Android write/verify/lock receipts. Java changes have not been compiled or tested against real NFC hardware. Physical readback, retap, permanent locking, and Android deep-link behavior still need a device test after the next requested APK build.
