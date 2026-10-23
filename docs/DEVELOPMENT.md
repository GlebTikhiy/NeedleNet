# Development and testing

Runtime GDScript and mod-specific assets live in `mods/multiplayer`. Python is needed for packaging and test orchestration, not to play.

## Package

Run `python build_release.py` with Python 3. The named Windows ZIP and its SHA-256 checksum are created in `dist/`. The builder checks version metadata, unexpected runtime files, obvious private-path/credential markers and ZIP integrity. The included manifest records each shipped file's size and SHA-256.

## Game tests

Drivers target Windows and the exact Steam demo build in the README. Supply your own game as an isolated copy under `lab/game/`, copy this repository's `mods` there and enable MPMod as described in INSTALL.md. Do not commit the game copy.

Run with Windows Python. Drivers create profiles/logs in ignored `local/` and set `NEEDLENET_TEST=1` to disable mod Steam networking; native Steam initialization can still occur. Network suites share a host port and must run sequentially.

```text
python tests/run_session.py
python tests/run_chat.py
python tests/run_items.py
python tests/run_ui.py
```

Run the core suite before UI tests to provide an isolated valid-save fixture. UI tests render the actual game and require graphics support. `run_factory.py` tests a limited conveyor fixture rather than all machines.

`run_chaos.py` also needs Co-op Anything's `tools/chaos/chaos.py` under ignored `tools/coop-anything/`; obtain that toolkit separately. It uses the bad_wifi profile and seed 4242. The toolkit is not a player dependency.

Test commands deliberately mutate worlds. Use the isolated copy and generated profiles, never a personal playthrough. TEST-RESULTS.md documents actual checks and remaining gaps; local tests do not establish separate-PC Steam connectivity.


## First-person motion regression

`python tests/run_motion_probe.py` renders native walking, sprinting, a fixed-skeleton walking segment, and stopping while looking down. The fixed-pose segment is deliberate test instrumentation; production does not freeze animation. The native camera keeps updating throughout. It checks alignment to the native camera's interpolation offset, rather than requiring the body to remain at the raw physics origin.

For pixel-level verification, install the optional analysis dependencies from `tests/requirements-motion.txt` and run `python tests/check_motion_frames.py`. This checks the red host torso silhouette in the fixed-pose frames. It caught a pre-draw transform change reaching the renderer too late even when scene-graph coordinates looked correct. Screenshots and logs remain in ignored `local/motion/current/`.


`python tests/run_recovery.py` tests manual snapshot completion, host send reporting and retry after an injected expired-deadline state on four local clients. Update checks are disabled automatically under NEEDLENET_TEST=1, while explicit manual checks remain available. `tests/update_live.gd` is a SceneTree driver for a real HTTP query; it neither opens a browser nor installs files.

## Factory stress and failure recovery

See [release QA](RELEASE-QA.md) for the larger native factory, host process termination, long network outage and mutation-pair regression. `run_release_candidate.py` needs the optional `tests/requirements-qa.txt` dependency and the Co-op Anything UDP relay. `run_shutdown.py` verifies graceful process exits separately from forced test cleanup.
