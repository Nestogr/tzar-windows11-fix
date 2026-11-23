# Tzar Fix (GOG) — Windows 11

Unofficial installer that makes **Tzar: The Burden of the Crown (GOG, v1.10)** start and play music on
Windows 11, straight from GOG Galaxy. The installer wizard is available in English and Spanish.

> **Tested on Windows 11.** It should also work on Windows 10 (nothing in the fix is specific to Windows 11),
> but this has not been tested yet. If you try it on Windows 10, please open an issue with the result and
> your `_tzarfix_backup\log.txt`.

## The problem

Launching GOG's Tzar on modern Windows shows a message saying that the current TZAR configuration is not
valid for this computer, and the game quits. Once that is bypassed, enabling music in *Options* fails with a
message saying that the MIDI device is being used by another application or is not working properly.
(Exact wording depends on the game language; on the Spanish version: *"La actual configuración de TZAR no es
válida para este ordenador..."* and *"No se puede activar la música porque el dispositivo midi está siendo
utilizado por otra aplicación..."*.)

## Root cause

At startup `Tzar.exe` counts video (DirectDraw) and sound devices (wave, DirectSound, MIDI) and compares
them with `tzar.ini` (`DIRECTDRAW_DEVICESNUMBER`, `SOUNDDEVICENUMBER`, `SOUNDDEVICEDXNUMBER`,
`SOUNDDEVICEMIDINUMBER`). Any mismatch shows the `invalidcfg` screen.

GOG also installs a **Windows compatibility shim** for `Tzar.exe` (`goggame.sdb`, "GOG.com Tzar",
`EmulateHeap` fix). With that shim, `winmm` **fails inside the game process**: the game sees 0 wave and
0 MIDI devices even though the PC has them. This has two effects:

- counts measured outside the game never match what the game sees, and
- MIDI music cannot work.

## What the installer does

1. Finds the Tzar folder (GOG registry or common paths) or lets you pick it. Checks that `Tzar.exe` exists.
2. Creates a **backup** in `<game>\_tzarfix_backup\original` (first run only, never overwritten).
   It covers `tzar.ini`, the VirtualStore copy, any previous `ddraw.dll`/`ddraw.ini`, `goggame.sdb`,
   the installed shim and its registry keys, and the compatibility layers on `Tzar.exe`.
   Every run also saves `run_<date>\tzar.ini`.
3. Uninstalls the GOG shim (`sdbinst -u`) and removes the compatibility layers on `Tzar.exe`.
4. Installs [cnc-ddraw](https://github.com/FunkyFr3sh/cnc-ddraw) v7.1.0.0 (bundled, works offline).
5. Sets `DIRECTXDEVICE=0` and `BUFFER_IN_VIDEO_MEMORY=0`.
6. **Opens Tzar for a few seconds**, reads from its memory how many devices it actually detects,
   writes those values to `tzar.ini`, and, if MIDI works, sets `MUSIC=1` and `CDAUDIO=0`.
7. Opens Tzar again to **verify** that the check passes, then shows "Verified" or a clear error.
8. Adds a **"Repair Tzar"** Start menu shortcut.

Everything is logged to `<game>\_tzarfix_backup\log.txt`.

## Install

1. Download `TzarFix-Setup-x.y.z.exe` from *Releases*.
2. Run it. The file is unsigned, so SmartScreen may say "Windows protected your PC".
   Click **More info → Run anyway**.
3. Accept the administrator prompt (needed to write to `Program Files` and to run `sdbinst`).
4. Check the game folder, then click *Next* and *Install*. Tzar opens and closes by itself twice; don't touch anything.
5. Tick "Play Tzar now", or launch it from GOG Galaxy as usual.

## If it breaks again

GOG Galaxy may reinstall the shim when it updates or verifies the game, and changing your audio devices
changes the device counts. In either case, run **Start → Repair Tzar**.

## Uninstall

Go to *Settings → Apps → Installed apps → Tzar Fix (GOG) → Uninstall*. Everything is restored from
`_tzarfix_backup\original`: `tzar.ini`, any previous `ddraw` files (or ours are deleted), the compatibility
layers and the **GOG shim** (`sdbinst`). With the shim restored, the game is back to its original, broken state.
The `_tzarfix_backup` folder and its log are kept.

## Requirements and limits

- Windows 11 (tested) or Windows 10 (should work, not tested yet), GOG's Tzar **v1.10** (the script checks the executable and changes nothing if it is a different version).
- Administrator rights are required.

---

## Build

Requirements: Windows, PowerShell 5.1+, [Inno Setup 6](https://jrsoftware.org/isinfo.php)
(`winget install JRSoftware.InnoSetup`).

```powershell
.\build.ps1 -Version 1.0.0     # -> dist\TzarFix-Setup-1.0.0.exe
```

`build.ps1` downloads the pinned cnc-ddraw release, verifies its SHA256 and compiles `src\TzarFix.iss`.
The GitHub Actions workflow (`.github/workflows/build.yml`) does the same on every published Release and
attaches the `.exe` to it.

| File | Purpose |
|---|---|
| `src/tzarfix.ps1` | Fix / repair / restore logic (run by the installer, the Start menu shortcut and the uninstaller) |
| `src/TzarFix.iss` | Inno Setup script (wizard ES/EN, game folder detection, uninstaller) |
| `build.ps1` | Fetches cnc-ddraw and compiles |
| `tools/make-icon.ps1` | Regenerates `src/tzarfix.ico` |

## License

MIT — see [LICENSE](LICENSE). Bundles cnc-ddraw by **FunkyFr3sh** (MIT), see
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). No game files are included. Not affiliated with GOG.com,
Haemimont Games or FX Interactive.
