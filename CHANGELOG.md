# Changelog

All notable changes to XMCP will be documented here.

## [Unreleased]

## [1.2.0] - 2026-02-24

### Added
- MCP `resources` protocol support: `resources/list` and `resources/read` — clients can now fetch `usage-guide.md` as an MCP resource at session start
- `get_project_info` now returns a `Project Directory:` line with the full path to the project folder, enabling direct file editing workflows
- `usage-guide.md` is now distributed next to the binary and exposed as an MCP resource — AI clients receive it automatically; users can edit it without rebuilding

### Fixed
- Shell injection prevention in `get_system_log`: `process_name` parameter is now validated against a whitelist regex before interpolation into the shell command
- JSON-RPC `id` type preservation: integer ids are now correctly echoed back as integers (not coerced to strings), fixing protocol compliance
- `ToolParameter.ToJSONItem` now emits correct JSON types for Boolean and Integer defaults (not always String)
- `MCPKit.Error()` now emits JSON `null` for missing ids instead of an empty string
- `get_selected_text` and `set_selected_text` now return `Failure` instead of `Success` when the IDE returns an `ERROR:` string
- RequestID lookup fixed: integer ids no longer cause the server to exit with "Missing id" on subsequent requests

### Changed
- `get_system_log` now works for both debug builds (`AppName.debug`) and built apps (`AppName`) — not just debug builds as previously documented
- Actionable error messages in `select_project_item`, `get_code`, and `set_code`: errors now guide the AI to the correct alternative strategy (direct file editing, `revert_project`, etc.)
- `usage-guide.md` expanded with tested guidance: window event handler file format, `list_project_items` event limitation, debug vs. built app logging behavior

## [1.1.0] - 2026-02-23

### Added
- `get_debug_log` tool: reads crash/exception info written by `App.UnhandledException` handlers to `/tmp/xmcp_debug.log`
- `get_system_log` tool: reads `System.DebugLog` output from the macOS unified log for a named debug app process (e.g. `MyApp.debug`)

### Fixed
- `build_project` now correctly passes build type and reveal flag to `DoCommand "BuildApp"` as a single string argument (e.g. `"BuildApp 24 True"`) — comma-separated arguments caused a script compiler error
- XMCP server processes now terminate gracefully when the MCP client closes stdin, preventing zombie processes from accumulating
- `run_project` and `build_project` now correctly capture and report compile errors from the Xojo IDE instead of always returning success
- Error output is formatted as a readable list with error type, message, location, and position

### Changed
- `search_docs` description clarified: it searches guides and tutorials, not the API reference — use `lookup_class` for class/method/property lookups

## [1.0.0] - 2026-01-01

### Added
- Initial release with 20 tools for controlling the Xojo IDE via MCP
