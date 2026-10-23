# NeedleNet 0.1.0-preview.3

- Player names now shrink with distance instead of dominating distant avatars. Tool captions are shown only nearby, and names fade out over 24–32 m.
- Manual world refresh reports what happened: the host sees how many snapshots were sent; guests see application completion or a 15-second timeout that permits retry. Networking already synchronizes the world automatically.
- New-version checks use the public GitHub release API, cached for one hour. An available update shows a notice and a button opening its official download page. No files are replaced during gameplay.

Four-client recovery checks passed for snapshot application, host send status, timeout state and retry. UI/version-comparison tests and a real GitHub query passed. A player reported successful Steam invitations and co-op play; that report is distinguished from local automated tests.

Native tool tutorial hints still follow shared progression. They have not been rewritten in this preview. Long sessions and host-crash recovery remain outside current verification.

Every participant should use the same version. Requires Windows Steam Demo build 25963876. Extract `NeedleNet-0.1.0-preview.3-Windows.zip`, close the game and run `Install.cmd`. Existing mod/configuration files are backed up. Credits and license notices are preserved.
