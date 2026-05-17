# XMCP Usage Guide for AI Assistants

This file is automatically loaded as an MCP resource when you connect to XMCP. It describes XMCP's capabilities, known limitations, and how to choose the right approach for each task. You can edit this file to add project-specific notes or customise the guidance.

---

## Prerequisites — before using any XMCP tools

**XMCP cannot start Xojo IDE.** All tools communicate via a macOS domain socket (`/tmp/XojoIDE`) that Xojo IDE creates when it launches. If the IDE is not running, every tool call will fail with "IPC socket not found".

**The user must:**

1. Start Xojo IDE manually
2. Open the project they want to work with (File > Open) — XMCP cannot open projects
3. Wait a few seconds after launch before the IPC socket is ready — if tools fail immediately after IDE start, ask the user to wait and retry

**Do not attempt any XMCP tool calls until the user confirms that Xojo IDE is open and the project is loaded.**

---

## What XMCP can do

XMCP gives you direct control over the Xojo IDE via 22 tools:

- **Navigate**: `list_project_items`, `get_current_location`, `select_project_item`
- **Read/write code**: `get_code`, `set_code`, `get_selected_text`, `set_selected_text`
- **Build and run**: `build_project`, `run_project`, `stop_project`
- **Create items**: `create_project_item`
- **Inspect and modify**: `get_item_description`, `constant_value`, `get_project_info`, `revert_project`
- **IDE scripting**: `run_ide_script` (escape hatch for anything not covered)
- **Documentation**: `search_docs`, `lookup_class`, `list_doc_topics`
- **Debugging**: `get_debug_log`, `get_system_log`
- **Cost estimation**: `estimate_request_cost` — call this proactively before broad or documentation-heavy tasks to check whether the approach is likely to be expensive, and to get suggestions for cheaper alternatives

---

## Starting work on a new project — recommended first steps

When you connect to a new Xojo project via XMCP:

1. Call `get_project_info` to confirm the IDE is connected and get the project directory path
2. Check whether `App` already has an `UnhandledException` handler (see below)
3. **If not, proactively offer to add it** — this is essential for diagnosing crashes in built apps

---

## Crash reporting — add UnhandledException to App

In built apps, runtime exceptions are silent unless you add an `UnhandledException` handler. Without it, crashes produce no output visible to XMCP.

Add this to `App.xojo_code` (before the `#tag ViewBehavior` section):

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

After adding, ask the user for permission to call `revert_project` to reload the project.

Once in place, use `get_debug_log` after a crash **in a built app** to retrieve the full exception message and stack trace. Without this handler, `get_debug_log` will always return empty — there is nothing to log.

**`UnhandledException` does NOT fire in debug mode.** The Xojo debugger intercepts all exceptions before they reach this handler — they appear in the IDE debugger instead. This handler is only useful in built apps.

**The log file is not cleared automatically.** It may contain data from a previous crash rather than the current one. Always call `get_debug_log` with `clear: true` after reading, so the next crash produces a fresh log.

---

## How to edit code

**Always edit source files directly on disk** — for both `.xojo_code` and `.xojo_window` files. Do not use `get_code` or `set_code` to write code.

The only exception is when the user explicitly asks you to read or edit code they have selected in the IDE. In that case, `get_code` and `set_code` without a location parameter work reliably. After writing with `set_code`, always remind the user to save the project (Cmd+S) — `set_code` writes to the IDE editor but does not save to disk.

---

## Direct file editing — how to do it

Reference examples of all common file structures are in the `examples/` folder next to this file. Use them as templates when creating or editing `.xojo_code` and `.xojo_window` files.

1. **Find the project directory**
   Call `get_project_info` — it returns a `Project Directory:` line with the full path.

2. **Find the right file**
   - Classes, modules, app-level code → `<ClassName>.xojo_code`
   - Window UI, controls, and event handlers → `<WindowName>.xojo_window`
   - Project manifest → `<ProjectName>.xojo_project` (key/value text format — edit sparingly)

