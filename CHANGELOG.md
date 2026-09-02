# Changelog

All notable changes to this tool are recorded here, newest first. Format loosely follows [Keep a Changelog](https://keepachangelog.com/); versioning follows the guide in this repo's `publish-debugger` skill (patch = bug fixes only, minor = new check/feature, major = not expected for a tool like this).

This file is the source of truth for "what's actually been released" - update it in the same push as any new git tag, rather than relying on the working repo's `BACKLOG.md` (a separate, internal working log that isn't guaranteed to stay in sync with real tag history - see the 2026-08-17 entry below for exactly why that matters).

## [1.7.0] - 2026-09-02

### Added
- The full SimBrief-planned route is now shown as visible text directly beneath the Planned SID/STAR line, instead of only being accessible through the existing "Copy Route" button. Requested via #1.

## [1.6.1] - 2026-08-31

### Fixed
- Callsign detection: the frequency-guess fallback could only capture one leading word before the number, so a plain two-word spoken airline name with no "Flight" token (e.g. "Air Canada 831") lost its first word, same failure shape as the "Frontier Flight 4204" case fixed in 1.5.1. Once that happened, speaker detection for that flight silently degraded partway through - most of the flight still classified correctly through an unrelated fallback, but once that stopped covering for it (in the reported case, partway through the descent), every later ATC instruction fell through to "unknown speaker" and vanished from the report with no error shown. A user-supplied real log looked like the debugger had stopped mid-flight - it was actually a live, complete recording all the way to the gate; only the report was cut short. Fixed by allowing an optional second leading word in the callsign-guess pattern.
- The 250kt-below-10,000ft, 200kt-Class-B, and stabilized-approach sink-rate checks had no tolerance at all - even a 1kt or 1fpm overage graded as a full violation, identical to a genuine, meaningful bust. All three now allow a small tolerance band (see the thresholds table in `SPEC.md`) before escalating from caution to violation, matching how every other numeric check in this tool already works.
- A dormant bug in the callsign-guess fallback's own aviation-jargon exclusion filter (skipping words like "ILS"/"QNH" so they never get mistaken for a callsign) - the two-word-name fix above could, in principle, push one of those excluded words past the position the filter checked, silently defeating it. Never observed causing a wrong guess in any real log, but fixed defensively rather than left as a latent risk.

### Added
- No new checks - a permanent regression-test fixture was added for the original "Frontier Flight 4204" case (`Player (11).log`, no user-visible change), closing a gap where that precedent had no automatic protection against a future regression.

## [1.6.0] - 2026-08-30

### Added
- A new check: ATC's "report the field in sight" request now expects a timely pilot reply ("field in sight," "we have the field"), graded through the same readback/response-timing machinery as every other instruction - previously invisible to the tool entirely, silently reading as "nothing to check" rather than a real compliance question.

### Fixed
- A speed instruction superseded by a later one (a new number, a landing clearance, or an outright cancellation like "resume normal speed") no longer gets automatically softened to a yellow warning if the aircraft was actually moving *away* from the original target when the window closed. Only a genuinely-still-progressing instruction gets the softer treatment now; a real reported case had speed dropping the wrong direction for three minutes before ATC moved on, and the tool previously showed that as a minor warning rather than the compliance failure it was.

### Known limitation, documented not fixed
- The readback-pairing mechanism (shared by every instruction that expects an acknowledgment, including the new field-in-sight check above) matches on timing, not content - it pairs whatever the pilot says next within the response window, without verifying that reply actually addresses the specific instruction. Not observed causing a false pass in any log checked so far, but noted here as a known trade-off rather than a guarantee.

## [1.5.1] - 2026-08-25

### Fixed
- Callsign detection: the frequency-guess fallback regex could only capture one leading word before the number, so an airline callsign spoken as "\<Airline\> Flight ####" (e.g. "Frontier Flight 4204") lost the airline name and guessed just "Flight 4204." Every ATC line then failed to match against the wrong guess and stayed misclassified as unknown speaker, so the tool produced zero exchanges for the entire flight - not a partial miss, no data at all. Fixed by allowing an optional "Flight" token in the fallback pattern.

## [1.5.0] - 2026-08-23

