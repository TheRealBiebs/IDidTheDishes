# Preloaded chore stickers

## Prepare stickers as a platform admin

Platform-admin access is separate from household administration. The selected account, `andrewpbieber@gmail.com`, has access to **Tag workshop** in the app navigation. Ordinary household admins cannot issue inventory or grant themselves platform access.

1. Create a named batch of 1–200 stickers. Each gets a registered, random URL on the existing website domain.
2. In a future Android build containing these changes, open the batch and choose **Write sticker**, then hold a blank NDEF-compatible sticker against the phone. A different existing URL or other data will not be overwritten.
3. The app reads the URL back before marking the sticker ready. Some stickers need formatting first: remove and retap them using **Verify sticker**. An unverified sticker cannot be claimed.
4. To lock stickers, enable permanent locking and confirm the irreversible operation. The app verifies the exact URL before attempting the Android read-only operation. Unsupported stickers are reported as ready but unlocked; they are never reported as locked.
5. Give verified stickers to friends. No household information is encoded on them, and friends do not need a writer.

The browser workshop can create batches and export a CSV of URLs. Physical writing and verification use the Android plugin. An older installed APK needs a new build before using this workflow. No APK was built as part of this change.

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

Applied SQL sources: `supabase/preloaded-stickers.sql`, `sticker-admin-households.sql`, `sticker-inventory-policies.sql`, and `sticker-release-request-feedback.sql`. These are migration references, not scripts to rerun on the existing project. Platform access is stored in a private server-managed table, never user-editable metadata. Inventory is private; clients use guarded RPCs. Existing assigned sticker URLs were migrated and remain valid.

Verification covered rolled-back database fixtures for roles, public privacy, atomic claims, cross-household isolation, release/reclaim, history, and daily limits; 15 unit tests; a production frontend build; and browser fixtures for public/member/admin flows and simulated Android write/verify/lock receipts. Java changes have not been compiled or tested against real NFC hardware. Physical readback, retap, permanent locking, and Android deep-link behavior still need a device test after the next requested APK build.
