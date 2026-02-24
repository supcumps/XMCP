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

## Direct File Editing Fallback (for development and testing)

Some items in a Xojo project cannot be accessed via the IDE scripting API. The workaround is to edit source files directly on disk and use `revert_project` to reload.

**When this is needed:**
- Window event handlers (`Window1.Opening`, `Window1.Close`, etc.) — these live in `.xojo_window` files and are invisible to IDE scripting
- Any situation where `get_code`/`set_code` returns "No code editor is active" for a known-valid item

**Workflow:**
1. Edit the `.xojo_code` or `.xojo_window` file directly as plain text
2. Call `revert_project` (or `DoCommand "Revert"` in an IDE script) to reload the project

**File structure reference:**
- `src/<ClassName>.xojo_code` — class, module, or app-level code
- `src/<WindowName>.xojo_window` — window UI, controls, and event handlers
- `src/XMCP.xojo_project` — project manifest (XML)
- `src/usage-guide.md` — the MCP resource distributed next to the binary

## usage-guide.md

`usage-guide.md` is XMCP's self-awareness layer. It is distributed next to the XMCP binary at build time and exposed via the MCP `resources` protocol (`resources/list` / `resources/read`). Compatible clients like Claude Code fetch it automatically at session start.

The file gives the AI immediate context about:
- What XMCP can and cannot do
- Known IDE scripting API limitations and their workarounds
- The direct file editing fallback workflow
- Correct `.xojo_window` event handler format
- Debug logging behavior (debug vs. built apps)

**To update AI guidance without rebuilding:** edit `src/usage-guide.md` directly — the binary reads it from disk at runtime from the same directory as the executable. When distributing XMCP, place `usage-guide.md` next to the binary.

## App.UnhandledException pattern

When building a Xojo app with XMCP, add this event to `App` to enable `get_debug_log` crash reporting. Note: only fires in built apps — the Xojo debugger intercepts exceptions during debug sessions.

```xojo
#tag Event
	Sub UnhandledException(error As RuntimeException)
	  Var msg As String = "Error: " + error.Message + EndOfLine
	  msg = msg + "Error Number: " + Str(error.ErrorNumber) + EndOfLine
	  If error.Stack <> Nil Then
	    msg = msg + "Stack:" + EndOfLine
	    For Each frame As String In error.Stack
	      msg = msg + "  " + frame + EndOfLine
	    Next
	  End If

	  Var f As New FolderItem("/tmp/xmcp_debug.log")
	  Var stream As TextOutputStream = TextOutputStream.Open(f)
	  stream.Write(msg)
	  stream.Close
	End Sub
#tag EndEvent
```

Add this directly to `App.xojo_code` before the `#tag ViewBehavior` section, then call `revert_project` to reload.
