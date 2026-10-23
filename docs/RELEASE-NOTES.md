# NeedleNet 0.1.0-preview.2

- Chat now opens in the upper-left corner with a translucent background and compact controls. Recent messages appear there without opening the input, then disappear after 10 seconds. Full history stays available with Y.
- Fix first-person body jitter when looking down while walking or running. The body now belongs to the player transform alongside the camera, and applies the native camera interpolation offset before the renderer receives transforms.
- Preserve the existing leg animation and remote-player network interpolation.

A rendered native-controller regression reproduced up to 0.07 m of local-body lag while walking and 0.117 m while running before the fix. The final test verifies zero view-alignment error; the fixed-pose rendered silhouette varies by only 1 pixel with native camera smoothing active. Chat layout and transparency are checked at 720p.

All players should install this version together. Requires Windows Steam Demo build 25963876. Extract `NeedleNet-0.1.0-preview.2-Windows.zip`, close the game and run `Install.cmd`. The installer backs up the previous mod and configuration.

This remains a preview. Separate-PC Steam invitations, long sessions and host-crash recovery need further testing. Core mod credits and licenses are preserved in LICENSE and NOTICE.md.
