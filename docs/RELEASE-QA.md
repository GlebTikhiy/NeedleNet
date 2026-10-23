# Release hardening — 2026-10-23

Target: Windows Steam demo build 25963876, App 5165210, native banner V66.
Executable SHA-256: `0304f7cdd9d2a30510f43a45e6d7ce96f201e69ced4a7334d08a7bfd01073742`.
Engine: Godot 4.7.2 custom build `3ea155ec3`.

## Method

Tests run real game processes against an isolated game copy, with a separate APPDATA profile for each participant. Test drivers call native game methods and the mod's normal networking paths. They do not use the player's saves. Fixtures, raw logs, save files, private paths and native API dumps are excluded from this repository and the player ZIP.

Universal Modder did not identify the custom game container automatically. Runtime reflection confirmed the native `add_conveyor(from, to, line_id)` and item-manager `spawn(id, transform, state)` APIs. Native script source was unavailable; no claim of full source recovery is made. Conveyors and falling hay wads are actual game objects. Construction bypasses purchase/unlock UI deliberately; it does not prove that every machine can be bought or every production chain works.

## Completed observations

| Scenario | Result |
| --- | --- |
| Four clients, one host and three guests | Shared world and three remote avatars per participant |
| Guest buys an available technology through the normal purchase path | `hand_carry` rank and one money deduction replicated to all four |
| Host grants guest1 a broom | Only guest1 owns the tool; the unlock may remain shared |
| 128 native conveyor segments and 1,024 physical hay wads | 90-second LAN run; all four reported 51,200 strands |
| Five-second complete network outage | Session recovered without recreating the world |
| Moderate factory, 90 seconds of bad Wi-Fi | Continued session; host quantity conserved |
| Forced host process termination | All guests left the world and returned to the menu |
| Restart host using the same isolated save | Saved seed, field, money, conveyors, cargo and personal tool restored; deliberately unsaved +17 money rolled back |
| 64 closed conveyor loops / 256 segments / 4,096 spawned wads | 180-second rendered-host LAN run; exact host total of 204,800 strands |
| Large moving factory, 90 seconds of bad Wi-Fi | Host quantity conserved; no duplicate belt sequence IDs in sampled participants |
| Large-world manual refresh | Request acknowledged and completion reported after application |
| Large-world host crash | Guests returned to the menu in 29.3 seconds; saved world reloaded |
| Large-world checkpoint recovery | Seed, all 14,641 field heights, money, shared technologies, 256 conveyors, 204,800 strands and personal tool restored |
| 45-second complete network outage | Guests timed out after 31.1 seconds; host stayed in the world; all three rejoined and the factory continued |
| Targeted partial-belt replay, old vs fixed | Old implementation: two copies; fixed implementation: one copy |
| Preview.4 core suite | All eleven existing checks passed, including fifth-player rejection, tool duplication protection, rejoin and save/load |
| Graceful exit | Host and all three guests exited with code 0; no forced termination needed |

The crash tests disable automatic saving after writing an explicit checkpoint, so the expected rollback can be measured. Normal host autosaving is unchanged. Host migration is not implemented: guests rejoin the original host after it restarts and loads the save.

## Defect found and fixed

The large looping factory exposed guest-only duplicate belt record identities in preview.3. The host's authoritative quantity stayed correct. A client's predicted cargo could already have crossed a seam when an older partial update restored the source belt; the predicted copy on an untouched destination belt remained.

The fix removes older predicted copies of incoming identities from untouched paths before restoring authoritative rows. It also updates path load and received-sequence bookkeeping. Full snapshots keep their existing behavior. No physical cargo is spawned by this cleanup.

The first large fixture required 90% of spawned cargo to board belts, which exceeds their native capacity at this density. The corrected gate requires at least half the quantity to remain on moving belts, plus exact conservation of the host's combined belt and physical cargo. The passing fixture kept approximately 2,358 records moving; the remaining objects stayed physical. This is not a 4,096-records-on-belts claim.

An initial moderate fixture crossed the native selling zone: three wads disappeared while money rose by 3.33. The corrected fixture is away from the trigger. That initial observation is not reported as network loss.

## Measured load

Hardware: Ryzen 5 9600X, GeForce RTX 5060 Ti, 31.4 GiB usable RAM. One D3D12 Forward+ host rendered the factory overview; three guests ran headless. The captured viewport was **1920×1080**, despite the requested 1280×720 window size. The rendered phase used a 60 FPS cap.

During the 180-second loaded LAN phase:

| Process | Median of three-second frame-time p95 samples | Largest sampled frame interval | Resident memory, first → last sample |
| --- | --- | --- | --- |
| Rendered host | 17.41 ms | 67.28 ms | 2,492 → 2,511 MiB |
| Headless guest1 | 21.10 ms | 140.03 ms | 1,728 → 1,730 MiB |
| Headless guest2 | 20.90 ms | 123.95 ms | 1,733 → 1,735 MiB |
| Headless guest3 | 21.11 ms | 149.24 ms | 1,726 → 1,727 MiB |

Frame intervals use the monotonic wall clock. Headless timings measure simulation scheduling, not rendered FPS. Loading/building and the post-crash camera view are excluded from this table. Occasional hitches occurred; a capped FPS counter alone would hide them. These measurements describe this machine and camera, not a minimum-spec guarantee or a long-term leak test.

Guest belt previews may temporarily lag the host as partial snapshots and prediction cross paths; the large moving fixture does not claim identical cargo positions or quantities at every intermediate frame. Quantity conservation is asserted on the authoritative host; duplicate belt identities are checked on every participant. Moderate settled cargo converged exactly on all four.

## Network and remaining scope

Co-op Anything's UDP relay used seed 4242. The bad_wifi profile has nominal one-way latency 35±25 ms, 2% base loss with bursts, 2% reordering and 0.5% duplication. The large-run relay observed 208,464 packets, dropped 6,430 (including deliberate outages), and duplicated 242. These are local ENet fault-injection tests, not Steam-relay or separate-PC WAN tests. Successful Steam invitations and co-op were previously reported by a player.

Native headless renderer RID warnings/errors and the game's experimental rendering-thread warning occurred in these runs; this is not a warning-free-engine claim. Long playthroughs, every production-machine type, full progression, corrupted-save recovery, cross-version save migration and separate-PC transport faults remain outside this report. Native shared tutorial hints are still a known limitation. Keep the preview label while those broader release gates remain open.

## Reproduction

See [development setup](DEVELOPMENT.md). Install the optional QA dependency, provide your own isolated game copy, and run one suite at a time:

```text
python -m pip install -r tests/requirements-qa.txt
python tests/run_release_candidate.py
python tests/run_belt_mutation_pair.py
python tests/run_shutdown.py
```

For the large rendered scenario, set `NN_STRESS_BELTS=256`, `NN_STRESS_CARGO=4096`, `NN_STRESS_SECONDS=180`, `NN_STRESS_LOOPS=1`, `NN_RENDER_HOST=1`, and `NN_LONG_OUTAGE=1` before running `run_release_candidate.py`. The relay toolkit must be available at the ignored `tools/coop-anything/` path. The mutation pair requires the local `v0.1.0-preview.3` Git tag and always restores the fixed lab file. It deliberately reproduces the old two-copy result before checking the fixed one-copy invariant.
