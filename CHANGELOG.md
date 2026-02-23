# Changelog

All notable changes to XMCP will be documented here.

## [Unreleased]

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