3. **Edit the file**
   `.xojo_code` and `.xojo_window` are plain text with `#tag` markers. Follow the existing structure exactly.

   Window-level event handlers go in `#tag WindowCode`:

   ```xojo
   #tag WindowCode
       #tag Event
           Sub Opening()
             ' your code here
           End Sub
       #tag EndEvent
   #tag EndWindowCode
   ```

   Control event handlers (e.g. a `DesktopButton`'s `Pressed` event) go in a `#tag Events ControlName` block *after* `#tag EndWindowCode`:

   ```xojo
   #tag Events Button1
       #tag Event
           Sub Pressed()
             MessageBox("Hi")
           End Sub
       #tag EndEvent
   #tag EndEvents
   ```

4. **Reload in the IDE**
   Ask the user for permission, then call `revert_project`. The user may see a confirmation prompt in the IDE — they need to accept it.

---

## IDE tool limitations to be aware of

### Never use `DoCommand "Insert..."` to add controls to windows

Using `DoCommand "Insert..."` commands (e.g. `DoCommand "InsertDesktopButton"`) to add UI controls to a window **disconnects the Xojo IDE's IPC socket**, making all subsequent XMCP tool calls fail until the IDE is restarted.

Always add controls by editing the `.xojo_window` file directly on disk instead. Use `examples/Window1.xojo_window` as a reference for the correct control block format and event handler structure.

### `select_project_item` cannot navigate to methods or events

The IDE scripting API can navigate to top-level items, classes, modules, and windows — but not to individual methods, properties, or event implementations. Edit the source file directly on disk instead.

`list_project_items` also does not list events — only methods, properties, and constants appear as children.

### Documentation tools — use search_docs and lookup_class, not list_doc_topics

- `search_docs` — search guides and tutorials by keyword. Use this first.
- `lookup_class` — look up a specific class or method in the API reference.
- `list_doc_topics` — returns the full documentation index (143,000+ characters). **Never call this to find information** — it wastes tokens and requires multiple slow read passes. Use `search_docs` instead. Only call `list_doc_topics` if the user explicitly asks for a topic overview.

### IDE scripting quirks (run_ide_script)

- `SelectProjectItem` returns a Boolean — always capture the return value: `Dim r As Boolean = SelectProjectItem("Window1")`
- `GetProjectItem` does not exist in the IDE scripting language — using it causes a compile error
- Avoid declaring variables as `ProjectItem` — it is a method name in the scripting language, not a type

### Parallel tool calls are not supported

The Xojo IDE accepts only one IPC connection at a time. Always use sequential tool calls.

### IPC socket timing after navigation

After certain navigation operations, the IDE briefly closes its IPC socket (~2–3 seconds). XMCP retries automatically. If a tool times out immediately after navigation, retry once.

---

## Running and building — rules and workflow

### Never act without explicit user request

- **Never call `build_project` unless the user explicitly asks you to build**
- **Never call `run_project` unless the user explicitly asks you to run**
- **Never call `revert_project` without asking the user first** — it discards all unsaved changes in the IDE

Always wait for the user's answer before proceeding. Asking a question and then acting anyway defeats the purpose.

### Recommended workflow when the user asks to build

1. **Offer to run first**: Before building, offer to call `run_project` to catch syntax errors. **Note:** Runtime errors will only be visible to the user in the Xojo IDE debugger — not to XMCP.
2. **Run and ask for feedback**: After `run_project` returns, always ask the user if they see any errors or exceptions in the IDE — XMCP cannot see runtime behaviour in debug mode.
3. **Only build if run succeeds** — or if the user explicitly wants to build anyway.

### What run_project and build_project can and cannot see

| | `run_project` | `build_project` |
| --- | --- | --- |
| Syntax errors | ✓ Returns error | ✓ Returns error |
| Runtime exceptions (debug mode) | ✗ Invisible — IDE debugger catches them | — |
| Runtime exceptions (built app) | — | ✗ Invisible without `UnhandledException` |
| Build output on disk | — | ✓ Verify `.app` exists after build |

**After `run_project` returns "Project launched in debug mode"**: always ask the user if the app is behaving correctly and if they see any exceptions in the IDE debugger.

**Note:** `run_project` catches syntax errors. Runtime exceptions are visible to the user in the Xojo IDE debugger — but not to XMCP.

### build_project uses the IDE's Build Settings

`build_project` takes no parameters — it builds using whatever target platforms the user has configured in the IDE's Build Settings (`BuildMac`, `BuildWin32`, etc.). On success it returns "Build succeeded."; on failure it returns the list of build errors. The success message does not include a path, so to confirm the build location, check the project's `Builds - <ProjectName>/` directory.

### Debug mode vs. built app — exception visibility

| Scenario | Exceptions visible to XMCP? | Where to look |
| --- | --- | --- |
| `run_project` (debug mode) | No | User sees them in Xojo IDE debugger |
| Built app with `UnhandledException` | Yes — via `get_debug_log` | `/tmp/xmcp_debug.log` |
| Built app without `UnhandledException` | No | Nowhere — add the handler |

---

## Tips for working effectively with XMCP

- Call `get_project_info` early to understand the project structure and get the directory path
- Use `list_project_items` to explore the project tree before navigating
- Use `run_ide_script` to run arbitrary IDE scripting commands when no dedicated tool exists
- Use `get_system_log` to retrieve `System.DebugLog` output — works for both debug builds (`AppName.debug`) and built apps (`AppName`)

---

*This file can be edited to add project-specific notes, custom conventions, or additional guidance for your AI assistant.*
