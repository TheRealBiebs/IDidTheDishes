# Household scan experience

Assigned sticker pages use the owning household's current theme, including the public preview. Unassigned and unknown tags remain neutral. Public previews expose only the chore title, visual theme, and reward-system identifier; membership, team identity, comments, photos, location, and eligibility remain private.

In Android, a normal eligible scan still logs immediately. A confirmed completion plays a short reward animation: colored gems fall into a jar using the member's team color, a gold star joins a small calendar for the star system, or a simple chore celebration appears for the adventurer preview. Animations respect reduced-motion preferences, and updating details does not replay them. Browser scans retain the explicit Log this chore action.

Optional details have no default selection:

- Performed: Shabbily, Good enough, To perfection.
- Starting state: Quick maintenance, Standard, A disaster area.
- A comment of up to 2,000 characters.
- One photo, selected from the device's camera/library picker.

Changes autosave after a brief pause to the **same completion**. Ratings never multiply points, create another completion, or send another chore notification. The page shows saving/error/retry feedback. App navigation buttons wait for pending saves; leaving via OS/browser navigation before a save finishes may interrupt it. Household members can view saved details and photo proof through View details in recent activity. Only the member who logged the chore may edit it.

Photo input accepts images up to 20 MB locally and re-encodes them to JPEG at a maximum 1,600 pixels on the longest edge. Re-encoding drops the original metadata. The private `chore-proof` bucket enforces a 3 MB stored-object limit. Formats the device cannot decode show an error asking for JPEG, PNG, or WebP.

Upload paths include household, author, completion ID, and a random filename. Storage policies permit uploads only for the author's existing completion. Proof must exist and belong to that author/completion before attachment. Members access attached proof with short-lived signed URLs; removed members and signed-out visitors cannot request them. Replaced, unattached proof is removed on a best-effort basis. Detached files from interrupted uploads or deleted records may require storage cleanup; they are never public.

Backend references: `supabase/chore-details-and-proof.sql` and `supabase/chore-proof-policy-hardening.sql`. Existing completion clients remain compatible. `complete_chore` still owns points, daily limits, cooldowns and notifications. `save_chore_details` handles later edits without awarding again.

Verification includes optional/null defaults, photo sizing, mocked Android auto-logging, all four themes, autosave/retry, mocked storage upload, and mobile layouts. Real phone file picking, camera behavior, photo decoding and NFC still require the accompanying APK test. The rolled-back database fixture test was prepared but could not run because the tool's confirmation expired; read-only bucket/permission checks and security advisors were completed.
