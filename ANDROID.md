# Android app

The Android app bundles the React frontend with Capacitor 8 and uses the same Supabase backend as the website. It requires Android 7 or newer; NFC chores require an NFC-equipped phone with NFC switched on.

## Install on your phone

Open the repository's **Actions → Build Android APK**. Select the latest successful run and download **IDidTheDishes-Android** from Artifacts. Unzip it, transfer `app-debug.apk` to your phone, open it and allow that browser/file manager to install unknown apps when Android asks. This is a debug build for personal testing.

Sign in with Google. Supabase Auth's redirect allowlist must include `io.github.therealbiebs.ididthedishes://auth/callback`. No Google client secret belongs in the app.

## NFC

With the app in the foreground, hold the phone against a preloaded sticker. Assigned chores log for authorized members; unassigned stickers open claim/configuration for household admins. The Scan button can explicitly enter configuration mode. Platform admins use **Tag workshop** to create and write batches, verify URLs, and optionally permanently lock supported tags with explicit confirmation. Household admins assign stickers without writing them. See [PRELOADED-STICKERS.md](PRELOADED-STICKERS.md). These changes require a future rebuilt APK; the existing installed APK does not update automatically.

Existing website URL stickers still work. Outside the app, Android decides whether to open the app, show a chooser or open a browser. If offered, choose I Did The Dishes and Always. On some versions use Android Settings → Apps → I Did The Dishes → Open by default → supported web addresses. GitHub project Pages cannot supply domain-root verified App Links for this project, so automatic background routing is device-dependent. Opening the app before scanning is the reliable path.

## Develop from VS Code

Install Android Studio (with its Android SDK), use Node 22 or newer, then from this folder:

```powershell
npm ci
npm run android:sync
npm run android:open
```

Android Studio opens the `android` project. Connect your phone with USB debugging enabled, select it and press Run. `npm run android:apk` builds a debug APK locally once Java/Android SDK are configured. Every frontend change needs another `npm run android:sync` and native build. The installed app bundles assets and does not automatically update when GitHub Pages changes.

GitHub Actions also builds and runs Android lint on each relevant push. It caches the test signing key for updates; if that cache is ever lost Android may require uninstalling the older debug app first. Signing in again restores cloud data. A release signing key and Play Store publishing are separate future steps.

## Included and remaining

- Native NFC read/write, existing household/team/theme screens and live notification inbox.
- Google uses the system browser and PKCE; saved sessions and the PKCE verifier are encrypted with Android Keystore. Device backups are disabled.
- Closed-app Android notifications use Firebase Cloud Messaging. In Your household, choose Enable phone notifications and allow the Android permission prompt. Tokens are associated with the signed-in user, refreshed on launch, and removed on disabling notifications/sign-out. Tapping a notification opens that household’s inbox. Android force-stop, disabled notification channels, lack of Google Play services, network availability and battery settings can prevent delivery.
- Email sign-up/reset still need the previously deferred SMTP setup. Google sign-in does not require SMTP.
- NFC and Google return behavior need testing on your physical phone; a CI build cannot verify its hardware.

The React UI and backend remain reusable for a future Capacitor iOS project. Building/signing iOS later requires macOS/Xcode and Apple's device provisioning.

## Firebase configuration

The non-secret Android Firebase configuration is `android/app/google-services.json`. The backend service-account credential is encrypted in Supabase Vault as `dishes_fcm_service_account`, readable only through the service-role push worker. Never commit an admin key or put it in frontend environment variables. The worker uses FCM HTTP v1, the existing durable retry queue, and removes UNREGISTERED device tokens. Browser Web Push continues using the existing VAPID configuration.
