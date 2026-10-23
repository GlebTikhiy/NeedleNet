# NeedleNet test results — 2026-10-22

## Version 0.19.6-NeedleNet.4

Rendered UI regression run PASS, on an isolated profile with real D3D12 rendering. Screenshots under local/ui/ were inspected; the slot-row wrap regression found during visual QA was corrected and rechecked.

- Native main-menu entry opens the session panel with one callback; co-op hint is displayed without a permanent HUD version watermark.
- Removing the native placeholder creates one replacement entry with native styling.
- Menu entry updates between Russian and English. Focus enters an available action, Tab stays inside the panel, closing restores the original menu button.
- Expanded IP settings fit 1280×720 using scrolling; close remains accessible.
- Host sees three compact open slots. Fresh profile offers the native NEW GAME action; it opens the game's original pre-demo screen while retaining the session.
- Native pause-menu session entry opens the panel; Escape returns to pause and restores button focus.
- Existing eleven-check four-client core suite also passed on .4, including money/hay, tool pickup, reconnect and save/menu/reload.

The local UI test disables mod Steam initialization deliberately. A separate rendered run against the installed .4 copy passed Steam initialization and verified that CREATE GAME is enabled, without creating a lobby or sending invites. Screenshots: local/ui/main-menu-steam.png and local/ui/session-steam.png. Real two-PC Steam joining and hours-long gameplay remain unverified.

## Version 0.19.6-NeedleNet.3

Fixed a reproduced ownership-recovery defect: the host reclaimed a departing guest's cargo locally but failed to notify other guests. The new test failed on .2 with a stale owner/epoch and frozen held copy; after the reliable owner broadcast it passed on .3.

Additional real-game checks on four isolated clients:

| Check | Result |
| --- | --- |
| Guest picks up a host-created hay wad, moves it, drops it | PASS; remaining peers see owner, held state and movement |
| Two guests compete for the same item | PASS; one owner and one carrying player |
| Owner disconnects while holding cargo | PASS after fix; all remaining peers see host ownership and released cargo |
| Owner rejoins after cargo recovery | PASS; recovered item is present with current owner |
| Guest carries/drops paper roll and hay bale | PASS |
| Repeat item scenarios behind deterministic bad_wifi UDP relay | PASS, seed 4242 |
| Eight native conveyors replicate to all guests | PASS |
| 160 physical hay wads fall onto conveyors and become belt cargo | PASS; at least 80 records observed on every participant |
| Belt cargo moves under the native simulation | PASS |
| No duplicate belt sequence IDs during 24-second observation | PASS |
| Conserved host cargo across belt-to-physical transitions | PASS; 8,000 strands in each of 10 loaded snapshots |
| Existing eleven-check core suite repeated on .3 | PASS; includes save/menu/reload, shared money/hay, tools, full-server timeout and reconnect |

Conveyor fixtures are created directly in a test world, bypassing purchase/unlock UI. The passing conveyor scenario is a small transport test, not a benchmark or verification of all production machines. A preliminary test seeded belt records directly; its results are not used as evidence for physical boarding or quantity conservation.

Chaos configuration: nominal one-way delay 35±25 ms, base loss 2% plus bursts, 2% reordering and 0.5% duplication. Actual relay counters: 9,232 packets seen, 352 dropped (162 client→server, 190 server→client), 46 duplicated (18/28). All item scenarios completed, including recovery after disconnect and paper-roll/hay-bale pickup/drop, with fixture quantities preserved. This models impaired local ENet traffic, not Steam relay or an actual WAN connection. Files: local/items-chaos-result.json, local/chaos-stats.json and local/chaos-packets.jsonl.

Reproduce additional scenarios: `python tests/run_items.py`, `python tests/run_factory.py`, `python tests/run_chaos.py`. Run one suite at a time; they share the same local host port. Test clients use separate profiles and their processes are cleaned up by their runner.

Still outside current evidence: real two-PC Steam/WAN session, full progression, all production-machine types, hours-long play and host-crash rollback. Native renderer RID warnings can occur in headless mode.

## Version 0.19.6-NeedleNet.2

Full expanded suite completed successfully against four isolated real-game clients on Steam build 25963876. Result file: local/session_result-v2.json. Separate fifth client exercised full-server handling.

| Check | Result |
| --- | --- |
| Four players and matching world seed | PASS |
| Three remote avatars per participant | PASS |
| Guest hay edit propagates; compare all 14,641 heights | PASS, maximum allowed per-value error 0.0021 |
| Guest money change reaches all participants | PASS |
| Guest horizontal displacement reaches host | PASS, 2 m within 0.1 m |
| Host drops broom; guest picks it up | PASS, loose copy removed on every peer |
| Three further pickup requests for that same item | PASS, one owner, no loose copies, no money change |
| Fifth client stops connecting and returns offline | PASS |
| Immediate reconnect after guest leaves | PASS after ordering fix; reproduced failure before fix |
| Host saves, returns to menu, reloads; all guests receive world | PASS, retained money and all heights within tolerance |
| Tool ownership after host save/reload | Observed one owner, no loose duplicate in final state |
| Universal Modder package lint | PASS, 161 files, zero failures/warnings before documentation refresh |

