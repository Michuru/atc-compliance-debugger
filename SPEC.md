# BeyondATC Compliance Debugger — Functional Spec

This tool reads a BeyondATC `Player.log` and checks, instruction by instruction, whether the pilot actually did what ATC told them to do. It exists so that when something in a BeyondATC session looks wrong (ATC loses track of the aircraft, stops vectoring for a descent, etc.), the pilot can rule themselves out as the cause before filing a bug report. If this tool shows the player correctly following every instruction and BeyondATC's own ATC still misbehaved, that's evidence the bug is in BeyondATC, not the player.

It runs entirely in a web browser, client-side — nothing in your log is ever uploaded anywhere. You can read the source directly; there's no build step, no server, no dependencies beyond what's already loaded on the page.

---

## Part 1 — For BeyondATC developers and testers

### What it does

1. You open `atc-compliance-debugger.html` in a browser and load a `Player.log` file (drag-and-drop or file picker).
2. The tool finds every radio exchange between ATC and the player aircraft, and pairs each ATC instruction with the pilot's readback (if any) and the aircraft's actual flown telemetry afterward.
3. For each instruction, it checks whether the aircraft's actual altitude, heading, and speed matched what was assigned — not just once, but for as long as that instruction stayed in effect (i.e., it also catches a pilot who complies briefly and then drifts back off).
4. Each instruction gets a compliant / caution / violation badge (✓ / ⚠ / ✕), with a plain-English explanation of what was assigned versus what actually happened.

### How to read a report

