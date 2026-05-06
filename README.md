# XMCP

An [MCP (Model Context Protocol)](https://modelcontextprotocol.io) server that gives AI assistants direct control over the [Xojo IDE](https://www.xojo.com). Built in Xojo using [MCPKit](https://github.com/gkjpettet/MCPKit) by Garry Pettet.

XMCP connects to the Xojo IDE via its IPC socket and exposes 22 tools that let an AI navigate projects, read and write code, build and run applications, create project items, inspect and modify item descriptions and constants, look up Xojo documentation, read debug logs and system output, and estimate request cost - all through the standard MCP protocol over stdin/stdout.

XMCP also ships a `usage-guide.md` file next to the binary, exposed as an MCP resource. Compatible clients (e.g. Claude Code) fetch it automatically at session start, giving the AI immediate awareness of XMCP's capabilities, known IDE scripting limitations, and fallback strategies — without any extra configuration. You can edit the file to add project-specific notes without rebuilding.

## Requirements

- **Xojo IDE** available for IDE tools (socket at `/tmp/XojoIDE` or `/private/tmp/XojoIDE`)
- **macOS** (current implementation targets macOS paths for IDE socket discovery and documentation auto-detection)
- **Xojo documentation** (optional) - install via **Xojo IDE → Preferences → General → Install Local Documentation**, then auto-detected by XMCP

## Installation

1. Open `src/XMCP.xojo_project` in the Xojo IDE
2. Build the project (Build > Build)
3. Note the path to the built `XMCP` binary

### Configure your MCP client

**Claude Code** (`~/.claude.json` or project `.mcp.json`):

```json
{
  "mcpServers": {
    "xmcp": {
      "command": "/path/to/XMCP"
    }
  }
}
```

**Claude Desktop** (`claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "xmcp": {
      "command": "/path/to/XMCP"
    }
  }
}
```

To specify a custom documentation path:

```json
{
  "mcpServers": {
    "xmcp": {
      "command": "/path/to/XMCP",
      "args": ["--docs-path", "/path/to/Documentation"]
    }
  }
}
```

## Usage

```
XMCP [options]
```

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Show help and list all available tools |
| `-v`, `--verbose` | Enable verbose debug logging to stderr |
| `-d`, `--docs-path PATH` | Path to Xojo documentation directory (auto-detected if omitted) |

The server communicates via JSON-RPC over stdin/stdout following the MCP protocol. It is not meant to be run interactively - it is launched by an MCP client (like Claude Code or Claude Desktop).

You can start XMCP before the Xojo IDE. IDE-dependent tools will return an error until the IDE socket is available.
XMCP retries both standard socket paths on each IDE request, so tools begin working automatically once the IDE starts.

## Tools

XMCP exposes 22 MCP tools organized into four categories.

### IDE Tools

These tools communicate with the Xojo IDE through its IPC socket to navigate, read, write, build, and manage projects.

#### `list_project_items`

Lists child items at a given location in the Xojo IDE Navigator. Returns a tab-delimited list of item names.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `location` | String | No | Dot-separated project path (e.g. `App` or `Module1.Method1`). Leave empty for top-level items. |

#### `get_current_location`

Returns the currently selected location in the Xojo IDE Navigator and its type (e.g. Class, Method, Window).

*No parameters.*

#### `select_project_item`

Navigates to a specific item in the Xojo IDE Navigator using a dot-separated path.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `item_path` | String | Yes | Dot-separated path to the project item (e.g. `App`, `Module1.MyMethod`). |

#### `get_code`

Reads the source code at the current location in the IDE editor. The `location` parameter is unreliable — omit it and use the IDE's current selection instead.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `location` | String | No | Dot-separated path to navigate to before reading. If empty, reads from current location. |

#### `set_code`

Writes source code to the current location in the IDE editor. Replaces the entire code content at that location. The `location` parameter is unreliable — omit it and use the IDE's current selection instead. Does not save to disk; the user must save manually (Cmd+S).

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `code` | String | Yes | The source code to write. |
| `location` | String | No | Dot-separated path to navigate to before writing. If empty, writes to current location. |

#### `get_selected_text`

Returns the currently selected text in the code editor, along with selection position and length.

*No parameters.*

#### `set_selected_text`

Replaces the currently selected text in the code editor with new text.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `text` | String | Yes | The replacement text to insert. |
| `selection_start` | Integer | No | Character offset to set the selection start before replacing. Default: -1 (use current). |
| `selection_length` | Integer | No | Number of characters to select before replacing. Default: 0. |

#### `build_project`

Builds the current Xojo project. Uses a 120-second timeout for long builds. **Note:** always reports "Build succeeded" regardless of whether the build actually succeeded — always ask the user to confirm the result.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `build_type` | Integer | No | `0` Default, `5` macOS (Cocoa), `9` Windows 32-bit, `14` Windows 64-bit, `16` Linux 32-bit, `17` Linux 64-bit, `18` Linux ARM, `24` macOS Universal. Default: 0. |
| `reveal` | Boolean | No | Reveal the built app in Finder after building. Default: false. |

#### `run_project`

Runs the current Xojo project in debug mode.

*No parameters.*

#### `stop_project`

Stops the currently running debug session.

*No parameters.*

#### `create_project_item`

Creates a new project item in the Xojo IDE.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `item_type` | String | Yes | One of: `NewClass`, `NewModule`, `NewMethod`, `NewProperty`, `NewConstant`, `NewEvent`, `NewNote`, `NewMenuHandler`, `NewComputedProperty`, `NewSharedMethod`, `NewSharedProperty`, `NewEnum`, `NewStructure`, `NewDelegate`, `NewInterface`, `NewWindow`, `NewContainerControl`, `NewFolder`, `AddEventImplementation`. |
| `parent_location` | String | No | Dot-separated path to navigate to before creating the item (e.g. `Module1`). |

#### `run_ide_script`

Executes an arbitrary Xojo IDE script. This is an escape hatch for any IDE scripting command not covered by other tools.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `script` | String | Yes | The IDE script code to execute. Use `Print` to return output values. |
| `timeout` | Integer | No | Timeout in milliseconds. Default: 10000 (10 seconds). |

#### `get_project_info`

Returns information about the currently open project including the project file path, Xojo IDE version, current location, location type, and selected item.

*No parameters.*

#### `revert_project`

Reverts the current Xojo project to the version saved on disk. Use this after modifying project files (e.g. `.xojo_window`, `.xojo_code`) directly to reload them in the IDE.

*No parameters.*

#### `get_item_description`

Gets or sets the description of the currently selected project item (method, property, event, etc.).

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `location` | String | No | Dot-separated path to navigate to before reading/writing (e.g. `App.MyMethod`). If empty, uses current location. |
| `value` | String | No | If provided, sets the description to this value. If omitted, returns the current description. |

#### `constant_value`

Gets or sets the value of a project constant. The constant must already exist in the project.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | String | Yes | The constant name. Can be simple (e.g. `kVersion`) or fully qualified (e.g. `App.kVersion`). |
| `value` | String | No | If provided, sets the constant to this value. If omitted, returns the current value. |

### Documentation Tools

These tools provide access to the local Xojo documentation, enabling the AI to look up classes, search for APIs, and browse available topics. Documentation is auto-detected from `~/Library/Application Support/Xojo/Xojo/<version>/Documentation/` or can be specified with `--docs-path`.

#### `search_docs`

Searches the local Xojo documentation guides and tutorials by keyword. Returns matching sections with surrounding context lines. Use this for conceptual questions about language features, patterns, and best practices. To look up a specific class, method, or property by name, use `lookup_class` instead.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `query` | String | Yes | The search term (e.g. `JSONItem`, `FolderItem`, `database`). |
| `max_results` | Integer | No | Maximum number of matching sections to return. Default: 5. |
| `context_lines` | Integer | No | Number of lines of context before and after each match. Default: 10. |

The documentation text is cached in memory after the first search for fast subsequent queries.

#### `lookup_class`

Looks up detailed documentation for a specific Xojo class, control, data type, or API by name. Returns the full structured reStructuredText reference including properties, methods, events, and examples.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `class_name` | String | Yes | The name of the class (e.g. `DesktopButton`, `JSONItem`, `FolderItem`, `String`). |

Automatically tries common prefixes (`Desktop`, `Web`) if the exact name isn't found.

#### `list_doc_topics`

Lists available Xojo documentation topics and pages from the `llms.txt` index. Use this to discover what documentation is available before looking up specific classes.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `filter` | String | No | Keyword to filter topics (e.g. `Desktop`, `database`, `networking`). If empty, returns all topics. |

### Debug Tools

These tools help diagnose runtime errors in Xojo apps by reading exception logs and system diagnostic output. For best results when building an app from scratch with XMCP, add an `App.UnhandledException` handler that writes to `/tmp/xmcp_debug.log`.

#### `get_debug_log`

Reads crash and exception info from `/tmp/xmcp_debug.log`. This file is written by `App.UnhandledException` handlers in Xojo apps that use the XMCP debug pattern. Call this after a crash or unexpected termination to retrieve exception details.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `clear` | Boolean | No | If true, deletes the log file after reading it. Default: false. |

#### `get_system_log`

Reads recent `System.DebugLog` output from the macOS unified log. Works for both debug builds (`AppName.debug`) and built apps (`AppName`).

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `process_name` | String | Yes | The process name to filter by. Debug builds use `AppName.debug`; built apps use `AppName`. Use `get_project_info` to find the project name. |
| `seconds` | Integer | No | How many seconds back to search the log. Default: 60, max: 3600. |

### Cost Awareness Tools

These tools estimate likely token cost before execution and suggest lower-cost approaches.

#### `estimate_request_cost`

Estimates expected token impact for a proposed request and optionally uses planned tool names to refine the estimate. Returns `LOW`, `MEDIUM`, or `HIGH`, with reasons and cheaper alternatives.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `request` | String | Yes | Natural-language request to estimate (for example: `Add a ListBox to Window1`). |
| `planned_tools` | String | No | Optional comma-separated tool names you expect to call (for example: `select_project_item,create_project_item`). |

## Resources

XMCP exposes one MCP resource that AI clients can fetch at session start:

| URI                     | Name             | Description                                                                                        |
|-------------------------|------------------|----------------------------------------------------------------------------------------------------|
| `file://usage-guide.md` | XMCP Usage Guide | AI-facing guide: capabilities, limitations, when to use IDE tools vs. direct file editing, and tips |

The `usage-guide.md` file is distributed next to the XMCP binary. You can edit it to add project-specific notes or custom conventions without rebuilding. Compatible MCP clients (e.g. Claude Code) fetch it automatically via `resources/list` and `resources/read`.

## Architecture

```
XMCP
├── App                    — MCP server entry point, tool registration, docs auto-detection
├── IDECommunicator        — IPC socket communication with Xojo IDE (protocol v2)
├── MCPKit/                — MCP protocol framework
│   ├── ServerApplication  — JSON-RPC stdin/stdout server loop
│   ├── Tool               — Base class for MCP tools
│   ├── ToolParameter      — Tool parameter definitions
│   ├── ToolArgument       — Parsed tool arguments
│   ├── ToolResult         — Success/Failure result type
│   ├── OptionParser       — CLI argument parsing
│   └── Option             — CLI option definition
└── Tools/                 — 22 MCP tool implementations
    ├── IDE tools (16)     — Control the Xojo IDE via IPC
    ├── Doc tools (3)      — Search and browse local Xojo documentation
    ├── Debug tools (2)    — Read crash logs and system diagnostic output
    └── Cost tools (1)     — Estimate request token cost and alternatives
```

### IDE Communication

XMCP connects to the Xojo IDE via a Unix domain socket (`IPCSocket`) at `/tmp/XojoIDE` (fallback: `/private/tmp/XojoIDE`). It uses the **IDE Communicator Protocol v2**, where messages are NUL-terminated JSON objects:

1. On connect, sends `{"protocol": 2}` to upgrade to protocol v2
2. Requests are sent as `{"tag": "xmcp_1", "script": "Print Location"}`
3. Responses arrive as `{"tag": "xmcp_1", "response": "App.Constructor"}`
4. Tags correlate requests with responses for synchronous operation

The `IDECommunicator` class handles connection management, tag generation, synchronous send/receive with configurable timeouts, and NUL-terminated message framing using direct `IPCSocket` communication.

For each IDE request, XMCP tries the last successful socket path first, then `/tmp/XojoIDE` and `/private/tmp/XojoIDE`. If all attempts fail, the tool returns a detailed connection/timeout error.

### Documentation Auto-Detection

On startup, XMCP scans `~/Library/Application Support/Xojo/Xojo/` for the newest Xojo version directory that contains `Documentation/llms-full.txt`. This file (along with `llms.txt` and `_sources/*.rst.txt`) is available via **Xojo IDE → Preferences → General → Install Local Documentation** and is intended specifically for LLM consumption.

## Known Limitations

- **macOS only** — depends on Unix domain sockets and macOS-specific Xojo docs location conventions.
- **IDE tools require an open project** — the Xojo IDE scripting socket must be available and a project must be loaded.
- **Documentation tools require local docs** — depend on `llms-full.txt`, `llms.txt`, and `_sources/*.rst.txt` files shipped with the Xojo IDE.
- **`get_code`, `set_code`, `get_selected_text`, `set_selected_text` require a method or property to be active** — these tools operate on the code editor view. If the selected item in the Navigator is a class, module, or folder (not a method, property, or other code item), they return an error: `No code editor is active. Navigate to a method or property first.`
- **`select_project_item` navigates to classes and folders, not individual methods or events** — the Xojo IDE scripting API (`SelectProjectItem`) can navigate to top-level items and classes, but not to individual methods, properties, or event implementations. `list_project_items` also does not list events. To read or write code for a specific method or event, use `get_code` or `set_code` with the full dot-separated path — XMCP navigates automatically before reading/writing.
- **IPC socket timing after navigation** — the Xojo IDE briefly closes its IPC socket (~2–3 seconds) after certain navigation operations. XMCP handles this with automatic retries (up to 5 × 1 second), so tools work reliably, but sequential IDE calls may take a few seconds longer after navigation.
- **Parallel tool calls are not supported** — the Xojo IDE accepts only one IPC connection at a time. MCP clients that send parallel tool calls (e.g. Claude Code in some modes) may see connection errors on concurrent requests. Sequential tool calls work reliably.

## Acknowledgments

- [MCPKit](https://github.com/gkjpettet/MCPKit) by Garry Pettet — the Xojo MCP framework that XMCP is built on

## License

MIT
