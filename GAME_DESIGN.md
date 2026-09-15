# FootballIdea — Design Notes

## Concept

A Roblox football game that combines Ultimate-Team-style card collection with
real strategic play-calling — you build a roster through packs, then coach by
calling plays against an opponent, rather than directly controlling a player
on the field.

**Why this gap exists:** existing Roblox football games split into two camps
that don't overlap. "Build A Football Team" / "Build A Soccer Squad" are
passive card collectors with no play-calling. "Football Fusion" / "NFL
Universe Football" are direct-control action games with shallow team-building
and repeated NFL DMCA issues (Football Fusion has been taken down twice for
using real NFL branding). Nobody combines a deep card meta with actual
coaching strategy.

## Game Structure

- **Full games**: 5-minute quarters, standard down/clock/timeout rules.
- **Quick Drives**: a shorter mode (3-5 possessions per side) for faster,
  ranked-ladder-style matches.
- Both modes run on the same play-calling engine — only match length and win
  condition differ.

## Core Mechanic: Blind Simultaneous Play-Calling

- Each down, offense and defense pick a call **without seeing the opponent's
  pick** (Tecmo Bowl / classic Madden style).
- Both reveal at once. Outcome is resolved by: (1) the matchup between the
  two calls, (2) the relevant card stats on both sides, (3) weighted
  randomness within the resulting range.
- Results play out as pre-baked highlight animations picked from an outcome
  band (stuffed / short gain / explosive / turnover) — no live physics or
  direct control needed.
- **No QTE or reflex mechanics.** This is intentionally pure strategy — card
  stats and play-calling decide everything, keeping the Ultimate Team roster
  meaningful (a maxed-out roster should matter more than player reflexes).

## Matchup Matrix

4 offensive calls x 4 defensive calls. Each offense has one clear "great"
matchup and one clear "bad" matchup against defense; the rest are decided by
card stats.

