defmodule HogToast.Toast do
  @moduledoc """
  Hologram component that renders a single toast notification.

  Handles the full lifecycle of an individual toast: initializing resolved
  styles, scheduling the countdown animation via `setup_toast_duration`, and
  managing pause/resume state when the user hovers over the toast.

  Use `create_toast/4` to build a toast map, then hand it to
  `HogToast.ToastGroup.add_toast/3` (or the scoped helpers injected by
  `HogToast.ToastHelpers`) to display it.

  ## Stacking index

  Each toast receives a zero-based `index` prop from `ToastGroup` (0 = newest).
  The value is exposed both as `data-idx` and as the CSS custom property
  `--idx` on the root element, so you can drive stacking animations purely in
  CSS:

      .hog-toast { transform: translateY(calc(var(--idx) * 0.5rem)); }
  """

  use Hologram.Component
  use Hologram.JS

  alias HogToast.DurationBar
  alias HogToast.Helpers
  alias HogToast.Icons
  alias HogToast.ToastGroup

  prop :group_name, :string
  prop :position, :any

  prop :index, :integer, default: nil
  prop :toast, :map
  prop :config, :map

  @impl true
  def init(props, component) do
    styles = Helpers.resolve_styles(props.config, props.toast.kind)

    component
    |> put_state(:styles, styles)
    |> put_state(:toast_id, props.toast.id)
    |> put_state(:group_name, props.group_name)
    |> put_action(:setup_toast)
  end

  @impl true
  def action(:setup_toast, _, component) do
    toast_id = component.state.toast_id
    group_name = component.state.group_name

    put_action(component,
      name: :init_toast,
      target: ToastGroup.cid(group_name),
      params: %{id: toast_id}
    )
  end

  def action(:swipe_start, %{event: event}, component) do
    toast_id = component.state.toast_id
    group_name = component.state.group_name

    put_action(component,
      name: :swipe_start,
      target: ToastGroup.cid(group_name),
      params: %{id: toast_id, event: event}
    )
  end

  def action(:swipe_move, %{event: event}, component) do
    toast_id = component.state.toast_id
    group_name = component.state.group_name

    put_action(component,
      name: :swipe_move,
      target: ToastGroup.cid(group_name),
      params: %{id: toast_id, event: event}
    )
  end

  def action(:swipe_end, %{event: event}, component) do
    toast_id = component.state.toast_id
    group_name = component.state.group_name

    put_action(component,
      name: :swipe_end,
      target: ToastGroup.cid(group_name),
      params: %{id: toast_id, event: event}
    )
  end

  @impl true
  def template do
    ~HOLO"""
    <div
      id={cid(@group_name, @toast.id)}
      class={@styles[:toast][:class]}
      style={Helpers.parse_styles([
        "--idx:#{@index};touch-action:none",
        @toast[:styles],
        @styles[:toast][:style]
      ])}
      role={toast_role(@config, @toast.kind)}
      data-paused={is_integer(@toast.state.pause_duration_left) and @toast.state.pause_duration_left > 0}
      data-dismissed={@toast.state.dismissed?}
      onpointerdown="this.setPointerCapture(event.pointerId)"
      $pointer_down="swipe_start"
      $pointer_move="swipe_move"
      $pointer_up="swipe_end"
      $pointer_cancel="swipe_end"
    >
      <button
        class={@styles[:close_button][:class]}
        style={@styles[:close_button][:style]}
        aria-label={close_button_label(@toast)}
        onpointerdown="event.stopPropagation()"
        $click={name: :hog_remove_toast, target: ToastGroup.cid(@group_name), params: %{id: @toast.id}}
      >
        <Icons.Close
          class={@styles[:icon][:class]}
          style={@styles[:icon][:style]}
        />
      </button>

      <p
        class={@styles[:title][:class]}
        style={@styles[:title][:style]}
      >{@toast.title}</p>
      <p
        class={@styles[:body][:class]}
        style={@styles[:body][:style]}
      >{@toast.body}</p>

      <DurationBar
        group_name={@group_name}
        toast={@toast}
        styles={@styles}
      />
    </div>
    """
  end

  @spec cid(name :: String.t(), id :: toast_id()) :: term()
  def cid(group_name, id), do: "hog-toast-#{group_name}-#{id}"

  defp close_button_label(toast) do
    if toast.title do
      "Dismiss #{toast.title}"
    else
      "Dismiss notification"
    end
  end

  defp toast_role(config, kind) do
    kinds = Map.get(config, :kinds, %{})
    kind = Helpers.get_proper_kind(kinds, kind)

    get_in(kinds, [kind, :role]) || "status"
  end

  @type toast_id() :: String.t()
  @type duration() :: non_neg_integer() | nil
  @type kind() :: atom()
  @type title() :: String.t()
  @type body() :: String.t()
  @type styles() :: map()
  @type state() :: map()
  @typedoc "Unix timestamp in milliseconds"
  @type start() :: pos_integer()

  @type toast() :: %{
          required(:id) => toast_id(),
          required(:kind) => kind(),
          optional(:title) => title(),
          optional(:body) => body(),
          optional(:duration) => duration(),
          required(:start) => start(),
          optional(:pause_duration_left) => duration(),
          required(:state) => state(),
          required(:styles) => styles()
        }

  @spec create_toast(
          kind :: kind(),
          title :: title(),
          body :: body(),
          duration :: duration()
        ) :: toast()
  def create_toast(kind, title, body, duration) do
    %{
      id: generate_toast_id(),
      kind: kind,
      title: title,
      body: body,
      duration: duration,
      start: now_unix(),
      state: %{
        pause_duration_left: nil,
        dismissed?: false,
        swiping?: false,
        swipe_start_x: nil,
        swipe_start_y: nil,
        swipe_direction: nil
      },
      styles: %{
        transition: nil,
        transform: nil,
        opacity: nil
      }
    }
  end

  defp generate_toast_id, do: to_string(System.unique_integer())
  defp now_unix, do: DateTime.to_unix(DateTime.utc_now(), :millisecond)
end
