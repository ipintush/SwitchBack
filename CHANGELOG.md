# Mistype Changelog

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
