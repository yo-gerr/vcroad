# AGENTS.md

## Build notes (Windows)

- `flutter build web --release` fails with `ProcessException: An Application Control policy has blocked this file` from `font-subset.exe` (Windows App Control policy blocks Flutter's icon tree-shaker binary).
- Always build web with the icon tree-shaker disabled:
  ```
  flutter build web --release --no-tree-shake-icons
  ```
  This skips the blocked `font-subset.exe`. Trade-off: full icon fonts are bundled (slightly larger output).
- A system-level alternative is adding an allow rule for `C:\flutter\bin\cache\artifacts\engine\windows-x64\font-subset.exe` in the Windows App Control policy.
