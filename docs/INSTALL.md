# Installation / Установка

## Quick setup

Close the game. Back up `%APPDATA%\Godot\app_userdata\Haystack Incremental` separately, then extract the Windows release ZIP and double-click `Install.cmd`. The installer finds Steam libraries; if none contain the game, paste the folder containing `FindTheNeedle.exe` when prompted. No administrator launch is requested.

Закройте игру. Отдельно сохраните резервную копию `%APPDATA%\Godot\app_userdata\Haystack Incremental`. Распакуйте ZIP и запустите `Install.cmd`. При запросе укажите папку с `FindTheNeedle.exe`; её можно открыть в Steam через управление игрой → просмотр локальных файлов.

Supported build: Windows Steam Demo **25963876**. Expected EXE SHA-256: `0304F7CDD9D2A30510F43A45E6D7CE96F201E69CED4A7334D08A7BFD01073742`. A different build is rejected before installation.

For a specific location, PowerShell also supports:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -GamePath "<game folder>"
```

## Manual ZIP / ZIP без установщика

1. Close the game and back up saves, `override.cfg` and any existing `mods/multiplayer` folder. Open the game folder from Steam → Manage → Browse local files.
2. Extract **NeedleNet-0.1.0-preview.5-Manual.zip**. Copy its `mods` folder beside `FindTheNeedle.exe`.
3. If the game has no `override.cfg`, copy the included one beside the executable. If it already exists, **keep it** and add the entry below in a text editor. Under an existing `[autoload]` section, add or replace only the `MPMod` line; do not create a second section.

```ini
[autoload]
MPMod="*mods/multiplayer/mp.gd"
```

**По-русски:** закройте игру и скопируйте сохранения, старые `override.cfg` и `mods/multiplayer` в безопасное место. Откройте папку игры через Steam → Управление → Просмотреть локальные файлы. Скопируйте туда `mods` из ручного ZIP. Если `override.cfg` отсутствует, скопируйте готовый из архива. Если уже есть — сохраните его настройки и добавьте строку `MPMod` из примера в раздел `[autoload]` (существующую строку замените). Запускать скрипты не нужно.

Launch through Steam. Everyone needs the same mod version. The host creates the session and chooses New game or Load game; guests accept the invitation. Manual installation does not create automatic backups. To update, close the game, back up and replace `mods/multiplayer`; keep the existing autoload entry.

## Controls

| Action | Key |
| --- | --- |
| Session panel / Панель сессии | F2 |
| Chat / Чат | Y or visible Chat button |
| Send / Отправить | Enter |
| Close / Закрыть | Escape |
| Resynchronize / Повторная синхронизация | F8 |

Steam leaderboard participation is disabled by the mod. Saving belongs to the host. Direct IP is available in advanced settings; default port is UDP 7777.

## Rollback / Откат

Close the game. Restore the previous `override.cfg` and `multiplayer` folder from the desired timestamp inside the game's `NeedleNet-backups`. To disable the mod without restoring an earlier version, remove the `MPMod` entry from `override.cfg`. Restore personal saves separately if needed.

Закройте игру. Восстановите `override.cfg` и папку `multiplayer` из нужной резервной копии `NeedleNet-backups`. Для отключения мода достаточно убрать строку `MPMod` из `override.cfg`. Сохранения восстанавливаются отдельно.
