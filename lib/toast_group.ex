defmodule HogToast.ToastGroup do
  @moduledoc """
  Hologram component that renders and manages a named group of toast notifications.

  Place `<ToastGroup name="my-group" />` in your layout or page template.
  Toasts are stacked in insertion order (newest first) and each one is rendered
  as a `HogToast.Toast` child component.

  ## Props

  - `name` — unique string identifier for this group; must match the `name`
    passed to `HogToast.ToastHelpers`.
  - `config` — optional `HogToast.Config` struct for custom styling.
  - `toasts` — optional initial list of toast maps (defaults to `[]`).

  ## Actions

  - `:hog_add_toast` — adds a toast map to the front of the list.
  - `:hog_remove_toast` — removes a toast by its `id`.
  """

  use Hologram.Component
  use Hologram.JS

  alias HogToast.Config
  alias HogToast.Helpers
  alias HogToast.Toast

  @positions ~w(top-left top-center top-right bottom-left bottom-center bottom-right)
  @default_position "bottom-right"

  prop :name, :string
  prop :position, :string, default: @default_position

  prop :class, [:string, :list], default: nil
  prop :style, :string, default: nil

  prop :config, :map, default: %Config{}
  prop :toasts, :list, default: []

  def init(props, component, server) do
    position = parse_position(props.position)
    [vertical, horizontal] = String.split(position, "-")

    component =
      component
      |> put_state(:toasts, props.toasts)
      |> put_state(:config, props.config)
      |> put_state(:name, props.name)
      |> put_state(:position, {vertical, horizontal})

    {component, server}
  end

  def action(:hog_add_toast, %{toast: toast}, component) do
    new_toasts = [toast | component.state.toasts]
    put_state(component, :toasts, new_toasts)
  end

  def action(:hog_remove_toast, %{id: toast_id}, component) do
    new_toasts = Enum.reject(component.state.toasts, &(&1.id == toast_id))
    put_state(component, :toasts, new_toasts)
  end

  def action(:pause, _, component) do
    js =
      Enum.map_join(component.state.toasts, ";", fn %{id: toast_id} ->
        "Hologram.dispatchAction('pause', '#{Toast.cid(component.state.name, toast_id)}')"
      end)

    JS.exec(js)

    component
  end

  def action(:resume, _, component) do
    js =
      Enum.map_join(component.state.toasts, ";", fn %{id: toast_id} ->
        "Hologram.dispatchAction('resume', '#{Toast.cid(component.state.name, toast_id)}')"
      end)

    JS.exec(js)

    component
  end

  @impl true
  def template do
    ~HOLO"""
    <div
      id={cid(@name)}
      class={Helpers.parse_styles([@class])}
      style={Helpers.parse_styles([position_to_style(@position), @style])}
      role="region"
      aria-label="Notifications"
      aria-live="polite"
      aria-atomic="false"
      aria-relevant="additions"
      onmouseenter={"Hologram.dispatchAction('pause', '#{cid(@name)}')"}
      onmouseleave={"Hologram.dispatchAction('resume', '#{cid(@name)}')"}
    >
      <slot />
      {%for {toast, index} <- parse_toasts(@toasts, @position)}
        <Toast
          cid={Toast.cid(@name, toast.id)}
          group_name={@name}
          position={@position}
          index={index}
          toast={toast}
          config={@config}
        />
      {/for}
    </div>
    """
  end

  @spec cid(name :: String.t()) :: String.t()
  def cid(name), do: "hog-toast-group-#{name}"

  @spec add_toast(Config.cs(), name :: String.t(), toast :: Toast.toast()) :: Config.cs()
  def add_toast(cs, name, toast) do
    put_action(cs, name: :hog_add_toast, target: cid(name), params: %{toast: toast})
  end

  @spec remove_toast(Config.cs(), name :: String.t(), toast_id :: Toast.toast_id()) :: Config.cs()
  def remove_toast(cs, name, toast_id) do
    put_action(cs, name: :hog_remove_toast, target: cid(name), params: %{id: toast_id})
  end

  defp parse_position(nil), do: @default_position
  defp parse_position(position) when is_atom(position), do: position |> Atom.to_string() |> parse_position()
  defp parse_position(position) when position in @positions, do: position
  defp parse_position(_), do: @default_position

  defp parse_toasts(toasts, {vertical, _}) do
    toasts =
      case vertical do
        "top" -> Enum.reverse(toasts)
        "bottom" -> toasts
      end

    Enum.with_index(toasts)
  end

  defp position_to_style({vertical, horizontal}) do
    base_style = "position:fixed;"

    style =
      case vertical do
        "top" -> "#{base_style}top:0;"
        "bottom" -> "#{base_style}bottom:0;"
      end

    case horizontal do
      "left" -> "#{style}left:0"
      "center" -> "#{style}left:50%;transform:translateX(-50%)"
      "right" -> "#{style}right:0"
    end
  end
end
