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

## Deferred / Open Items

- AI opponent tendency-reading / adaptiveness (explicitly deferred).
- Ultimate Team card/pack/rarity/chemistry system — next brainstorming
  pillar.
- Trick-play animation content pipeline (tied to future playbook
  collectibles).