- **Green (✓ / ok)**: the aircraft did what was assigned, within a reasonable tolerance and a reasonable amount of time.
- **Yellow (⚠ / warn)**: a minor deviation, a slow response, or an instruction that was superseded by a later one before it could be fully judged.
- **Red (✕ / bad)**: a clear compliance failure — the aircraft never reached the assigned target, busted through it, or drifted well off it after initially complying.
- **"...still turning/ascending/descending/speeding up/slowing... new instructions given before arriving"** (shown on the original instruction) together with **"New instructions given before the aircraft reached the earlier ALT/HDG/SPD X clearance"** (shown on the one that interrupted it): these two notes describe the same event from each instruction's own side. A previous instruction was still being carried out correctly (aircraft moving the right direction, confirmed from actual telemetry) when a new instruction cut it off. That's not treated as a violation — ATC changed its mind before the pilot had a chance to finish.
- A badge with no target (e.g., "readback correct, contact ground 121.6") never shows a false readback warning — the tool knows the difference between an instruction with something to check and a plain acknowledgment.
- Expanding an instruction's detail view shows a small assigned-vs-actual diagram — a compass for heading, a linear bar for altitude/speed — whenever there's a real gap worth visualizing: a missed target, or one still correctly in progress when a later instruction took over ("new instructions given before arriving"). A fully compliant "reached it" result has nothing to compare, so it doesn't get one.
- **"Player announced going around"** is an informational entry, not a compliance badge — a go-around is the pilot's own unilateral safety decision, with no ATC-issued target to check it against, so it's shown purely so the moment is visible in the timeline (it previously wasn't shown at all) rather than as a pass/fail judgment.
- The pilot's readback (or its absence) is shown inline on the card itself, with its own timestamp, so it no longer takes expanding the card to see what the pilot actually said or when — and a "Readback delayed" finding states both the instruction time and the readback time directly, so either can be checked against the raw log's clock without doing the subtraction by hand.
- Every pilot line — readback or self-report — is labeled **Pilot (human)** or **Co-Pilot (AI)**. BeyondATC logs real push-to-talk speech through a separate speech-to-text pipeline (`[Speech Transcription]`) from its own synthesized/text-based readbacks and canned button-triggered reports (`[LocalVoiceInput]`/`[Instruction]`, including `[PlayerAction]`); the tool surfaces which pipeline produced each line instead of showing a bare "Pilot" for both.
- A **procedures line** beneath the flight's route header, when known, shows what was originally *filed* — "Planned SID/STAR: X, rwy Y" (or "no SID/STAR filed" for a flight plan with none), sourced from the log's own SimBrief-plan header fields, not the `#hRoute` line above it — right alongside what was actually *assigned*: the departure SID name and runway (or "radar vectors to FIX, then as filed" when BeyondATC's engine computed a SID internally but the voiced clearance never named it, or "no SID/STAR computed (vectored)" when the engine itself never found one), the arrival STAR name and runway, and the runway ATC actually cleared for the approach or landing. If the cleared runway differs from the STAR's own runway, it's labeled "(reassigned from rwy X)" — a real mid-flight runway change, not a parsing inconsistency. Putting the planned and actual sides side by side is deliberate: a real divergence (a different SID/STAR name, or a different runway) is visible just from the two segments disagreeing, with no separate "(differs from planned)" annotation needed. Each piece shows only if it's actually known, and the whole line is hidden if none of it could be determined.

### What each check means

- **Heading**: did the aircraft turn to and hold the assigned heading? Includes vector instructions with no explicit direction ("fly heading X") and point-triggered instructions ("leave FIX heading X" — doesn't have to happen instantly, only once the aircraft actually passes that fix). A vector heading assigned in the same instruction as an approach clearance (e.g., "turn right, heading 230, ... cleared ILS approach runway 26L") is understood to be a means to intercept the final approach course — continuing to turn past it once established on the final course, within a generous bound, is the expected outcome, not a deviation.
- **Altitude**: did the aircraft climb/descend to and hold the assigned altitude? Understands "at pilot's discretion" (no response-time penalty), "maintain X until established" (continuing past X once on the localizer is correct, not a violation), "climb/descend via [procedure]" (can't independently verify the procedure's own altitude constraints, so this is marked "not independently verified" rather than guessed at), point restrictions like "cross FIX at or above X" (only matters exactly at that fix), and "maintain VFR at or below/above X" (a Class B/C transition-altitude ceiling or floor — any altitude on the correct side of the number counts as compliant for as long as the restriction is in effect, not a specific target to converge on).
- **Speed**: did the aircraft reduce/increase/hold the assigned speed ("reduce speed to 220 knots," "increase speed 240 knots," "maintain 250 knots")? Also recognizes "minimum approach speed" — real Pilot/Controller Glossary phraseology with no explicit knot value in the instruction itself. Since ATC didn't state a number, the target is resolved from the aircraft's own category-derived approach-speed limit (see "Aircraft category system" below) and every result referencing it is labeled `"Xkt minimum approach speed"` rather than a bare `"Xkt"`, so it's never mistaken for a number ATC actually spoke. Separately, flat safety limits are checked regardless of any specific ATC speed instruction: 250kt below 10,000ft always applies, a category-appropriate approach/landing speed ceiling applies near the runway (see "Aircraft category system" below), and — specifically for the duration of a "remain clear of the Bravo/Class B airspace" instruction — 200kt applies, per 14 CFR §91.117(c). That narrower 200kt cap only fires for a "remain clear of" instruction (staying underneath the Class B shelf); it does not apply when the aircraft has instead been cleared into or through the Class B itself, which is a different real-world situation with no such limit. A speed restriction stays in effect until ATC issues a new one, explicitly cancels it ("resume normal speed"), or clears the aircraft to land.
- **Response timing**: did the pilot start complying within a reasonable time after the instruction, scaled to the size of the change (a 170° turn is allowed more time than a 10° nudge; a small, fast change is never penalized just because a fixed radio/recognition delay dominates a short time window)?
- **Readback**: did the pilot acknowledge instructions that actually assigned something to comply with? A frequency-change-only call with no clearance content never expects one.
- **Vertical speed**: two distinct checks — an enroute caution/violation ceiling (a secondary "something unusual happened" signal, not a hard regulatory limit — no such limit exists) and a separate, stricter final-approach sink-rate check tied to real stabilized-approach criteria.
- **Transponder**: flags a squawk left off after takeoff on an IFR departure (normal while parked; a genuine finding if it's still off several samples after liftoff).

### Aircraft category system

Not every aircraft should be held to the same speed/climb-rate numbers — a light single and a 747 fly approach at very different speeds. The tool maps each aircraft's ICAO type code (read from the log's own `Aircraft Type:` line, with a SimBrief flight-plan URL as a secondary source when present) to an FAA approach category (A through E) and derives approach speed, landing speed, and climb/descent-rate expectations from that category. If the aircraft type isn't recognized, the tool falls back to generic flat defaults and shows an always-visible warning so you know the numbers might not be tuned for that aircraft.

### Known data limitations (not bugs in this tool)

- BeyondATC's own `[PlayerState]` telemetry logging is tied to radio transmissions, not a steady clock — once ATC stops talking, logging effectively stops too. This creates real gaps in exactly the areas compliance checks care about most, especially the final stretch before touchdown. When the tool can't verify something because there's no data, it says so explicitly rather than guessing.
- A log doesn't have to span gate-to-gate — BeyondATC recording can start mid-flight or end before the aircraft comes to a stop. The tool detects and flags this rather than silently misreporting a partial flight as a complete one. If a log or leg ends (e.g. a BeyondATC crash) too soon after an instruction for the pilot to plausibly have had time to comply, the tool reports "not enough data to judge compliance" rather than guessing at a violation.
- The tool has no airspace-geometry database (no Class B/C/D boundaries, shelves, or corridors). It can confirm the pilot complied with whatever numeric restriction ATC actually assigned in the clearance (e.g., a "maintain VFR at or below X" ceiling, or the 200kt "remain clear of the Bravo" speed cap described above), but it cannot independently verify whether an airspace clearance or entry was geometrically correct, or catch an aircraft entering controlled airspace without required contact — that's outside what log/telemetry data alone can answer.

---

## Part 2 — Technical appendix

### Architecture

```
parseLog()  →  guessCallsign() / refineSpeakersByCallsign()
            →  classify() / parse*Clearance()   (per-instruction parsing)
            →  buildExchanges()                  (pairs instructions with readback + flown telemetry windows)
            →  evaluateExchange()                (the actual compliance judgment, per instruction)
            →  recompute()                        (second pass: carries "still in progress" notes onto the superseding instruction)
```

Everything runs client-side in a single `.html` file — no build step, no server, no external dependency beyond what's already inlined.

### Compliance thresholds (defaults, user-adjustable at runtime via the Thresholds panel)

| Threshold | Default | Source |
|---|---|---|
| Heading tolerance | 5° | Judgment call |
| Altitude tolerance | 150ft | Judgment call |
| Speed tolerance | 10kt | Judgment call, consistent with observed real compliant-hold oscillation |
| Speed limit below 10,000ft | 250kt | FAA regulatory limit (14 CFR §91.117(a), per FAA JO 7110.65BB Para 5-7-2 NOTE 1) |
| Speed limit beneath Class B / in a VFR corridor | 200kt (only while a "remain clear of the Bravo" instruction is in effect) | FAA regulatory limit (14 CFR §91.117(c), per FAA JO 7110.65BB Para 5-7-2.b) |
| Approach speed target | Category-derived (90–180kt by category A–E) | FAA Pilot/Controller Glossary approach categories (1.3× stall speed at max landing weight) |
| Landing-clearance speed target | Category-derived | Same as above |
| Min. expected climb/descent rate | 500fpm (flat, all categories) | FAA AIM ¶4-4-10(d) |
| Vertical speed caution / violation (enroute) | Category-derived (1,500–9,000fpm by category) | No authoritative ceiling exists (confirmed against FAA AIM ¶4-4-10(d) and ICAO Doc 4444 §4.7) — informed judgment call grounded in real published aircraft performance data |
| Stabilized-approach sink-rate limit | 1,000fpm (flat, all categories) | FAA's 1995 stabilized-approach bulletin; FSF ALAR Briefing Note 7-1 |
| "On approach" altitude threshold | 1,000ft AGL | FAA-hosted Airbus Flight Ops Briefing Note, "Flying Stabilized Approaches" |
| Slow-response threshold | 3 minutes (base allowance, scaled up for larger changes) | Judgment call |
| Expected speed-change rate | 20kt/min (used only to scale the response-timing allowance) | Judgment call, consistent with real observed compliant speed changes |

### Aircraft approach categories (FAA Pilot/Controller Glossary)

| Category | Approach speed band | Example types in this tool |
|---|---|---|
| A | <91kt | C172, PA28, SR22, DA62, BE58, C208, PA24, DHC6 (Twin Otter), DHC2 (Beaver), AC11 (Commander 114), M600 (Piper M600) |
| B | 91–121kt | P180, TBM, PC12, most light/midsize business jets, BE60, B58T (Baron 58P/58TC), C750, STAR, ATR72, DH8D (Dash 8 Q400), DC6 |
| C | 121–141kt | 737 family, A320 family, E-Jets, CRJ family, 727 family, A310, 767-200/-200ER, 777-200/-200LR |
| D | 141–166kt | 767-300ER, 777-300/-300ER, 787, 747-8, A330/A350, A380 |
| E | ≥166kt | (no current member — no aircraft in this table has a verified Vref this high) |

### Known parsing/behavioral edge cases worth knowing about

- **Speaker detection** relies on BeyondATC's consistent radio phraseology (ATC leads with the callsign; a pilot readback signs off *with* the callsign at the end), not the log's internal `sid` voice-slot id, which is not a reliable ATC/pilot marker. Several real pilot-speech patterns break that lead/trail assumption and are recognized separately, by content, so they're correctly attributed to the pilot rather than misread as an ATC transmission: player-initiated requests ("request IFR clearance," "request direct to fix," "ready for descent," etc.); a player's own go-around report ("going around"); real-world initial-contact/position reports that name the facility being called before the aircraft's own callsign ("Gdansk Departure, Wizzair 37KJ, good evening, passing 2,200 climbing to FL110") or that report a position with no greeting at all ("Sweden Control, Wizzair 37KJ, passing FL276 climbing to FL380..."); an arrival check-in with an aircraft-type or position clause between the facility/callsign and the content ("Scottsdale Tower, N39NG, Piper M600, inbound for landing, with information Q."); crew acknowledgments that open with "We'll…"/"Wilco…"/"Roger, we'll…" instead of trailing with the callsign; and CTAF self-announce broadcasts at untowered fields ("<Airport> traffic, <callsign>, <position/intent>, <Airport>"). The player's own real voice transmissions (a separate transcription pipeline in the log) are always attributed to the pilot regardless of phrasing, including a bare voice line that happens to open with the callsign the way an ATC instruction normally would. A narrow exclusion prevents the reverse mistake: genuine ATC lines that also happen to contain the word "request" (e.g. "proceed through the Class Delta as requested," "say request," "please make a taxi request," "altitude change request cancelled") are correctly kept as ATC speech rather than misread as a pilot request.
- **Callsign detection** prefers the log's own `Player Callsign:` line whenever it appears literally in the transcript (required for tail-number-style callsigns like `N452DA`), falling back to frequency-guessing a spoken "Word ####" pattern (matching both Title-case "Speedbird 1" and ALL-CAPS "LEIPZIGAIR 324", and an airline name followed by a literal "Flight" before the number, e.g. "Frontier Flight 4204") only when no hint matches.
- **Runway/SID/STAR correlation** (the procedures line described above) relies on a heuristic, not a guarantee. BeyondATC logs a `[Procedures] SID/STAR is ... using runway X` line for every aircraft it's tracking — player and background AI traffic alike — with no callsign on the line itself. Attribution to the player requires a nearby raw line (within a couple of lines either side) carrying a callsign/aircraft token matching one of the log's own literal `Player Callsign:` values — deliberately the *raw* ICAO-style form (e.g. `LHA324`), not the resolved display-form callsign shown elsewhere in the header (e.g. `LEIPZIGAIR 324`), since BeyondATC's own internal engine lines only ever use the former. Not every nearby callsign token is equally trustworthy: a line that names the aircraft directly for this exact computation (e.g. `[VectorGen] callsign=LHA324|...`) is preferred over one that's merely positional (e.g. `[RunwayAlloc] LHA324 ...`, which can — rarely, in a busy log — coincidentally sit near a *different* aircraft's own procedure line with nothing stronger nearby to prefer instead); the tool always prefers the more specific match when both exist. A mid-flight runway reassignment (e.g. weather-driven) is tracked via BeyondATC's own `[Arrival Runway Update]` log line. A leg with a handful of candidates and no nearby callsign token anywhere (nothing else in the file they could belong to) falls back to assuming they're the player's; a busy multi-aircraft log with many unmatched candidates shows nothing for that piece rather than guessing whose procedure it was.
- **Multi-leg logs**: a single file can contain more than one flight back-to-back if BeyondATC wasn't restarted between them. The tool detects and separates these automatically.
- **"Climb/descend via [procedure]"** clearances are recognized but not independently verified against the named SID/STAR's own altitude constraints (that data isn't in the log) — reported as "not independently verified from available states" rather than guessed at.
- **Approach clearances are recognized in two phraseology families**, not just the ones that say the word "approach": the common "cleared [the] X approach [runway Y]" form, and a fallback for real ATC phrasing that skips that word entirely — "cleared R-NAV-Z 34L," "cleared R-NAV 35," and similarly for ILS/visual/VOR/LOC/LDA/GPS/NDB. Recognizing this second family matters beyond just the procedures-line display: an approach clearance also supersedes any still-open heading/altitude vector, so missing one could previously leave an earlier clearance's compliance window open longer than it should have been.
- A transient overshoot that's immediately corrected during altitude capture is not reported as a hard "busted altitude" — only a deviation the aircraft never recovers from within the instruction's window is.
- Reaching an assigned heading, altitude, or speed once is not treated as the end of the check — the tool continues watching for drift back off target for as long as that instruction stays in effect, since BeyondATC will actively re-vector a player who has drifted, and this tool aims to show that the drift happened in the first place, not just judge whatever correction instruction comes next in isolation.

---

*This tool is maintained independently of BeyondATC and is not an official BeyondATC product. Questions, corrections, or bug reports against this tool itself are welcome via the repo's issue tracker.*
