# Household admins and member approval

The household creator is its first admin. In **Your household → Everyone at home**, an admin can make any existing member another admin, remove admin access, or transfer their own role to another member. Making another admin preserves the caller's access; transferring promotes the recipient and demotes the caller in the same transaction. Other admins keep their roles. At least one admin must remain.

Admins configure chore stickers, create and replace invitation links, approve or decline join requests, manage themes/reward systems/teams, and change admin roles. Ordinary members can view their household, complete eligible chores, choose their own team, and manage their device notifications.

Invitation links now request membership. Following a link and submitting a name creates one pending request, not a membership. The requester sees its status and gains no access to household data before approval. Admins review requests under **Your household → Requests to join**. Requests update through Realtime, visibility refresh, a 30-second fallback check, and the requester's Check status button. A declined request can be resubmitted with a currently valid invitation.

## Backend enforcement

- Existing database role `owner` means **Admin**. It is retained for older installed clients; multiple members can hold it. No account metadata or editable JWT profile field grants admin access.
- `app_private.is_admin` checks the current authenticated user's membership. The legacy `is_owner` helper delegates to it.
- `set_household_admin` and `transfer_household_admin` authorize the caller, validate that the target is in the same household, and serialize on the household row. Removal cannot leave zero admins. Transfers update both roles atomically.
- Chore, invitation, team, theme and reward mutators use that same household lock before checking permissions. Revocations therefore take effect on subsequent actions, including actions queued behind a role change. Household locks use FOR NO KEY UPDATE to remain compatible with foreign-key checks during chore completion.
- `household_join_requests` has SELECT-only client grants and RLS for the requester or household admins. Clients cannot insert memberships, approve requests or update roles directly.
- `join_household` preserves its legacy UUID return type but now records a request. `decide_join_request` requires an admin and inserts only ordinary memberships. Approval is idempotent and respects the 50-member household limit.
- Requesters can have at most 10 pending requests; households can have at most 200. Private invitation tables remain inaccessible to ordinary clients.

The applied migration is `supabase/household-admins.sql`. Existing creators retain admin access and existing members retain their memberships. Older APKs cannot show the new role and approval controls; install the updated APK to use them.

## Verification

Rolled-back database fixtures exercise creator defaults, co-admins, sole-admin transfer, last-admin protection, former-admin revocation, normal chore completion, direct-write denial, pending-request privacy, duplicate requests, approval/decline, requester self-approval denial, and cross-household isolation. Browser fixtures cover confirmation/cancellation, admin controls disappearing after transfer, restricted member views, request waiting/refresh, and phone layouts across all themes. Unit tests cover role interpretation and the last-admin UI guard.
