# NeedleNet changes

## 0.1.0-preview.2

- Move chat to the upper-left corner with a translucent background, compact controls and passive recent messages; chat no longer uses center-screen notification cards.
- Parent the local first-person body directly to the player so it shares the camera's movement and interpolation. Apply the native camera interpolation offset in late idle processing, before renderer transform submission; a pre-draw update is too late. Remote avatars keep their separate network interpolation.
- Add rendered native-controller walking/running/stopping regression coverage and 720p chat layout checks.


## 0.1.0-preview.1

- Adopt independent Semantic Versioning for NeedleNet. This preview replaces the former `0.19.6-NeedleNet.5` label; gameplay is unchanged.
- Update the in-game version, release tag, download names and documentation. All players must use the same version label.


## 0.19.6-NeedleNet.5

- Separate host actions for new game and load; disable load when no saves exist. Keep new game available with existing saves and focus it first.
- Add visible lobby/HUD chat controls, 100-message scrollable history with participant colors, and lobby chat. Preserve literal markup and Cyrillic; bound sent messages to 200 characters. Block player controls while typing.
- Render remote avatars from a bounded pose buffer 100 ms behind incoming updates, clear it on teleports, and disable duplicate physics interpolation. Match local model yaw and position to the same interpolated transform.

## 0.19.6-NeedleNet.4

- Integrate session access into native main-menu and pause-menu buttons, retaining game fonts/styles and keyboard focus.
- Show four-player co-op hint and current roster count in the main menu; recreate the entry if a native placeholder is absent.
- Show empty player slots and use the available primary action as initial panel focus. Keep Tab inside the panel and return focus on close/Escape.
- Start the native new-game flow on fresh profiles; retain native save selection when saves exist.
- Move mod version from permanent HUD watermark to session-panel footer; simplify unavailable-Steam messaging and remove duplicate instructions.
- Verify panel layout at 720p with expanded advanced settings, plus Russian/English menu updates and native pause entry.

## 0.19.6-NeedleNet.3

- Broadcast cargo ownership recovery when a player disconnects. Previously only the host adopted the item; other guests retained the departed owner and a frozen held puppet.
- Add four-client item scenarios for guest hay carry/movement/drop, competing claims, cargo recovery after disconnect, and paper-roll/hay-bale carry.
- Add a deterministic bad-Wi-Fi test through Co-op Anything's UDP relay and a physical-cargo conveyor scenario.

## 0.19.6-NeedleNet.2

- End unsuccessful connections after 30 seconds instead of leaving clients indefinitely on the connection screen.
- Queue host/join requests made while returning from an aborted guest world. Previously the transition guard returned before the pending-session branch, so a quick reconnect could be discarded.
- Expand real-client regression scenarios: compare every hay height within the existing HAY_EPS tolerance, guest hay edits, host tool drop/guest pickup/repeated requests, save and world reload.
- Strengthen movement assertions to check two metres of horizontal displacement rather than any pose change.

## 0.19.6-NeedleNet.1

- Adapt Sucukdeluxe's MIT maintenance fork to four total players.
- Add capacity admission guard and distinct compatibility version.
- Add isolated local real-game tests, installer backups and Russian instructions.
- Reference installed GodotSteam libraries instead of distributing copies of game DLLs.
