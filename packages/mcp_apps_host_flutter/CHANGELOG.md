# Changelog

All notable changes to this package are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.2.0] - 2026-11-13

### Added

- `ToolApprovalLabels` (English and Korean texts) and optional `labels` and `locale` arguments on `showToolApprovalDialog` / `ToolApprovalDialog`. The default follows the app locale: Korean when it is `ko`, otherwise English. Apps that do not list `ko` in `supportedLocales` still see English.

## [0.1.1] - 2026-11-11

### Changed

- Documentation only: English `README.md` is now the default, with a Korean `README.ko.md`.

## [0.1.0] - 2026-11-10

### Added
- First release. Implements the host side of MCP Apps spec revision 2026-01-26.

[0.2.0]: https://github.com/LeeGyeongPil/mcp-apps-host-dart/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/LeeGyeongPil/mcp-apps-host-dart/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/LeeGyeongPil/mcp-apps-host-dart/releases/tag/v0.1.0
