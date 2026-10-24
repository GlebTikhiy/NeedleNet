# Ninety-minute soak — 2026-10-24

Result: **PASS_WITH_COVERAGE_GAPS**. This validates the queued-snapshot fix in preview.5; it is not full progression or separate-PC Steam certification.

Four real game processes used isolated lab profiles: one rendered host, three headless guests. All test audio was disabled using the Dummy audio driver and master-bus mute. Runtime belt-module SHA-256: `9011c7342ee987317c59d8e78d617e019dd0a2ee9ea66304eaf4dd19b8054159`. After the release version-string bump, the eleven-check preview.5 core suite also passed, including rejoin, fifth-player rejection and save/load.

| Check | Observed result |
| --- | --- |
| Duration | Scheduled 90-minute loop; 90.53 minutes from soak start through final recovery/shutdown; total 94.02 minutes |
| Native factory fixture | 256 conveyor segments in closed loops; 4,096 spawned physical hay wads |
| Authoritative quantity | 204,800 strands in every one of 493 sampled host states |
| Duplicate belt sequence IDs | Zero in all four participants' 493 sampled states |
| Save/load | Seven completed cycles |
| Guest actions and rejoin | Sixteen completed cycles including money, field edits, chat and reconnect |
| Network | Alternating local ENet LAN/bad_wifi; seed 4242 |
| Host process termination | Checkpoint restoration passed; deliberately unsaved money rolled back |
| End of test | All four processes exited normally; no script-error lines in collected logs |

Cross-path records superseded during pending-snapshot merging reached maxima of 6,971 for guest1, 9,468 for guest2 and 4,994 for guest3. Counters reset when their world service is recreated; these are per-role maxima, not a combined session total. They show that the repaired merge path was exercised repeatedly.

Peak resident memory was approximately 2,899 MiB for the rendered host and 2,084 / 2,084 / 2,162 MiB for the headless guests. These are peaks, not proof of zero memory growth. Frame positions and guest cargo previews are predicted between snapshots; sampled host conservation does not assert identical per-frame guest positions/quantities.

## Failure that led to this fix

The preceding preview.4 soak stopped after 73 samples, approximately 12 minutes into its loaded phase. Guest2 reported six duplicate belt identities after bad Wi-Fi and rejoin. The host remained at 204,800 strands.

The pending queue could combine an older full snapshot containing a record on path A with a newer partial update containing that record on path B. Both packets were valid independently; their merged result was not. The earlier prediction cleanup only removed copies outside the paths being replaced, so this separate queue case remained.

The fix removes superseded record locations from older queued entries before path merging and validates merged entries before clearing any live cargo. A deterministic real-engine replay produced two copies on preview.4 and one on the fix. An explicitly invalid merged snapshot was rejected before mutation. The earlier seam/prediction replay also continued to produce one copy after the fix.

## Individual machine probes

Before the main soak, native generators with physical fuel, poles/wires, a borehole and a water main supplied six separately placed machine types. Native physical input items were dropped into their intakes; the press received native batch-sized inputs. Actual output signals were observed:

| Machine | Output confirmation |
| --- | --- |
| Compressor | `baled`: 1 |
| Pulper | `slabbed_record`: 2 |
| Paper machine | `rolled_record`: 2 |
| Briquette press | `pressed_record`: 2 |
| Wrapper | `wrapped`: 1 |
| Pelletizer | `bricked`: 8 |

These probes ran before the conveyor soak and their fixtures were discarded by loading a clean checkpoint. They do not claim 90 minutes of continuous production on all six machines, full stock conversion, end-to-end linked chains or normal blueprint purchases. The original probes had no electricity/water and proved no output; correcting the fixture is not counted as a production-runtime fix.

## Remaining gates and reproduction

Still unverified: linked end-to-end production chains with normal purchase/unlock progression, and separate-PC Steam transport fault handling. Successful Steam invitations/co-op were previously reported by a player; the automated relay remains local ENet.

Run [the unattended test](../LONG-TEST.md) from a prepared isolated lab. The source checkout includes Windows launch/stop scripts and writes a copyable final report. No game files, personal saves, native API dumps or raw session logs are distributed. No test code is included in the player ZIP, and passing this runner never publishes a stable release automatically.
