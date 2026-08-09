# BeyondATC Compliance Debugger

A single-file, client-side tool that cross-references a BeyondATC `Player.log` against the aircraft's actual flown telemetry to flag ATC-compliance issues (heading/altitude/speed deviations, missed readbacks, altitude busts). Used as an elimination step before filing bugs against BeyondATC itself: if this tool shows the player correctly following every instruction and BeyondATC's own ATC still misbehaved, that's evidence the bug is in BeyondATC, not the player.

**Usage**: open [`atc-compliance-debugger.html`](atc-compliance-debugger.html) in any modern browser and load a `Player.log` file (drag-and-drop or file picker). Nothing is uploaded — everything runs client-side.

See [`SPEC.md`](SPEC.md) for a full functional spec: what each check means, how to read a report, the exact thresholds and their sources, and known data/parsing limitations.
