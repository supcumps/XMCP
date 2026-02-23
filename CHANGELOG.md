# Changelog

All notable changes to XMCP will be documented here.

## [Unreleased]

### Fixed
- `run_project` and `build_project` now correctly capture and report compile errors from the Xojo IDE instead of always returning success
- Both tools use `DoCommand "RunApp"` / `DoCommand "BuildApp"` and parse the structured `buildError` JSON response
- Error output is formatted as a readable list with error type, message, location, and position

### Changed
- `search_docs` description clarified: it searches guides and tutorials, not the API reference — use `lookup_class` for class/method/property lookups

## [1.0.0] - 2026-01-01

### Added
- Initial release with 18 tools for controlling the Xojo IDE via MCP
