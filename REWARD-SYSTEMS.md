# Household themes and rewards

A household has one theme selection under **Your household → Household settings**. The theme determines the visual style and reward presentation; there is no separate reward-system selector.

| Theme | Reward presentation | Status |
| --- | --- | --- |
| Wizard Adventure | Gemstone tubes for individuals or teams | Ready |
| Parents & Kids | One star per completed chore on a calendar | Ready |
| The Cat’s Meow | Cat companions; chore points for now | Growth and breeding coming later |
| Poker Chips | Chip artwork; chore points for now | Play money and weekly gambling coming later |

Poker is a future play-money experience. No real money, bets or gambling operations are implemented. The old Squeaky Clean selection migrates to Poker Chips. Legacy adventurer reward IDs remain readable in archived results.

## Individuals and teams

New households default to individual scoring and do not create teams. Teams can be enabled at creation (with four starter teams) or later in Household settings. Existing households retain team mode. In team mode admins manage team names, colours, emblems and membership. Turning teams off keeps memberships and assignments for later, while ignoring team assignment restrictions for chore scans; member eligibility still applies.

Gemstone tubes show individual members when teams are off and team totals when on. The calendar remains filterable by household member. Cat and poker previews show individual/team point totals without simulating future growth, breeding or betting.

## Points and weekly wins

Completions retain base points and configured quality/condition adjustments in every theme. Stars always count one per completion. Wizard, cat and poker weekly competitions use chore points; Parents & Kids uses completed chores. Each positive winning individual/team gets one weekly win point; ties award one to each winner. Empty weeks award none.

The dashboard leaderboard displays accumulated weekly win points for the active scoring mode. Hall of Fame retains each week’s mode, participants, reward rules and chore history. Rating edits and refutation removals correct archived awards. Community rankings share accumulated household/team weekly win points, with individual identities and scores kept private.

## Backend and validation

The server derives reward_scheme from theme and enforces it on writes, including older RPC entry points. New clients use create_household_experience and set_household_experience. All settings mutations remain admin-only. Auth, NFC scans, shared schedule limits, cooldowns, proof and notifications continue through the existing completion pipeline.

See supabase/household-experiences.sql and supabase/verify-household-experiences.sql for schema/RPC changes and rollback checks. Tests cover paired mappings, individual/team totals, administrator-only deletion, sticker reuse, weekly wins, archive corrections, privacy and phone-sized UI flows.
