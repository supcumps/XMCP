# XMCP Usage Guide for AI Assistants

This file is automatically loaded as an MCP resource when you connect to XMCP. It describes XMCP's capabilities, known limitations, and fallback strategies. You can edit this file to add project-specific notes or customise the guidance.

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
- **Cost estimation**: `estimate_request_cost`

---

## Known limitations of the IDE scripting API

### 1. Cannot navigate to method-level items with `select_project_item`

The Xojo IDE scripting API (`SelectProjectItem`) can navigate to top-level items, classes, modules, and windows — but **not** to individual methods, properties, or event implementations within them.

**Symptom**: `select_project_item` returns `ERROR: Could not select 'Window1.Button1.Pressed'. The IDE scripting API cannot navigate to method-level items...`

**Solution**: Use `get_code` or `set_code` with the full dot-separated path. These tools navigate automatically before reading or writing.

```
get_code(location: "Window1.Button1.Pressed")   ✓
set_code(code: "...", location: "App.MyMethod") ✓
select_project_item(item_path: "Window1.Button1.Pressed") ✗
```

### 2. Window event handlers cannot be accessed via IDE tools

Window event handlers (e.g. `Window1.Opening`, `Window1.Close`, `Window1.Resized`) live in `.xojo_window` files and cannot be read or written through the IDE scripting API.

**Symptom**: `get_code` or `set_code` returns `ERROR: Could not navigate to: Window1.Opening`

**Solution**: Edit the `.xojo_window` file directly on disk (see fallback workflow below).

### 3. Parallel tool calls are not supported

The Xojo IDE accepts only one IPC connection at a time. If the MCP client sends parallel tool calls, some will fail with connection errors.

**Solution**: Always use sequential tool calls when working with XMCP.

### 4. IPC socket timing after navigation

After certain navigation operations, the Xojo IDE briefly closes its IPC socket (~2–3 seconds). XMCP retries automatically (up to 5 × 1 second), so most calls recover. If a tool times out immediately after navigation, retry once.

---

## Fallback: direct file editing

When IDE tools cannot access an item, edit the source files directly on disk and reload the project.

### Step-by-step

1. **Find the project directory**
   Call `get_project_info` — it returns a `Project Directory:` line with the full path to the folder containing all source files.

2. **Find the right file**
   - Each class, module, or app-level code is one `.xojo_code` file (named after the class)
   - Window UI and event handlers are in `.xojo_window` files (one per window)
   - The project manifest is `<ProjectName>.xojo_project` (XML — edit sparingly)

3. **Edit the file directly**
   Use standard file read/write tools. The `.xojo_code` format is plain text with `#tag` markers. Follow the existing structure exactly.

4. **Reload in the IDE**
   Call `revert_project` to reload all changed files from disk into the IDE.

### When to use direct file editing

| Situation | Use direct editing? |
|-----------|-------------------|
| Window event handler (Opening, Close, Resized, etc.) | Yes — always |
| `select_project_item` fails for a method path | No — use `get_code`/`set_code` with path instead |
| `get_code` fails with "No code editor is active" | Yes — item may not be a code item |
| Adding a new method to an existing class | Either — IDE tools or direct editing both work |
| Modifying window layout or controls | Yes — edit `.xojo_window` directly |

---

## Tips for working effectively with XMCP

- Call `get_project_info` early to understand the project structure and get the directory path
- Use `list_project_items` to explore the project tree before navigating
- Use `run_ide_script` to run arbitrary IDE scripting commands when no dedicated tool exists
- After a crash or unexpected termination, call `get_debug_log` to retrieve exception details
- Add an `App.UnhandledException` handler to your Xojo project that writes to `/tmp/xmcp_debug.log` for automatic crash logging

---

*This file can be edited to add project-specific notes, custom conventions, or additional guidance for your AI assistant.*