| Offense ↓ / Defense → | Stack the Box | Blitz | Man Coverage | Zone Coverage |
|---|---|---|---|---|
| **Run** (inside/outside) | Stuffed (bad) | Gashed (good — rushers vacate run lanes) | Slightly favors offense (lighter box) | Stat-decided |
| **Quick Pass** (screen/slant/flat) | Favors offense (box reacts too slow) | Big play (good — ball's out before pressure) | Stat-decided (press technique vs. release) | Shut down (bad) |
| **Medium Pass** (out/curl/cross) | Favors offense (safeties down in the box) | Stat-decided (does the OL pick up the extra rusher?) | Shut down (bad — man travels with the route) | Stat-decided (find the soft zone or don't) |
| **Deep Pass** (play-action shot) | Big play (favors offense — nobody's deep) | Shut down (bad — no time to develop) | Stat-decided (classic WR speed vs. CB speed) | Shut down (bad — safety help is built for this) |

Relevant card stats: OL pass-block vs. DL/blitz rating, WR route-running vs.
CB coverage, QB accuracy vs. pressure, RB power/vision vs. front-seven run
rating.

## Formations & Named Plays

Formations sit underneath the matrix above — they unlock 2-3 named plays per
formation and shift the odds within a matchup, without changing the core
math.

**Offense**
- **I-Formation** — run-heavy (*Power*, *Dive*). Boosts Run everywhere, but
  no real pass plays — one-dimensional if read.
- **Singleback** — balanced default, one play per category, no
  bonus/penalty.
- **Shotgun** — pass-focused (*Slant*, *Curl-Flat*, *Four Verts*). More time
  to read boosts pass execution; weak Run Inside, exposed to Blitz on Deep
  calls.
- **Spread** — max explosiveness (*Bubble Screen*, *Go Routes*). Big upside
  vs. Blitz/Man, terrible vs. Stack the Box.
- **Goal Line / Jumbo** — situational (*Dive*, *QB Sneak*). Crushes
  Stack-the-Box near the end zone, nearly unusable for pass.

**Defense**
- **Base 4-3** — balanced default.
- **Goal Line D** — max Stack-the-Box, disastrous vs. pass — the natural
  head-to-head against offense's Goal Line package.
- **Nickel/Dime** — extra DBs, boosts Man/Zone (especially vs. Deep), weak
  vs. Run.
- **46/Overload** — boosts Blitz further (bigger risk/reward call).

**Ultimate Team tie-in:** gate specific plays behind personnel, not just
formation — *Four Verts* needs 4 WR cards above a speed threshold, *Goal
Line Dive* needs a blocking-TE/FB card, *Bubble Screen* wants a fast slot
receiver. Packs and roster-building expand the playbook directly, not just
raw stats.

## Playbooks as Collectibles (Future / Roadmap)

- A second collectible axis alongside player cards: **Coach Packs / Scheme
  Packs**.
- Rare/Legendary playbooks unlock **signature trick plays** (Flea Flicker,
  Wildcat, hook-and-ladder, fake punt/reverse) — high risk/reward calls that
  can break the matchup matrix in a specific, learnable way.
- Supports build diversity — two similar rosters can play very differently
  depending on which playbook is equipped.
- Flagged as content-heavy (needs its own animations and matrix exceptions)
  — a good post-launch update rather than a day-one feature.

## Down & Distance Modifiers

| Situation | Effect |
|---|---|
| **Short** (1-3 yds to go) | Run's baseline improves; Stack-the-Box's counter gets stronger — the power-football duel |
| **Medium** (4-7 yds) | Neutral — base matrix applies untouched |
| **Long** (8+ yds) | Quick Pass's floor rises; Blitz's swing gets bigger both ways (bigger win, bigger disaster vs. Quick Pass) |
| **Red Zone / Goal-to-Go** | Deep Pass loses most value (no room downfield); Man/Zone strengthen; Run-vs-Stack-the-Box duel intensifies — where Goal Line formations live |

## 4th Down Decision Layer

Before any blind call, offense picks one macro option:
- **Punt** — safe, flips field position, ends the drive.
- **Field Goal** — auto-resolved by kicker rating vs. distance (a percentage
  roll, not a play-call duel — keeps the "pure strategy" rule intact).
- **Go for it** — proceeds into the normal blind matchup; failure = turnover
  on downs. A natural hook for a future tendency/scouting system (does the
  opponent go for it more when trailing?).

## Clock & Timeouts

- 3 timeouts per half.
- Dual-purpose: stops the clock **and** extends the play-call timer (e.g.
  8-10 sec normal window → ~20 sec) — useful offensively (buy time to
  decide) and defensively (stop clock).
- Clock rules: completions/runs in bounds keep it running; incompletions,
  out-of-bounds, scores, and the two-minute warning stop it.
- **Hurry-up/no-huddle**: shrinks your own play-call timer further but locks
  the defense's formation from the previous play (they can't swap
  Base→Dime fast enough) — the built-in comeback mechanic.

## Turnovers

Live inside the RNG outcome bands rather than as a separate system — e.g. a
"disaster" result on Deep Pass vs. Blitz carries an interception chance, a
stuffed Run in short yardage carries a small fumble chance.

## Card Rarity & Packs

Four rarity tiers at launch (more may be added later as a live-service
expansion — e.g. a tier above Platinum down the line):

- **Bronze** — baseline stats, bulk of a starting roster.
- **Silver** — modest stat bump, fills out a functional team.
- **Gold** — real starters, meaningful stat jump.
- **Platinum** — top-of-the-ceiling stats, gated behind unlocking
  rare/personnel-specific plays (e.g. a Platinum speed WR being what gets a
  team to 4 fast WRs for *Four Verts*).

**Pack types:**
- **Standard packs** — Bronze/Silver-heavy, bought with soft currency earned
  from playing (wins weighted more than losses, plus daily/weekly quests).
- **Position packs** — guarantees a card from a chosen position group,
  letting players target a specific roster gap (e.g. buying a WR pack
  specifically to unlock a play that needs one).
- **Premium packs** — Robux-purchased, better odds at Gold/Platinum.
- **Event packs** — rotating weekly/seasonal, sometimes with time-limited
  exclusive Platinum cards.
- **Coach/Scheme packs** — separate pool for the future playbook-collectible
  layer, so the card grind and playbook grind don't compete for the same
  currency.

**Duplicate handling:** dupes convert to upgrade fuel that levels up that
specific card's stats within its rarity band, and enough dupes at one
rarity auto-craft one card at the next rarity up.

**Pity system:** guaranteed Gold+ every N packs. Odds should be disclosed
in-game from day one — Roblox's marketplace policy already requires
disclosing odds on randomized item purchases.

**Open questions:**
- Currency structure — one soft currency + Robux-for-premium-packs, or a
  middle "premium soft currency" layer (earnable slowly for free, but
  mainly bought)?
- Trading — player-to-player card trading (real economy, harder to keep
  fair/scam-free) vs. account-locked cards?

## Chemistry

Eight named bonds, mirroring the matchup matrix (4 offense, 4 defense), so
building chemistry means choosing a playstyle identity rather than a
generic stat bump.

*Offense*
- **Power Unit** (OL + RB, + TE blocker) → boosts Run
- **Quick Strike** (QB + slot WR/RB) → boosts Quick Pass
- **Route Tree** (QB + WR + TE) → boosts Medium Pass
- **Deep Threat** (QB + speed WR) → boosts Deep Pass

*Defense*
- **Run Stoppers** (DL + LB) → boosts Stack the Box
- **Blitz Package** (LB + DL pass-rushers) → boosts Blitz
- **Lockdown Corners** (CB + S, man specialists) → boosts Man Coverage
- **Shutdown Zone** (S + LB + CB zone specialists) → boosts Zone Coverage

A team that stacks Power Unit + Run Stoppers plays like a ground-and-pound
team; one that stacks Deep Threat + Shutdown Zone plays like an air-raid /
bend-don't-break team. The bonds push a roster toward a coherent identity
instead of just raising numbers.

**Activation:** checks the active roster pool, not physical adjacency in a
formation grid (no FIFA-style link web needed). Chemistry is **scaled, not
binary** — the more qualifying cards (and the higher their rarity) a bond
has, the bigger its outcome boost. A team with 2 of the 3 Route Tree pieces
still plays a little better at Medium Pass than a team with none; a full,
high-rarity set plays a lot better.

Chemistry is purely an **outcome modifier** on the stat-decided matrix
rolls — it doesn't gate play availability, since that's already handled by
the personnel-gated plays system. Keeps the two mechanics from overlapping.

**Deferred:** Team/Set bonus (amplified chemistry when linked cards share a
fictional team tag) — needs multiple fictional team rosters designed up
front, so it's a later addition once functional chemistry is proven out.

## Roster Construction

**No salary cap.** A stronger (higher-spend) roster is intended to play
better — pay-to-win is an accepted, intentional part of the monetization
model, not something to balance away with a budget system.

Implication for later: since roster power can vary a lot between players,
**matchmaking/tiering** (grouping by roster strength, or a separate ranked
ladder) becomes important so free/new players still find winnable matches
— otherwise retention suffers before anyone spends. Filed under the
social/matchmaking layer, not solved yet.

## Progression: AI-First Onboarding

New players start entirely against AI, not other players.

- **Season Mode** (AI) — a permanent single-player mode, not just a
  tutorial funnel. Players build a roster via earned packs/currency and
  play through CPU-controlled teams of increasing strength.
- **PvP unlock gate** — win a set number of games vs. CPU. Simple,
  understandable requirement rather than a level/XP curve.
- Season Mode stays around as permanent content after PvP unlocks (a
  career/franchise-style mode alongside ranked PvP), not something players
  age out of.
- Softens the no-cap/pay-to-win risk flagged earlier: players earn a real
  roster and learn the play-calling system before ever facing a
  human/whale opponent in PvP.
- Reconnects to the deferred AI-adaptiveness item — Season Mode's CPU
  difficulty ladder can start as stat-only (bigger/better AI rosters) and
  later add smarter tendencies once that system is built.

## PvP Structure

- **Ranked ladder runs on Quick Drives** (not full games) — short matches
  keep queue times low and the format replayable, closer to a ranked
  card-game match than a full sim.
- **League Play** uses Full Games (5-min quarters) — private lobbies,
  friends, tournaments, scheduled league-style PvP. Same engine, different
  container.
- **Power-aware matchmaking** — blends skill rating with rough roster power
  so brackets stay competitive despite no roster cap. Spending still lets
  a player climb by fielding stronger tools, but matches stay within a
  bracket rather than pitting new accounts against whales.
- **Placement matches** immediately after the PvP unlock gate, to seed
  initial rank.
- **Seasonal resets** synced to Season Mode's cadence, with rank rewards
  (packs, cosmetics) at season end, feeding back into the pack economy.
- Global + friends leaderboards, and spectating for live matches.

## Season Mode Schedule

Matches the real NFL format structurally: **17 games + 1 bye week**, into
a playoff bracket (Wild Card → Divisional → Championship → Finale) against
CPU teams of rising difficulty. The schedule *format* (game count, bye
week, bracket) isn't NFL-protected IP — but per the earlier IP-safety
note, the teams themselves stay fictional, not real NFL teams/branding.

## Currency & Trading

**Two-tier currency:**
- **Coach Coins** (soft currency) — earned via Season Mode and PvP wins,
  dailies/weeklies. Buys Standard/Position packs.
- **Premium currency** (Robux-purchased, sold in bundles) — buys
  Premium/Event packs and cosmetics. Standard live-service pattern: lets
  packs be priced at awkward numbers and currency sold in bundles that
  nudge slight overspend.

**No player trading**, at launch or planned — not just deferred. Reasons:
hard to keep scam-free, undercuts the pack economy the game is
monetized around (players could trade for needs instead of
pulling/buying), and Roblox's platform trading rules are restrictive
outside their built-in limited-items system. The existing duplicate-fusion
system (dupes → upgrade fuel / auto-craft, see Card Rarity & Packs)
already covers the "bad luck protection" itch trading usually solves.

## Deferred / Open Items

- AI opponent tendency-reading / adaptiveness (explicitly deferred).
- Team/Set chemistry bonus (needs fictional team rosters built first).
- Trick-play animation content pipeline (tied to future playbook
  collectibles).
