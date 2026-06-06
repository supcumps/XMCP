# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

XMCP is an MCP (Model Context Protocol) server written in **Xojo** that gives AI assistants direct control over the Xojo IDE. It communicates via stdin/stdout JSON-RPC (MCP protocol) and forwards IDE commands via a Unix domain socket to the running Xojo IDE process.

## Building

This is a **Xojo native application** — there is no Makefile, npm, or shell-based build system.

- **Project file**: `src/XMCP.xojo_project`
- **Build**: Open the project in Xojo IDE and use Build > Build
- **Output**: `src/Builds - XMCP/macOS ARM 64 bit/XMCP/` — contains the `XMCP` binary, `usage-guide.md`, and `examples/`
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

**`App.xojo_code`** — Entry point. Registers all 22 tools in `Configure()`, auto-detects the Xojo documentation path under `~/Library/Application Support/Xojo/`, initializes `IDECommunicator` and optionally `SemanticSearch`. The global `App.IDE` instance is used by all IDE tools; `App.SemanticSearch` is used by `SearchDocs` when available.

**`IDECommunicator.xojo_code`** — Handles all IDE socket communication. Uses IDE Communicator Protocol v2 over a Unix domain socket (`/tmp/XojoIDE` or `/private/tmp/XojoIDE`). Messages are NUL-terminated JSON. Sends a `{"protocol": 2}` handshake, then uses tag-based correlation for synchronous request/response. Default timeout is 10 seconds; builds use 120 seconds.

**`MCPKit/`** — The MCP protocol framework (8 classes):
- `ServerApplication` — JSON-RPC stdin/stdout loop and tool dispatch
- `Tool` — Base class all 22 tools inherit from
- `ToolParameter`, `ToolArgument`, `ToolResult` — Parameter/result types
- `OptionParser`, `Option`, `OptionException` — CLI argument parsing

**`SemanticSearch.xojo_code`** — Optional semantic search provider. Initialized at startup if `xojo_rag.db` exists in `DocsPath` and the embedding server at `http://localhost:8089/v1/embeddings` responds. Probed once at startup; `App.SemanticSearch` is `Nil` when unavailable (zero overhead). Uses async `URLConnection` + `DoEvents` loop, `SQLiteDatabase`, and cosine similarity over float32 blobs.

**`Tools/`** — 22 tool implementations, each inheriting `MCPKit.Tool` and implementing `Run(args() As MCPKit.ToolArgument) As MCPKit.ToolResult`:
- **16 IDE tools**: list/navigate/read/write project items, build, run, stop, create items, run IDE scripts, get project info, revert, get/set item description, get/set constant value, get/set selected text
- **3 documentation tools**: search docs (guides/tutorials), lookup class (API reference), list topics (operate on cached `llms-full.txt` / `llms.txt`)
- **2 debug tools**: `GetDebugLog` (reads `/tmp/xmcp_debug.log`), `GetSystemLog` (reads macOS unified log via `Shell`)
- **1 cost tool**: `EstimateRequestCost` (static heuristics, no IDE call)

### Semantic search

`SearchDocs` automatically uses semantic search when both conditions are met at startup:

1. `DocsPath/xojo_rag.db` exists — the RAG database built by the XMCP-RAG indexer
2. The embedding server is running at `http://localhost:8089/v1/embeddings` (llama.cpp with `nomic-embed-text`)

If either is absent, `search_docs` falls back to keyword search transparently. The AI sees the same tool name and output format either way.

The RAG database must be placed in the same directory as `llms-full.txt` (i.e. `DocsPath`). To build it, run the XMCP-RAG indexer with the embedding server running.

**SemanticSearch pipeline (current implementation):**

