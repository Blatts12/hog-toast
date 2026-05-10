# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Keeping docs in sync

When changing how the package works — new props, config options, actions, behaviours, public API — update both `CLAUDE.md` and `README.md` as part of the same change.

## Codebase search

Always use the **cicada MCP** to search this codebase. Prefer its tools (`search_function`, `search_module`, `query`, `git_history`, etc.) over grep or manual file traversal.

## Hologram documentation

- [llms.txt](https://github.com/bartblast/hologram/blob/dev/llms.txt) — index of Hologram docs with links to individual topics
- [llms-full.txt](https://github.com/bartblast/hologram/blob/dev/llms-full.txt) — full Hologram documentation in a single file

## Commands

```bash
mix deps.get          # install dependencies
mix test              # run tests
mix format            # format code (uses Styler plugin)
mix credo --strict    # lint (strict mode is configured as default in .credo.exs)
mix test test/hog_toast_test.exs  # run a single test file
```

## Architecture

`hog_toast` is an Elixir library providing toast/notification components for [Hologram](https://github.com/bartblast/hologram) apps. All components use `use Hologram.Component` and render via `~HOLO` templates.

### Module responsibilities

- **`HogToast.ToastGroup`** — Hologram component that owns the toast list in its state. Identified by a `name` prop which is used to build a stable DOM id (`hog-toast-group-#{name}`). Handles `:hog_add_toast` and `:hog_remove_toast` actions dispatched to that DOM id. Renders child `Toast` components, passing each a zero-based `index` (0 = newest). Accepts a `position` prop (`"top-left"` | `"top-center"` | `"top-right"` | `"bottom-left"` | `"bottom-center"` | `"bottom-right"`, default `"bottom-right"`) and optional `class`/`style` props for the wrapper element.

- **`HogToast.Toast`** — Hologram component for a single toast. On `init`, calls `setup_toast_duration` which injects a `requestAnimationFrame` loop via `JS.exec/1` to animate the duration bar and auto-dismiss. Pause/resume on hover works by recording remaining duration and adjusting the `start` timestamp. Swipe-to-dismiss uses drag events with a damped offset for the "wrong" direction (i.e. directions away from the toast's screen edge resist movement). The rAF loop JS string contains Elixir string interpolation (component IDs, duration, start time) evaluated at action-dispatch time — editing it requires understanding both sides.

- **`HogToast.DurationBar`** — Stateless component rendering the countdown bar `<div>`. Its width is driven entirely by the rAF loop in `Toast`, not by component state.

- **`HogToast.Config`** — Struct for visual configuration. `new!/1` deep-merges user-supplied overrides onto built-in defaults using `Helpers.deep_merge/2`. Supports `stack_type: :stack | :collapse` and per-kind class/role overrides. The `kinds` map is extensible; unknown kinds fall back to the first key (`:default`).

- **`HogToast.ToastHelpers`** — `__using__` macro that injects scoped `add_toast/2`, `remove_toast/2`, and `create_toast/3,4` into a caller module, bound to a fixed group name at compile time.

- **`HogToast.Helpers`** — Internal utilities: `deep_merge/2`, `resolve_styles/2` (flattens config + kind overrides into a `%{toast:, close_button:, icon:, title:, body:, duration_bar:}` map used in templates), `parse_styles/1`, and `falsy?/1`.

- **`HogToast.Icons.Close`** — Internal component rendering the SVG close-button icon. Not part of the public API; only used inside `Toast`'s template.

### Key data flow

1. User calls `add_toast(component, toast)` from an action in their Hologram page/component.
2. `ToastHelpers` delegates to `ToastGroup.add_toast/3`, which calls `put_action/2` targeting the group's DOM id.
3. `ToastGroup` receives `:hog_add_toast`, prepends the toast map to its state, and re-renders — spawning a new `Toast` child.
4. `Toast.init/2` calls `setup_toast_duration`, which starts a client-side rAF loop. Dismissal dispatches `:hog_remove_toast` back to the group.

### Styling

There is no bundled stylesheet. The library emits predictable CSS class names that the consuming app is expected to style:

| Element        | Default class                  |
|----------------|--------------------------------|
| Group wrapper  | `hog-toast-group`              |
| Toast          | `hog-toast`                    |
| Title          | `hog-toast-title`              |
| Body           | `hog-toast-body`               |
| Duration bar   | `hog-toast-duration-bar`       |
| Close button   | `hog-toast-close-button`       |
| Close icon     | `hog-toast-close-button-icon`  |

Per-kind modifier classes (`hog-toast-info`, `hog-toast-warning`, `hog-toast-danger`, `hog-toast-success`) are appended to the toast element. Override or extend any of these via `HogToast.Config.new!/1`. The stacking index is available as the CSS custom property `--idx` on each toast element.

### Testing

The test suite (`test/hog_toast_test.exs`) currently covers only pure Elixir units (helpers, config merging). Hologram component behaviour — rendering, actions, the rAF loop, swipe gestures — must be verified manually against a real Hologram application. When adding new component logic, note what can and cannot be covered by unit tests.

### Formatting

- Line length: 120 characters (configured in `.formatter.exs` and `.credo.exs`)
- Styler is a formatter plugin — `mix format` also enforces style rules

## Cicada MCP reference

Always use the cicada MCP to search this codebase. The tools form a workflow: start with `query`, then drill down with `expand_result`, `search_function`, or `search_module`.

### `query` — start here for every search

The primary entry point for any code discovery. Accepts keywords or module/function patterns and returns ranked results with suggestions for next steps.

```
query("authentication")                          # keyword search
query(["pause", "duration"])                     # multi-keyword
query("HogToast.Toast.create*")                  # pattern match
query("swipe", glob="lib/**/*.ex")               # scoped to a path
query("remove_toast", result_type="functions")   # functions only
query("config", scope="public")                  # public API only
query("toast", recent=true)                      # changed in last 14 days
```

Key parameters:
- `result_type` — `"all"` (default) | `"modules"` | `"functions"`
- `scope` — `"all"` (default) | `"public"` | `"private"`
- `glob` — file glob filter, e.g. `"lib/**"`, `"!**/test/**"`
- `match_source` — `"all"` (default) | `"docs"` | `"strings"` | `"comments"`
- `show_snippets=true` — include code previews in results
- `verbose=true` — full documentation previews

### `expand_result` — drill into any result

After `query` returns something interesting, pass its identifier here. Automatically detects module vs. function.

```
expand_result("HogToast.Toast")                        # expand a module
expand_result("HogToast.Toast.create_toast/4")         # expand a function
expand_result("HogToast.Helpers", what_it_calls=true)  # show dependencies
expand_result("HogToast.ToastGroup", what_calls_it=true, what_it_calls=true)
```

### `search_function` — detailed function analysis

Find a function's definition and all call sites. Supports wildcards and OR patterns.

```
search_function("add_toast")
search_function("create_toast/4")
search_function("HogToast.Toast.create_toast/4")
search_function("add*|remove*")                        # OR pattern
search_function("resolve_styles", include_usage_examples=true)
search_function("action", module_path="HogToast.Toast", what_it_calls=true)
search_function("create_toast", usage_type="tests")    # only test call sites
```

### `search_module` — full module API

Shows all functions with arities, line numbers, signatures, docs, and dependency relationships.

```
search_module(module_name="HogToast.Config")
search_module(module_name="HogToast.*")                # all HogToast modules
search_module(file_path="lib/toast.ex")
search_module(module_name="HogToast.Toast", type="all")          # incl. private
search_module(module_name="HogToast.Helpers", what_calls_it=true) # impact analysis
search_module(module_name="HogToast.Toast", what_it_calls=true, dependency_depth=2)
search_module(module_name="HogToast.Toast", verbose=true)         # with docs + specs
```

### `git_history` — file and function history

```
git_history(file_path="lib/toast.ex")                                 # file PR history
git_history(file_path="lib/toast.ex", start_line=64)                  # who wrote line 64
git_history(file_path="lib/toast.ex", start_line=64, end_line=96)     # range blame
git_history(file_path="lib/toast.ex", function_name="action", show_evolution=true)
git_history(file_path="lib/config.ex", recent=true)                   # last 14 days
git_history(file_path="lib/toast.ex", author="jakub")
```

### `query_jq` — raw index queries

For custom analysis not covered by the other tools. Queries the internal index directly with jq syntax.

```
query_jq(".modules | keys")                                      # list all modules
query_jq(".modules[].functions | length")                        # function count per module
query_jq(".modules | to_entries | map(select(.value.file | test(\"test\")))")  # test files
query_jq(".modules[].functions[] | select(.arity == 2)")         # functions with arity 2
query_jq(".metadata")                                            # index metadata
query_jq(".modules | schema", sample=true)                       # discover field structure
```

### `refresh_index` — update the index after edits

Run after editing files if search results seem stale.

```
refresh_index()                  # incremental (fast, only changed files)
refresh_index(force_full=true)   # full reindex
```
