# Changelog

All notable changes to XMCP will be documented here.

## [Unreleased]

### Fixed
- `build_project` no longer silently fails. Previously it sent `DoCommand "BuildApp <buildType> <reveal>"`, which is an invalid combination of the no-argument `DoCommand "BuildApp"` form and the `BuildApp(buildType, reveal)` function form — the IDE ignored the trailing tokens, returned `{}` without building, and the tool reported "Build succeeded" while no `.app` was produced. The tool now uses `DoCommand "BuildApp"` and respects the IDE's configured Build Settings. Reported on the Xojo forum.
- **Runaway CPU and orphaned processes**: three loops in `IDECommunicator` (retry-pause, connect-poll, read-poll) were busy-waiting without yielding, pinning a CPU core at 100% whenever the IDE socket was slow and preventing the server from noticing stdin closure. All three now sleep briefly between iterations.
- **Server-killing requests**: a JSON-RPC request without `id` that wasn't a notification used `Exit`, which broke out of the main loop and terminated the whole process. A single malformed client frame became a denial-of-service. Now logs the error and continues.
- **Boolean arguments rejected as objects**: `MCPKit.TypeFromValue` had no `Variant.TypeBoolean` branch and `IsNumeric` returns True for booleans, so any boolean tool argument (e.g. `get_debug_log`'s `clear: true`) was misclassified as an object and failed validation. Added an explicit boolean check.
- **`constant_value` schema lied**: `name` was advertised as optional but rejected at runtime when empty. Marked required so the schema matches behavior.
- **Zero-arg tools rejected calls without `arguments`**: per MCP spec, `arguments` may be omitted for tools with no parameters. The server now treats missing `arguments` as an empty object.
- **`initialize` echoed the client's protocol version**: the server now asserts its own `PROTOCOL_VERSION` instead of falsely claiming compatibility with whatever version the client requested.
- **Malformed `tools/call` returned generic ServerError**: when `params` was not a JSON object, or `name` was missing or non-string, the server raised RuntimeException and reported -32000 ServerError. Now validates explicitly and returns -32602 InvalidParameters with a clear message. The same defensive check now also rejects non-object `arguments` (e.g. arrays).
- **`build_project` / `run_project` misreported plain-text failures as success**: any non-JSON string response was treated as success. Now only empty/whitespace responses (the expected happy path) become Success — non-empty non-JSON surfaces the raw text as Failure.
- **`RunScript` helper swallowed IDE script errors**: the centralized response handler stringified `scriptError` JSON objects as Success, hiding real failures. It now detects `scriptError` and returns Failure with the IDE's error payload.
- **UTF-8 truncation could split codepoints**: `LeftBytes` / `RightBytes` cut at byte boundaries, which could leave malformed UTF-8 in `get_system_log`, `list_doc_topics`, and `lookup_class`. Switched to character-counted `Left` / `Right`.
- **`get_system_log` had no timeout or error path**: `Shell.Execute` could run unbounded and a failed `log show` produced no signal. Now has a 30 s timeout, surfaces non-zero exit codes as Failure, and caps output at ~256 K characters (tail-truncated, with a footer pointing to the `seconds` parameter for narrower queries).

### Added

- **Semantic search for `search_docs`**: when the XMCP-RAG embedding server (`http://localhost:8089/v1/embeddings`) is running and `xojo_rag.db` is present alongside `llms-full.txt`, `search_docs` automatically uses vector-based semantic search instead of keyword matching. Falls back to keyword search silently when either is unavailable — no configuration required and the AI sees no difference in tool name or output format.
- **Trust model section in `usage-guide.md`**: documents that XMCP is a full-trust local bridge, not a sandbox — `run_ide_script` executes arbitrary IDE scripting code with full IDE authority, and several other tools mutate the project without confirmation. Intended for a single trusted MCP client on the developer's workstation.

### Changed
- `build_project` no longer takes `build_type` or `reveal` parameters. Build targets are now controlled via the IDE's Build Settings (`BuildMac`, `BuildWin32`, etc.) selected in the IDE.
- `usage-guide.md`: removed the "always reports Build succeeded" warning — `build_project` now reports real outcomes
- CLAUDE.md: documented the distinction between `DoCommand "BuildApp"` (no-argument, uses Build Settings) and the `BuildApp(buildType, reveal)` function form, with correct buildType values
- **Internal: centralized IDE response handling in `IDECommunicator.RunScript`**: 12 of the simple IDE tools now share a single helper for the Nil-check → string/JSON unwrap → "ERROR:" / `scriptError` mapping flow that was previously duplicated in each tool. Net diff −219 lines. `build_project`, `run_project`, `get_project_info`, and `run_ide_script` retain bespoke response handling.
- `list_doc_topics` and `lookup_class`: results are now capped at ~100 K characters with a footer pointing to `filter` / `search_docs` for narrower lookups, to avoid token bloat on large documentation pages.

## [1.3.1] - 2026-05-06

### Added
- `examples/` folder next to `usage-guide.md` with reference implementations of common Xojo file structures: `App.xojo_code`, `Module1.xojo_code`, `MyClass.xojo_code`, `MyButton.xojo_code`, `Window1.xojo_window` — gives the AI concrete templates to copy from when creating or editing project files

## [1.3.0] - 2026-05-06

### Changed
- `usage-guide.md`: direct file editing is now the primary approach for all code changes — not a fallback. `get_code`/`set_code` with dot-separated paths are unreliable and the guide no longer recommends them for writing code
- `usage-guide.md`: `get_code`/`set_code` without a location parameter work reliably when the user has already selected code in the IDE — after `set_code`, the AI now reminds the user to save (Cmd+S)
- `usage-guide.md`: `build_project` always reports "Build succeeded" regardless of outcome — AI now always asks the user to confirm the build succeeded
- `usage-guide.md`: `get_debug_log` is only useful in built apps — the Xojo debugger intercepts all exceptions in debug mode so they never reach the log. The log may contain data from a previous crash; always call `get_debug_log` with `clear: true` after reading
- `usage-guide.md`: `list_doc_topics` should not be used for lookups — use `search_docs` instead to avoid wasting tokens on the full 143,000-character index
- `usage-guide.md`: runtime exceptions in debug mode are visible to the user in the IDE debugger but not to XMCP
- `select_project_item`: error message no longer suggests using `get_code`/`set_code` with dot-path as an alternative
- CLAUDE.md/README.md: corrected incorrect claim that `.xojo_project` is XML (it is key/value text format)

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