Hay edits and tool requests were issued through test scripts using the game's live state and the mod's normal networking path. They are not a test of every physical tool/carry interaction. Existing native renderer RID warnings occurred in some headless runs; no claim that all native warnings are eliminated.

Still unverified: two-computer Steam/WAN invitations, packet-loss behavior, full campaign/progression, all hay/paper carry interactions, loaded factory stress tests, host-crash rollback and long sessions. The original upstream issue #21 is not declared universally resolved based on the broom test.

## Earlier version 0.19.6-NeedleNet.1

Game: Windows Steam Demo, build 25963876, Godot 4.7.2 custom build.
Mod: 0.19.6-NeedleNet.1, adapted from Sucukdeluxe commit a9e8ecf42ab4baf75f8c5394bb27447b5e4b3cd3.

Executed against a private game copy, with separate APPDATA directories for every process. No personal saves were used. Headless game instances used actual game scenes, the mod's ENet transport and RPCs; these were not simulated clients.

| Check | Result |
| --- | --- |
| External autoload through override.cfg | PASS |
| Host plus three guests | PASS |
| World transfer and matching run seed | PASS |
| 14,641 hay height values loaded on each peer | PASS (size only; content equality not asserted) |
| Three remote avatars on every peer | PASS |
| Guest money change reaches all four peers | PASS (+17, no duplicate application observed) |
| Guest movement reaches host | PASS (x approximately 13.2 → 15.2) |
| Fifth connection cannot enter full world | PASS (still connecting after 15 seconds, no admitted player) |
| Guest disconnect reduces host roster to three | PASS |
| Guest rejoins and receives world/current money | PASS |
| Rendered multiplayer panel, Russian, four-player label | PASS (D3D12 screenshot inspected) |
| Installed game loads MPMod and initializes Steam | PASS (Steam ready, networking options accepted) |
| Universal Modder package lint before installation | PASS, 160 files, zero failures/warnings |

The custom header did not prevent running external scripts. No PCK decryption, engine patch or game asset extraction was required. GDRE Tools was identified as the applicable Godot recovery tool, but not downloaded because an existing MIT mod provided the tested entry point.

Not verified: two-computer Steam invitations, WAN transport, packet-loss behavior, complete gameplay progression, machine/item sync under load, save rollback, full hay-content equality and long sessions. These checks do not establish a complete bug-free playthrough.

Launching an external test script from a different working directory initially failed to resolve external mod files. Launching with the game's directory as the working directory fixed it. Steam should launch normally from the game directory; custom shortcuts should set their working directory accordingly.

Reproduction: prepare lab/game as a private copy, install package/mods and its autoload there, then run `python tests/run_session.py`. Raw private logs and state reports are under local/. Each run uses new profiles. Runner terminates only its own process handles.

## 0.19.6-NeedleNet.5 — 2026-10-23

- PASS `tests/run_session.py`: 11 core checks on four real local game processes, including remote movement, admission limit, rejoin, money, cargo and host save/reload. Snapshot: `local/session_result-v5-core.json`.
- PASS `tests/run_chat.py`: each of four participants sends Cyrillic and literal markup; all four receive the same author and 200-character bounded message. Snapshot: `local/chat-result.json`. Fixed the test reader's Windows default encoding to explicitly read UTF-8 state files.
- PASS `tests/run_ui.py`: native menu/pause integration, 720p session layout, visible lobby chat, literal text/history, player menu lock while typing, new/load choices with no saves and a valid save fixture, session retention across dialogs. Fixture comes from the isolated core test; the manual UI test world did not itself produce a save.
- PASS avatar buffer checks in the UI driver: midpoint interpolation, shortest yaw across ±180°, teleport reset. Typed test sample arrays are populated through append to preserve GDScript array types.
- PASS `tests/run_chaos.py`: Co-op Anything bad_wifi relay, seed 4242, four-client cargo/movement/claim/disconnect/rejoin and supported item kinds.
- PASS Universal Modder publication check: 164 files, zero failures/warnings.

Limits: no visual recording of continuous walking/running under packet loss, no real two-PC Steam/WAN run, no long chat scrolling/input endurance run, no hours-long factory session or host crash test. The 100 ms remote pose buffer intentionally trades a small presentation delay for smoother motion; long packet gaps hold the last pose.

## Public player package — 2026-10-23

`python tests/check_public_release.py`: PASS. 166 entries, including 155 runtime files identical to .5, valid per-file hashes, matching archive contents and manifest, reproducible ZIP, no forbidden development/personal/game-binary files, valid relative Markdown links, wrong game build rejected before writes. Steam-library discovery and backup/config preservation were also checked in an isolated installer fixture. Gameplay code unchanged.
