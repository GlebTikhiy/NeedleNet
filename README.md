![NeedleNet — four players, one shared world](media/banner.svg)

# NeedleNet

**Find The Needle Demo, together.** An unofficial co-op mod for up to four players: one host and three friends.

[Русский / Russian](README-RU.md) · [Recording guide](docs/CREATORS.md) · [Credits](NOTICE.md)

**0.1.0-preview.5 · Windows · Steam demo build 25963876 · Preview**

## Play together

- Create a session and invite friends through the Steam interface.
- Start a new game or choose an existing save from the session panel.
- Share the yard, money and progress; the host saves the world.
- Use the visible chat button or **Y** in the lobby and in game.
- Open the session panel from the main menu, pause menu or **F2**.

Every player needs the game and the same NeedleNet version. This fork also includes the base mod's machines, upgrades and balance changes.

## Download and install

Download **NeedleNet-0.1.0-preview.5-Windows.zip** from [**Releases**](https://github.com/GlebTikhiy/NeedleNet/releases/tag/v0.1.0-preview.5), then extract it. GitHub's automatic “Source code” ZIP contains the development project; players should use the named Windows ZIP instead.

1. Close the game and back up your saves.
2. Double-click **Install.cmd** in the extracted folder. The installer looks for the game in Steam libraries and asks for its folder if necessary.
3. Launch the game through Steam. Select **Multiplayer**, create a session, invite friends, then choose **New game** or **Load game**.

The installer checks the supported game build and backs up the previous mod/configuration under `NeedleNet-backups` in the game folder. It does not include the game or modify its executable. [Manual installation and rollback](docs/INSTALL.md).

## Preview status

Four local game clients passed synchronization, save/load, chat and impaired-network tests. A player has also reported successful Steam invitations and co-op play; our automated coverage remains local. Host-crash checkpoint recovery and a 256-conveyor / 4,096-object factory have now passed automated checks; a 90-minute four-client soak passed with seven save/load cycles and outputs from six separately supplied machine types. End-to-end production chains and purchase/unlock progression remain unverified. A rendered native-controller test reproduces the former first-person body lag and verifies view alignment and stable rendered geometry after the fix; broader real-play coverage is still pending.

NeedleNet uses independent `MAJOR.MINOR.PATCH` versions; game and upstream versions are tracked separately. The source repository documents the policy in `docs/VERSIONING.md`.

The source repository includes the detailed test report in `docs/TEST-RESULTS.md`.

For a recording session, run a short connection and save/load rehearsal first. [A quick checklist and description text](docs/CREATORS.md).

## Development and attribution

Based on [Sucukdeluxe / xRangerDE's maintenance fork](https://github.com/Sucukdeluxe/FindTheNeedle-Coop-Mod), pinned at `a9e8ecf42ab4baf75f8c5394bb27447b5e4b3cd3`, originally by [AleDev11](https://github.com/AleDev11/FindTheNeedle-Coop-Mod). MIT license; Quaternius player model is CC0. NeedleNet changes were developed with AI assistance. This project is not affiliated with the game developer.

See [development and testing](https://github.com/GlebTikhiy/NeedleNet/blob/main/docs/DEVELOPMENT.md). Run `python build_release.py` to create the player ZIP and its SHA-256 file in `dist/`. The builder includes only the documented runtime files and player instructions. Report reproducible issues using the issue template; remove personal details from logs.

Automatic startup update checks use the public GitHub release API with a one-hour cache and show an optional download link. Downloads open in the browser; files are not replaced during play. The manual world refresh is a recovery tool, not required for normal automatic synchronization. Some native tutorial hints still follow shared progression rather than per-player tool ownership.