### Added
- A procedures line beneath the flight's route header shows the SID/STAR/runway actually assigned to the player - previously buried in exchange-by-exchange detail - flagging a genuine mid-flight runway reassignment ("(reassigned from rwy X)").
- The same line also shows what was originally *filed* (from the log's own SimBrief-plan header fields) side by side with what was actually assigned, so a real divergence - a different SID/STAR name, a changed runway, or vectors used instead of a charted procedure - is visible at a glance. Motivated by player reports of runways/procedures changing mid-flight that needed direct verification against the debugger.

### Fixed
- Approach-clearance recognition was limited to phraseology containing the word "approach" ("cleared ILS approach runway 07"), missing a real clearance family that omits it entirely ("cleared R-NAV-Z 34L", "cleared R-NAV 35"). This wasn't just a display gap - an approach clearance also supersedes any still-open heading/altitude vector, so missing one could leave an earlier clearance's compliance window open longer than it should have been.
- Procedure-candidate correlation (used by the procedures line above) could, rarely in a busy multi-aircraft log, misattribute a background aircraft's SID/STAR computation to the player when only a positional tag (not one naming the aircraft directly for that computation) was nearby. The correlation now prefers a tag that names the aircraft directly whenever one exists, falling back to a positional-only match only when nothing more specific is available. Also adds recognition of BeyondATC's own runway-reassignment log line, closing a related gap where a real weather-driven runway change had no correlation tag at all nearby and rendered the stale pre-change runway.

## [1.4.1] - 2026-08-22

### Fixed
- Callsign detection: the frequency-guess fallback regex only matched Title-case callsigns ("Speedbird 1"), so an ALL-CAPS callsign ("LEIPZIGAIR 324") lost to an unrelated taxi holding point mentioned elsewhere in the log, silently dropping a real ATC heading-vector instruction from the exchange list entirely.
- Heading: a vector heading assigned in the same instruction as an approach clearance (e.g. "turn right, heading 230, ..., cleared ILS approach runway 26L") had no equivalent to altitude's "maintain X until established" carve-out, so a textbook-correct ILS intercept graded as a hard violation once the aircraft continued turning past the vector heading onto the actual final approach course. Bounded to a generous tolerance, not a blanket skip, so a genuine large mismatch (e.g. a re-vector after flying through the final course) still gets flagged.

## [1.4.0] - 2026-08-22

### Added
- Every pilot line - readback or self-report - is now labeled **Pilot (human)** or **Co-Pilot (AI)**, distinguishing BeyondATC's real push-to-talk speech-to-text pipeline from its own synthesized/text-based readbacks and canned button-triggered reports. Both were already tracked internally; neither was ever surfaced before now.

### Fixed
- The pilot's readback (or its absence) required expanding an instruction's card to see at all - including its own timestamp, needed to visually compare against the instruction time for a "Readback delayed" finding. Now shown inline on the card itself; only the raw voice line, diagrams, and state grid still require expanding.

## [1.3.1] - 2026-08-22

### Fixed
- Go-around reports (e.g. "American 1883, going around.") were correctly speaker-tagged as pilot speech but never rendered as a timeline entry at all - silently dropped, leaving no visible reason why the vectors right after it looked like a second approach attempt. Now shown as an informational entry ("Player announced going around") with no compliance judgment attached - a go-around is the pilot's own unilateral safety decision, with no ATC-issued target to check it against.
- "Readback delayed ~Xm" gave no way to check the finding against the raw log's own clock without doing the subtraction by hand. The label now also states the instruction and readback HH:MM times directly, and the readback line in each instruction's detail view now shows its own timestamp.
- A fourth real "request" false positive: BeyondATC's own canned confirmation ("...roger, altitude change request cancelled.") was misread as a pilot-initiated request and misclassified as pilot speech - same underlying pattern as the three exclusions already fixed in v1.1.0/v1.2.0.

## [1.3.0] - 2026-08-19

### Added
- Assigned-vs-actual mini diagrams in each instruction's detail view - a compass for heading, a new linear bar for altitude/speed - now shown for a clearance still correctly in progress when a later instruction took over ("new instructions given before arriving"), not just a genuine final miss. Previously only heading's final-miss case had this visual at all; altitude and speed had none.

### Fixed
- Piper M600 was missing from the aircraft-category table entirely, silently falling back to flat, untuned thresholds. Added using real POH data (Vref 85kt / Vso 62kt → Category A).
- Speaker detection: two more real player-voice patterns were misread as ATC speech. A real player voice-transcription line could be misattributed back to ATC if it happened to open with the callsign (no comma) the way a real ATC instruction does. An arrival check-in on a new frequency with an aircraft-type clause between the facility/callsign and the content ("Scottsdale Tower, N39NG, Piper M600, inbound for landing, with information Q.") matched neither existing check-in pattern. Both had been producing phantom no-content "ATC instruction" cards in the exchange list, obscuring the pilot's own actual radio calls.

## [1.2.1] - 2026-08-18

### Fixed
- "Minimum approach speed" - real ATC phraseology with no explicit knot value - previously matched nothing at all and produced zero compliance results for the exchange, not just a wrong verdict. Now recognized and resolved against the aircraft's own category-derived approach-speed limit, labeled `"Xkt minimum approach speed"` so it's never mistaken for a number ATC actually spoke.

## [1.2.0] - 2026-08-18

### Added
- 200kt speed limit check while a "remain clear of the Bravo/Class B" instruction is in effect (14 CFR 91.117(c)). Scoped specifically to that phrasing - does not apply when the aircraft is instead cleared into or through the Class B itself, a different real-world situation with no such cap.
- Quick-access SimBrief link and a "Copy Route" button (for pasting into Navigraph Charts or similar) whenever a loaded log has SimBrief flight-plan data.

### Fixed
- Heading-compliance windows now close on a landing clearance, matching how altitude and speed windows already worked. Previously an open heading window could run through touchdown and taxi, grading the original instruction against whatever direction the aircraft happened to be facing while parking. Corrected 12 exchanges across 11 sample logs.
- Speaker detection: initial radio check-ins that lead with the facility name instead of the aircraft's own callsign, pilot acknowledgments opening with "We'll…/Wilco…/Roger, we'll…", and CTAF self-announce broadcasts at untowered fields were misread as ATC speech instead of pilot speech. 86+ corrected instances across the sample log library.

### Process
- Added this file. The previous process relied on `BACKLOG.md` (in the separate working repo) to track "has this been tagged yet" - that note went stale after `v1.1.0` was tagged and was never corrected, which nearly caused a duplicate/colliding `v1.1.0` release to be drafted for unrelated work. This file exists so version history has one place that can't drift out of sync with the actual GitHub tags.

## [1.1.0] - 2026-08-12

### Added
- "Maintain VFR at or below/above X" check (Class B/C transition-altitude ceiling or floor) - previously fell through unrecognized and got zero compliance evaluation.

### Fixed
- Aircraft-type detection now reads the log's own `Aircraft Type:` line directly, instead of only the SimBrief flight-plan URL - fixes category detection silently failing for every non-SimBrief (MSFS-loaded) flight.
- Aircraft-category table: added AC11, DHC6, DHC2, B58T, ATR72, DH8D, DC6, B721/B722, A310, and the 737 Classic family; corrected B762/B772/B77L (767-200/-200ER, 777-200/-200LR) from a wrongly-assigned Category D to their real Category C - a real compliance-verdict change, not just table coverage.
- Speaker detection: genuine ATC lines containing "request" ("...as requested," "say request," "please make a taxi request") were misread as pilot speech and silently dropped from the exchange list; a player's own "going around" report is now recognized as pilot speech.
- Altitude bust check no longer flags a clearance as "busted" when it was immediately superseded by a further clearance in the same direction.
- A clearance issued too close to the end of a log/leg (e.g. a BeyondATC crash) to have plausibly been complied with now reports "not enough data to judge compliance" instead of a false violation.

## [1.0.1] - 2026-08-09

### Fixed
- Player-initiated requests (IFR clearance, pushback, taxi, direct-to-fix, altitude/approach change, etc.) were misclassified as ATC speech in logs lacking `[PlayerAction]` tags, since they lead with the callsign the same way real ATC phraseology does.
- Carryover badges now name the target explicitly instead of "it"; the HDG final-heading label no longer implies a completed turn where the data doesn't support it.

## [1.0.0] - 2026-08-09

### Added
- Initial release: heading/altitude/speed compliance checks, response-timing checks, readback verification, vertical-speed checks, transponder-off-after-takeoff alert, and the aircraft approach-category system.
