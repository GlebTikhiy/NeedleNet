# NeedleNet 0.1.0-preview.5

Fixed another guest-only conveyor duplication case: an older full snapshot and a newer partial update could queue the same cargo on two different paths. Newer record locations now supersede older queued copies, and merged snapshots are validated before touching live cargo.

A 90.53-minute four-client native factory soak passed: 256 conveyor segments, 4,096 spawned objects, exactly 204,800 strands in all 493 sampled host states, no sampled duplicate identities, seven save/load cycles, sixteen guest activity/rejoin cycles, host-crash checkpoint restoration and normal process exits. Six separately supplied machine types also confirmed output before the main soak. [Detailed results and limitations](https://github.com/GlebTikhiy/NeedleNet/blob/v0.1.0-preview.5/docs/LONG-TEST-RESULTS.md).

This remains a preview. Linked production chains with normal purchases/unlocks and separate-PC Steam fault injection are still unverified. Individual machine probes do not certify complete progression. Native tutorial hints remain shared; host migration is not implemented.

Every player must update together. Requires Windows Steam Demo build 25963876. Extract `NeedleNet-0.1.0-preview.5-Windows.zip`, close the game and run `Install.cmd`. Previous mod/configuration files are backed up. Game files, private saves, raw logs and test drivers are not included in the player ZIP.
