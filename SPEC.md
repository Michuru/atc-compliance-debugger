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
- **"Supersedes earlier X clearance... still in progress"**: this note means a previous instruction was still being carried out (aircraft correctly turning/climbing/slowing the right direction) when this new instruction interrupted it. That's not treated as a violation — ATC changed its mind before the pilot had a chance to finish.
- A badge with no target (e.g., "readback correct, contact ground 121.6") never shows a false readback warning — the tool knows the difference between an instruction with something to check and a plain acknowledgment.

### What each check means

- **Heading**: did the aircraft turn to and hold the assigned heading? Includes vector instructions with no explicit direction ("fly heading X") and point-triggered instructions ("leave FIX heading X" — doesn't have to happen instantly, only once the aircraft actually passes that fix).
- **Altitude**: did the aircraft climb/descend to and hold the assigned altitude? Understands "at pilot's discretion" (no response-time penalty), "maintain X until established" (continuing past X once on the localizer is correct, not a violation), "climb/descend via [procedure]" (can't independently verify the procedure's own altitude constraints, so this is marked "not independently verified" rather than guessed at), and point restrictions like "cross FIX at or above X" (only matters exactly at that fix).
- **Speed**: did the aircraft reduce/increase/hold the assigned speed ("reduce speed to 220 knots," "increase speed 240 knots," "maintain 250 knots")? Separately, two flat safety limits are always checked regardless of any ATC instruction: 250kt below 10,000ft, and a category-appropriate approach/landing speed ceiling (see "Aircraft category system" below). A speed restriction stays in effect until ATC issues a new one, explicitly cancels it ("resume normal speed"), or clears the aircraft to land.
- **Response timing**: did the pilot start complying within a reasonable time after the instruction, scaled to the size of the change (a 170° turn is allowed more time than a 10° nudge; a small, fast change is never penalized just because a fixed radio/recognition delay dominates a short time window)?
- **Readback**: did the pilot acknowledge instructions that actually assigned something to comply with? A frequency-change-only call with no clearance content never expects one.
- **Vertical speed**: two distinct checks — an enroute caution/violation ceiling (a secondary "something unusual happened" signal, not a hard regulatory limit — no such limit exists) and a separate, stricter final-approach sink-rate check tied to real stabilized-approach criteria.
- **Transponder**: flags a squawk left off after takeoff on an IFR departure (normal while parked; a genuine finding if it's still off several samples after liftoff).

### Aircraft category system

Not every aircraft should be held to the same speed/climb-rate numbers — a light single and a 747 fly approach at very different speeds. The tool maps each aircraft's ICAO type code (read from the log's SimBrief flight-plan URL) to an FAA approach category (A through E) and derives approach speed, landing speed, and climb/descent-rate expectations from that category. If the aircraft type isn't recognized, the tool falls back to generic flat defaults and shows an always-visible warning so you know the numbers might not be tuned for that aircraft.

### Known data limitations (not bugs in this tool)

- BeyondATC's own `[PlayerState]` telemetry logging is tied to radio transmissions, not a steady clock — once ATC stops talking, logging effectively stops too. This creates real gaps in exactly the areas compliance checks care about most, especially the final stretch before touchdown. When the tool can't verify something because there's no data, it says so explicitly rather than guessing.
- A log doesn't have to span gate-to-gate — BeyondATC recording can start mid-flight or end before the aircraft comes to a stop. The tool detects and flags this rather than silently misreporting a partial flight as a complete one.

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
| Speed limit below 10,000ft | 250kt | FAA regulatory limit |
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
| A | <91kt | C172, PA28, SR22, DA62, BE58, C208, PA24 |
| B | 91–121kt | P180, TBM, PC12, most light/midsize business jets, BE60, C750, STAR |
| C | 121–141kt | 737 family, A320 family, E-Jets, CRJ family |
| D | 141–166kt | 777, 787, 747-8, A330/A350, A380 |
| E | ≥166kt | (no current member — no aircraft in this table has a verified Vref this high) |

### Known parsing/behavioral edge cases worth knowing about

- **Speaker detection** relies on BeyondATC's consistent radio phraseology (ATC leads with the callsign; a pilot readback signs off *with* the callsign at the end), not the log's internal `sid` voice-slot id, which is not a reliable ATC/pilot marker. Player-initiated requests ("request IFR clearance," "request direct to fix," "ready for descent," etc.) break this pattern by leading with the callsign like ATC does - these are recognized separately by content, so they're correctly attributed to the pilot rather than misread as an ATC transmission.
- **Callsign detection** prefers the log's own `Player Callsign:` line whenever it appears literally in the transcript (required for tail-number-style callsigns like `N452DA`), falling back to frequency-guessing a spoken "Word ####" pattern only when no hint matches.
- **Multi-leg logs**: a single file can contain more than one flight back-to-back if BeyondATC wasn't restarted between them. The tool detects and separates these automatically.
- **"Climb/descend via [procedure]"** clearances are recognized but not independently verified against the named SID/STAR's own altitude constraints (that data isn't in the log) — reported as "not independently verified from available states" rather than guessed at.
- A transient overshoot that's immediately corrected during altitude capture is not reported as a hard "busted altitude" — only a deviation the aircraft never recovers from within the instruction's window is.
- Reaching an assigned heading, altitude, or speed once is not treated as the end of the check — the tool continues watching for drift back off target for as long as that instruction stays in effect, since BeyondATC will actively re-vector a player who has drifted, and this tool aims to show that the drift happened in the first place, not just judge whatever correction instruction comes next in isolation.

---

*This tool is maintained independently of BeyondATC and is not an official BeyondATC product. Questions, corrections, or bug reports against this tool itself are welcome via the repo's issue tracker.*
