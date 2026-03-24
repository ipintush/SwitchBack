# SwitchBack Changelog

## 1.4 (2026-03-23)

### Bug Fixes

- **Persistent Accessibility permission**: Sign with a self-signed certificate ("SwitchBack Dev") so TCC recognizes the same identity across updates. Previously, each build produced a new ad-hoc signature, forcing users to re-grant Accessibility after every update. Run `setup-cert.sh` once to create the certificate; subsequent builds and installs will no longer trigger the permission prompt.
- **Smart TCC reset**: `postinstall` and `install-direct.sh` now reset the Accessibility permission only when the previous binary was ad-hoc signed — preserving a valid grant when the self-signed certificate is in use.

---

## 1.3 (2026-03-22)

### Features

- **Switch Input Language**: Optional setting to automatically switch the macOS input
  source after each conversion (Hebrew↔English). Off by default. Toggle via menu bar.

---

## 1.2 (2026-03-18)

### Features

- **Launch on Login**: New menu item to toggle whether SwitchBack launches automatically at login.

---

## 1.1 (2026-03-11)

### Bug Fixes

- **Clipboard race condition**: Rapid hotkey presses no longer cause stale converted text to be pasted. Each new conversion now cancels any pending clipboard-restore from the previous operation before starting.
- **Clipboard restore delay**: Increased from 0.15 s to 0.5 s so slow apps (e.g. heavy Electron apps) have enough time to finish processing Cmd+V before the original clipboard is restored.

### Features

- **FN / Globe key support**: Globe+letter combinations (e.g. Globe+H) can now be recorded as custom hotkeys. The recorder accepts `.function` as a valid modifier and displays it as `fn` in the hotkey field and menu bar (e.g. `fn H`).
- **Special key names**: The hotkey display now shows human-readable names for Space, Return, Tab, F1–F12, and Globe instead of `?`.

---

## 1.0 (initial release)

- Menu-bar app for toggling text between Hebrew and English keyboard layouts.
- Global hotkey (default Cmd+Shift+H): copies selected text, converts it, pastes it back.
- Custom hotkey recorder with Cmd / Ctrl / Option modifier support.
- Accessibility permission prompt on first launch.
