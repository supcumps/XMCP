# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

XMCP is an MCP (Model Context Protocol) server written in **Xojo** that gives AI assistants direct control over the Xojo IDE. It communicates via stdin/stdout JSON-RPC (MCP protocol) and forwards IDE commands via a Unix domain socket to the running Xojo IDE process.

## Building

This is a **Xojo native application** — there is no Makefile, npm, or shell-based build system.

- **Project file**: `src/XMCP.xojo_project`
- **Build**: Open the project in Xojo IDE and use Build > Build
- **Output**: `src/Builds - XMCP/XMCP` (macOS binary)
- **Alternatively**: Use the `mcp__xmcp__build_project` MCP tool if XMCP itself is running

There are no automated tests or linting tools; validation happens through Xojo IDE's built-in compiler and manual integration testing with an MCP client.

## Architecture

### Communication Flow

```
MCP Client (stdin/stdout JSON-RPC)
    → MCPKit.ServerApplication  (request routing)
        → Tool.Run()            (each of 22 tools)
            → IDECommunicator   (IPCSocket to Xojo IDE)
                → Xojo IDE      (executes IDE scripts, returns results)
```

### Key Components

**`App.xojo_code`** — Entry point. Registers all 22 tools in `Configure()`, auto-detects the Xojo documentation path under `~/Library/Application Support/Xojo/`, initializes `IDECommunicator`. The global `App.IDE` instance is used by all IDE tools.

**`IDECommunicator.xojo_code`** — Handles all IDE socket communication. Uses IDE Communicator Protocol v2 over a Unix domain socket (`/tmp/XojoIDE` or `/private/tmp/XojoIDE`). Messages are NUL-terminated JSON. Sends a `{"protocol": 2}` handshake, then uses tag-based correlation for synchronous request/response. Default timeout is 10 seconds; builds use 120 seconds.

**`MCPKit/`** — The MCP protocol framework (8 classes):
- `ServerApplication` — JSON-RPC stdin/stdout loop and tool dispatch
- `Tool` — Base class all 22 tools inherit from
- `ToolParameter`, `ToolArgument`, `ToolResult` — Parameter/result types
- `OptionParser`, `Option`, `OptionException` — CLI argument parsing

**`Tools/`** — 22 tool implementations, each inheriting `MCPKit.Tool` and implementing `Run(args() As MCPKit.ToolArgument) As MCPKit.ToolResult`:
- **16 IDE tools**: list/navigate/read/write project items, build, run, stop, create items, run IDE scripts, get project info, revert, get/set item description, get/set constant value, get/set selected text
- **3 documentation tools**: search docs (guides/tutorials), lookup class (API reference), list topics (operate on cached `llms-full.txt` / `llms.txt`)
- **2 debug tools**: `GetDebugLog` (reads `/tmp/xmcp_debug.log`), `GetSystemLog` (reads macOS unified log via `Shell`)
- **1 cost tool**: `EstimateRequestCost` (static heuristics, no IDE call)

### Tool Implementation Pattern

Every tool follows this structure:

```xojo
Function Run(args() As MCPKit.ToolArgument) As MCPKit.ToolResult
  ' 1. Extract parameters from args
  Var myParam As String = ""
  For Each arg In args
    If arg.Name = "my_param" Then myParam = arg.Value.StringValue
  Next

  ' 2. Build an IDE script string
  Var script As String = "Print SomeIDEFunction()"

  ' 3. Send to IDE and handle response
  Var response As JSONItem = App.IDE.SendAndReceive(script)
  If response = Nil Then
    Return MCPKit.ToolResult.Failure(App.IDE.LastErrorMessage)
  End If

  Return MCPKit.ToolResult.Success(response.Value("response").StringValue)
End Function
```

Documentation tools skip step 3 and operate on the in-memory doc cache instead.

### IDE Script Communication

`IDECommunicator.SendAndReceive(script As String) As JSONItem` sends:
```json
{"tag": "xmcp_1", "script": "Print Location"}
```
And receives:
```json
{"tag": "xmcp_1", "response": "App.Constructor"}
```

The IDE script language is the Xojo IDE Scripting language (not Xojo itself). Scripts use `Print` to return values. Use `RunIDEScript` tool or `mcp__xmcp__run_ide_script` to experiment with scripts interactively.

`DoCommand "RunApp"` and `DoCommand "BuildApp"` are special: they return a `buildError` JSON object directly as the response value (not via `Print`) on failure, or an empty `{}` on success. The `run_project` and `build_project` tools handle this by calling `DoCommand` followed by `Print ""`, then parsing the response value.

`DoCommand "BuildApp"` accepts build type and reveal flag as part of the command string, not as separate comma-separated arguments: `DoCommand "BuildApp 24 True"`. Comma-separated arguments cause a script compiler error.

## Development Notes

- **macOS only** — socket paths, documentation paths, and the Xojo IDE are macOS-specific.
- **Xojo IDE must be open** with a project loaded for IDE tools to work.
- To test changes, rebuild with Xojo IDE, then restart the MCP client session.
- Source files are `.xojo_code` (plain text, one class/module per file) and `.xojo_project` (XML project manifest). These can be edited as plain text or through the IDE.
- Verbose logging to stderr can be enabled with the `-v/--verbose` CLI flag.
- Documentation is auto-detected from versioned paths; the `--docs-path` flag overrides this.
