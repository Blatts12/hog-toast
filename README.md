# HogToast

A toast/notification component library for [Hologram](https://github.com/bartblast/hologram) apps. Supports multiple toast kinds, auto-dismiss with a countdown bar, pause/resume on hover, and full accessibility via ARIA attributes.

## Installation

Add `hog_toast` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:hog_toast, "~> 0.1.0"}
  ]
end
```

## Usage

### 1. Add a toast group to your component

Place `HogToast.ToastGroup` in your template where toasts should appear:

```elixir
<HogToast.ToastGroup name="main" />
```

The `name` uniquely identifies the group — use it when adding or removing toasts.

### 2. Wire up the helper module

Use `HogToast.ToastHelpers` in your component to get scoped helper functions:

```elixir
defmodule MyApp.Page do
  use Hologram.Page
  use HogToast.ToastHelpers, name: "main"

  # Generates:
  #   add_toast/2    — adds a toast to the group
  #   remove_toast/2 — removes a toast by id
  #   create_toast/3 — builds a toast map (kind, title, body)
  #   create_toast/4 — builds a toast map with custom duration (ms)
end
```

### 3. Show a toast

Call `add_toast/2` from any action, passing the component reference and a toast map:

```elixir
def action(:save, _params, component) do
  toast = create_toast(:success, "Saved", "Your changes have been saved.")
  add_toast(component, toast)
end
```

`create_toast/3` defaults to a 4000 ms auto-dismiss duration. Pass a fourth argument to override:

```elixir
# No auto-dismiss
create_toast(:info, "Tip", "Hover a toast to pause its timer.", nil)

# 8 second dismiss
create_toast(:warning, "Heads up", "Session expires soon.", 8_000)
```

### Toast kinds

The built-in kinds are `:default`, `:info`, `:success`, `:warning`, and `:danger`. You can also define any custom kind by adding it to the `kinds` map in your config, then using that atom in `create_toast`:

```elixir
HogToast.Config.new!(%{
  kinds: %{
    promo: %{class: "bg-purple-800 ring-purple-500"}
  }
})

# Then show it:
create_toast(:promo, "New feature", "Check out what's new.")
```

If a toast's kind is not found in the config, it falls back to `:default`.

Each kind accepts a `role` key that sets the ARIA `role` on the toast element (defaults to `"status"`). Use `"alert"` for urgent messages that should interrupt the user:

```elixir
kinds: %{
  danger:   %{class: "bg-danger-800",  role: "alert"},
  critical: %{class: "bg-red-950",     role: "alert"},
  info:     %{class: "bg-info-800"}   # role defaults to "status"
}
```

## Styling

### Default class names

`HogToast.ToastGroup` ships with a default `%Config{}` that applies class names to every element — no styles are included, giving you full control:

| Element           | Default class                 |
| ----------------- | ----------------------------- |
| Group container   | `hog-toast-group`             |
| Toast             | `hog-toast`                   |
| Toast title       | `hog-toast-title`             |
| Toast body        | `hog-toast-body`              |
| Duration bar      | `hog-toast-duration-bar`      |
| Close button      | `hog-toast-close-button`      |
| Close button icon | `hog-toast-close-button-icon` |
| Info kind         | `hog-toast-info`              |
| Success kind      | `hog-toast-success`           |
| Warning kind      | `hog-toast-warning`           |
| Danger kind       | `hog-toast-danger`            |

You can target these in your own stylesheet, or use the slot to inject a scoped style block (see below).

### Tailwind — using `Config.new!`

Pass a config built with `Config.new!` to override classes for each element and kind. User-supplied values are deep-merged on top of the defaults, so you only need to specify what you want to change:

```elixir
defp toast_group_config do
  HogToast.Config.new!(%{
    group: %{
      class: "fixed bottom-2 right-6 z-50 flex flex-col-reverse gap-2"
    },
    toast: %{
      class: [
        "w-sm relative ring-2 rounded overflow-hidden shadow",
        "transition-all duration-300 ease-in-out"
      ],
      title: %{class: "text-md font-semibold px-2 py-1"},
      body: %{class: "pb-2 text-sm px-2"},
      duration_bar: %{class: "h-1 bg-white/40"},
      close_button: %{
        class: "absolute top-0.5 right-0.5 p-1 hover:bg-black/30 cursor-pointer rounded",
        icon: %{class: "size-5"}
      }
    },
    kinds: %{
      default: %{class: "bg-purple-800 ring-purple-500"},
      success: %{class: "bg-emerald-800 ring-emerald-500"},
      warning: %{class: "bg-amber-800 ring-amber-500"},
      danger: %{class: "bg-rose-800 ring-rose-500"},
      info: %{class: "bg-blue-800 ring-blue-500"}
    }
  })
end
```

Then pass it to the group:

```elixir
<HogToast.ToastGroup name="main" config={toast_group_config()} />
```

You can also use the `style` key anywhere a `class` key is accepted to pass inline CSS strings instead of class names:

```elixir
HogToast.Config.new!(%{
  group: %{style: "position: fixed; bottom: 0.5rem; right: 1.5rem;"}
})
```

### Scoped styles via the slot

`HogToast.ToastGroup` exposes a slot rendered inside the group container. You can use it to inject a `<style>` block that targets the default BEM class names, keeping toast styles co-located with the group and avoiding global stylesheet pollution:

```elixir
<HogToast.ToastGroup name="main">
  <style scope>{%raw}
    .hog-toast-group {
      position: fixed;
      bottom: 0.5rem;
      right: 1.5rem;
      z-index: 50;
      display: flex;
      flex-direction: column-reverse;
      gap: 0.5rem;
    }

    .hog-toast {
      width: 24rem;
      position: relative;
      outline: 2px solid transparent;
      border-radius: 0.25rem;
      overflow: hidden;
      box-shadow: 0 1px 3px 0 rgb(0 0 0 / 0.1);
      transition: all 300ms ease-in-out;
    }

    .hog-toast-title {
      font-size: 1rem;
      font-weight: 600;
      padding: 0.25rem 0.5rem;
    }

    .hog-toast-body {
      font-size: 0.875rem;
      padding: 0 0.5rem 0.5rem;
    }

    .hog-toast-duration-bar {
      height: 0.25rem;
      background-color: rgb(255 255 255 / 0.4);
    }

    .hog-toast-close-button {
      position: absolute;
      top: 0.125rem;
      right: 0.125rem;
      padding: 0.25rem;
      border-radius: 0.25rem;
      cursor: pointer;
    }

    .hog-toast-close-button:hover {
      background-color: rgb(0 0 0 / 0.3);
    }

    .hog-toast-close-button-icon {
      width: 1.25rem;
      height: 1.25rem;
    }

    .hog-toast-info    { background-color: hsl(220 100% 35%); outline-color: hsl(220 100% 60%); }
    .hog-toast-success { background-color: hsl(120 100% 25%); outline-color: hsl(120 100% 45%); }
    .hog-toast-warning { background-color: hsl(40 100% 30%); outline-color: hsl(40 100% 55%); }
    .hog-toast-danger  { background-color: hsl(10 100% 35%); outline-color: hsl(10 100% 60%); }
  {/raw)</style>
</HogToast.ToastGroup>
```

## Accessibility

- The group renders as `role="region"` with `aria-live="polite"` and `aria-atomic="false"` so screen readers announce new toasts without interrupting the user.
- `:danger` toasts use `role="alert"` for immediate announcement.
- Close buttons include an `aria-label` derived from the toast title.
- Duration bar animations are skipped when `prefers-reduced-motion` is enabled.

## License

MIT