1. **Embed query** — HTTP POST to `mEmbeddingUrl`; returns float32 MemoryBlock.
2. **Vector search** — SELECT all rows from `embeddings JOIN chunks`; compute cosine similarity for each.
3. **FTS5 hybrid** — SELECT top 200 from `chunks_fts MATCH ?`; normalise BM25 scores to [0,1]; combine: `final = 0.7×cosine + 0.3×fts`. Falls back to vector-only if `chunks_fts` is absent (old DB).
4. **Partial selection sort** — find top `maxResults×2` candidates by combined score.
5. **Deduplication** — skip chunks from the same `source` whose score is within 0.04 of the previous chunk from that source (avoids returning near-identical sections).
6. **Neighbour expansion** — for chunks with cosine score ≥ 0.72, fetch `prev_id` and `next_id` from the DB and include them (context window expansion).
7. **Logical sort** — group results by `source`, ordered by best score; sort chunks within each source group by `chunk_index` ascending.
8. **Cache** — result string stored in `mCache` (Dictionary, max 50 entries, full clear on overflow).

**Performance:**
- `mDB` is a persistent `SQLiteDatabase` held open for the process lifetime (no reconnect per query).
- WAL mode (`PRAGMA journal_mode=WAL`), 256 MB mmap (`PRAGMA mmap_size`), 64 MB page cache (`PRAGMA cache_size=-65536`) applied at startup.
- Cache (`mCache`) prevents redundant vector scoring for repeated queries within a session.

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

`DoCommand "RunApp"` and `DoCommand "BuildApp"` are special: they return a `buildError` JSON object directly as the response value (not via `Print`) on failure, or `{}` on success. Both `run_project` and `build_project` call the no-argument `DoCommand` form followed by `Print ""`, then parse the response value. `DoCommand "BuildApp"` uses the IDE's configured Build Settings (`BuildMac`, `BuildWin32`, etc.).

The `BuildApp(buildType, reveal)` function form exists for IDE scripts that need to build a specific target (returns the build path as a string). Valid `buildType` values: 3=Win32, 4=Linux32, 9=macOS Universal, 16=macOS, 17=Linux64, 18=LinuxARM32, 19=Win64, 24=macOSARM, 25=WinARM64, 26=LinuxARM64. Invalid values (e.g. 0) produce no build and return an empty string.

**Do not** use `DoCommand "BuildApp 24 True"` — `DoCommand "BuildApp"` is the no-argument form and silently ignores trailing tokens.

## Development Notes

- **macOS only** — socket paths, documentation paths, and the Xojo IDE are macOS-specific.
- **Xojo IDE must be open** with a project loaded for IDE tools to work.
- To test changes, rebuild with Xojo IDE, then restart the MCP client session.
- Source files are `.xojo_code` (plain text, one class/module per file) and `.xojo_project` (key/value text format project manifest). These can be edited as plain text or through the IDE.
- Verbose logging to stderr can be enabled with the `-v/--verbose` CLI flag.
- Documentation is auto-detected from versioned paths; the `--docs-path` flag overrides this.

## Direct File Editing (primary approach)

Edit source files directly on disk and use `revert_project` to reload. This is the primary way to edit Xojo project code — not a fallback.

**Always edit directly on disk for:**
- All `.xojo_code` files (classes, modules, app-level code)
- Window event handlers (`Window1.Opening`, `Window1.Close`, etc.) — these live in `.xojo_window` files and are invisible to IDE scripting

**Workflow:**
1. Edit the `.xojo_code` or `.xojo_window` file directly as plain text
2. Call `revert_project` (or `DoCommand "Revert"` in an IDE script) to reload the project

**File structure reference:**
- `src/<ClassName>.xojo_code` — class, module, or app-level code
- `src/<WindowName>.xojo_window` — window UI, controls, and event handlers
- `src/XMCP.xojo_project` — project manifest (key/value text format)
- `src/usage-guide.md` — the MCP resource distributed next to the binary
- `src/examples/` — reference templates for common Xojo file structures (`App.xojo_code`, `Module1.xojo_code`, `MyClass.xojo_code`, `MyButton.xojo_code`, `Window1.xojo_window`); copy from these when creating new project files

## usage-guide.md

`usage-guide.md` is XMCP's self-awareness layer. It is distributed next to the XMCP binary at build time and exposed via the MCP `resources` protocol (`resources/list` / `resources/read`). Compatible clients like Claude Code fetch it automatically at session start.

The file gives the AI immediate context about:
- What XMCP can and cannot do
- Known IDE scripting API limitations and their workarounds
- When to use IDE tools vs. direct file editing (window files always use direct editing)
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
