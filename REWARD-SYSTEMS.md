# Household reward systems

In **Your household → Reward system**, the household admin can select a reward system independently of the visual theme. Members see the same system. All existing and newly created households default to gemstone points.

| System | Available now | Chore reward |
| --- | --- | --- |
| Gemstone points | Team columns, personal tube, weekly point ranking | The chore's configured point value |
| Gold-star calendar | Month navigation, member filtering, daily breakdown by chore, weekly star ranking | Exactly one star per completed chore |
| Household adventurers | Clearly labelled character, equipment, loot and practice-battle preview | Chores are logged; no real loot, inventory or battle results are issued yet |

The demo loadout and training dummy use screen-local state. Reloading discards them. They do not award items, create an inventory or challenge another member.

## Data and history

`households.reward_scheme` stores the selection. `set_reward_scheme` is an admin-only RPC. Existing household RLS controls reads, and household Realtime updates refresh the selection on other open clients.

`chore_completions` remains the canonical history for every system. NFC scans, eligible members, shared daily limits, idempotency and notification delivery use the same completion pipeline. Point values remain stored so switching back can restore the point view. Point controls are hidden while using a different system; existing point values are retained.

Calendar stars are a projection of all historical completions, including those logged before the calendar was selected. Each completion is one star regardless of its point value. The month is aggregated in Postgres through the member-only, RLS-enforced `reward_calendar` RPC; it is not derived from the recent-activity feed or a limited browser query. Dates use the stored household-local `chore_date`.

Weekly comparison uses points for the gemstone system and completion counts for the other systems. The calendar itself displays the selected month's stars. Notifications describe the active reward at completion time; historical notifications keep their original wording.

## Extending the scaffold

1. Add stable metadata in `src/rewards/registry.js`: ID, label, availability, rule description and comparison unit.
2. Add a dashboard component and register it in `src/rewards/RewardDashboard.jsx`. All systems receive household, theme, teams, members, current user, weekly scores and a refresh revision. Theme and reward code are separate.
3. Add the scheme ID to the database constraint and admin setter through a migration. Keep old IDs and default behavior compatible with older installed APKs.
4. Add any server-side award logic to the authenticated completion transaction. Never trust browser requests to choose rewards, item ownership or battle outcomes.
5. Cover scoring, permissions, idempotency and UI behavior; run `npm test` and `npm run build`. Build a new APK for bundled mobile UI changes.

For the eventual adventure engine, add a server-owned item catalog, inventory with unique completion-to-drop references, validated equipment slots, and versioned drop rules. Battles will need explicit challenges/acceptance, household membership checks, server-resolved outcomes and immutable battle records. No inventory or battle tables are created by this scaffold, so the eventual rules can be designed before committing household data to them.

## Validation

Automated unit tests cover count-based star ranking, calendar layout/leap years/month transitions, fallback behavior and preview wording. Database checks use rolled-back fixtures for owner/member/outsider access, theme independence, preservation across all three selections, 3,001 historical completions, duplicate scan requests and reward-specific notification text. UI checks exercise all themes on phone-sized screens, calendar filtering/retry/navigation, preview equipment, demo practice and restoring the original gemstone view.
