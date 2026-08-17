# Changelog

All notable changes to this tool are recorded here, newest first. Format loosely follows [Keep a Changelog](https://keepachangelog.com/); versioning follows the guide in this repo's `publish-debugger` skill (patch = bug fixes only, minor = new check/feature, major = not expected for a tool like this).

This file is the source of truth for "what's actually been released" - update it in the same push as any new git tag, rather than relying on the working repo's `BACKLOG.md` (a separate, internal working log that isn't guaranteed to stay in sync with real tag history - see the 2026-08-17 entry below for exactly why that matters).

## [1.2.0] - 2026-08-17

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
