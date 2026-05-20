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

  @swipe_in_max 16
  @swipe_out_threshold 120
  @swipe_out_max 360

  prop :group_name, :string
  prop :position, :any

  prop :index, :integer, default: nil
  prop :toast, :map
  prop :config, :map

  def init(props, component) do
    styles = Helpers.resolve_styles(props.config, props.toast.kind)

    component
    |> put_state(:styles, styles)
    |> put_state(:toast, props.toast)
    |> put_state(:group_name, props.group_name)
    |> put_state(:position, props.position)
    |> put_state(:index, props.index)
    |> put_state(:dismissed, false)
    |> put_state(:swiping?, false)
    |> put_state(:swipe_start_x, nil)
    |> put_state(:swipe_start_y, nil)
    |> put_state(:swipe_direction, nil)
    |> put_action(:setup_toast)
  end

  def action(:setup_toast, _, component) do
    setup_toast_duration(component)
    component
  end

  def action(:swipe_start, params, component) do
    if component.state.dismissed do
      component
    else
      component
      |> update_style(:transition, "none")
      |> put_state(:swiping?, true)
      |> put_state(:swipe_start_x, params.event.client_x)
      |> put_state(:swipe_start_y, params.event.client_y)
      |> put_state(:swipe_direction, nil)
    end
  end

  def action(:swipe_move, params, component) do
    if component.state.swiping? do
      dx = params.event.client_x - component.state.swipe_start_x
      dy = params.event.client_y - component.state.swipe_start_y
      direction = component.state.swipe_direction || determine_direction(dx, dy)

      if is_nil(direction) or component.state.dismissed do
        component
      else
        raw = if direction == "x", do: dx, else: dy
        swipe_dir = swipe_direction(raw, direction)
        {vertical, horizontal} = component.state.position
        out_dirs = position_to_out_dirs(vertical, horizontal)
        offset = damp_offset(raw, direction, out_dirs)
        transform = if direction == "x", do: "translateX(#{offset}px)", else: "translateY(#{offset}px)"

        component =
          component
          |> put_state(:swipe_direction, direction)
          |> update_style(:transform, transform)

        if swipe_dir in out_dirs and abs(raw) >= @swipe_out_threshold do
          sign = if raw >= 0, do: 1, else: -1
          out = if direction == "x", do: "translateX(#{sign * 500}px)", else: "translateY(#{sign * 500}px)"

          component
          |> update_style(:transition, "transform 0.25s ease-in, opacity 0.2s ease-in")
          |> update_style(:transform, out)
          |> update_style(:opacity, "0")
          |> put_state(:swiping?, false)
          |> put_state(:dismissed, true)
          |> put_action(name: :remove, delay: 200)
        else
          component
        end
      end
    else
      component
    end
  end

  def action(:swipe_end, _params, component) do
    if component.state.swiping? and not component.state.dismissed do
      component
      |> update_style(:transition, "transform 0.4s cubic-bezier(0.34, 1.56, 0.64, 1)")
      |> update_style(:transform, nil)
      |> put_state(:swiping?, false)
      |> put_state(:swipe_start_x, nil)
      |> put_state(:swipe_start_y, nil)
      |> put_state(:swipe_direction, nil)
    else
      component
    end
  end

  def action(:remove, _, component) do
    group_cid = ToastGroup.cid(component.state.group_name)

    component
    |> put_state(:dismissed, true)
    |> put_action(
      name: :hog_remove_toast,
      target: group_cid,
      params: %{id: component.state.toast.id}
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
        @toast[:style],
        @styles[:toast][:style]
      ])}
      role={toast_role(@config, @toast.kind)}
      data-paused={is_integer(@toast.pause_duration_left) and @toast.pause_duration_left > 0}
      data-dismissed={@dismissed}
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
        $click="remove"
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

      <p style="font-size: 0.6em">start: {@toast.start}</p>
      <p style="font-size: 0.6em">duration: {@toast.duration}</p>
      <p style="font-size: 0.6em">pause_duration_left: {@toast.pause_duration_left}</p>

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

  defp setup_toast_duration(component) do
    toast = component.state.toast
    group_name = component.state.group_name

    if duration?(toast) do
      bar_id = DurationBar.bar_id(group_name, toast.id)
      toast_cid = cid(group_name, toast.id)
      group_cid = ToastGroup.cid(group_name)

      JS.exec("""
      const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

      function tick() {
        const toast = document.getElementById("#{toast_cid}");
        if (!toast) return;

        if (toast.dataset.paused) {
          requestAnimationFrame(tick);
          return;
        }

        if (toast.dataset.dismissed) return;

        const bar = document.getElementById("#{bar_id}");
        const elapsed = Date.now() - #{toast.start};

        if (elapsed >= #{toast.duration}) {
          if (bar && !reducedMotion) bar.style.width = "0%";
          Hologram.dispatchAction("hog_remove_toast", "#{group_cid}", { id: "#{toast.id}" });
          return;
        }

        if (bar && !reducedMotion) {
          const fraction = Math.max(0, 1 - elapsed / #{toast.duration});
          bar.style.width = `${fraction * 100}%`;
        }

        requestAnimationFrame(tick);
      }

      requestAnimationFrame(tick);
      """)
    end
  end

  defp determine_direction(dx, dy) when abs(dx) > 5 or abs(dy) > 5 do
    if abs(dx) > abs(dy), do: "x", else: "y"
  end

  defp determine_direction(_, _), do: nil

  defp swipe_direction(raw, "x") when raw >= 0, do: "right"
  defp swipe_direction(_raw, "x"), do: "left"
  defp swipe_direction(raw, "y") when raw >= 0, do: "down"
  defp swipe_direction(_raw, "y"), do: "up"

  defp damp_offset(raw, direction, out_dirs) do
    sign = if raw >= 0, do: 1, else: -1
    dir = swipe_direction(raw, direction)

    if dir in out_dirs do
      sign * min(abs(raw), @swipe_out_max)
    else
      sign * min(abs(raw) * 0.1, @swipe_in_max)
    end
  end

  defp close_button_label(toast) do
    if toast.title do
      "Dismiss #{toast.title}"
    else
      "Dismiss notification"
    end
  end

  defp duration?(toast) do
    duration = Map.get(toast, :duration)
    is_integer(duration) and duration > 0
  end

  defp toast_role(config, kind) do
    kinds = Map.get(config, :kinds, %{})
    kind = Helpers.get_proper_kind(kinds, kind)

    get_in(kinds, [kind, :role]) || "status"
  end

  defp position_to_out_dirs("top", "center"), do: ["up"]
  defp position_to_out_dirs("top", h), do: ["up", h]
  defp position_to_out_dirs("bottom", "center"), do: ["down"]
  defp position_to_out_dirs("bottom", h), do: ["down", h]

  @type toast_id() :: String.t()
  @type duration() :: non_neg_integer() | nil
  @type kind() :: atom()
  @type title() :: String.t()
  @type body() :: String.t()
  @type styles() :: map()
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
          optional(:styles) => styles()
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
      pause_duration_left: nil,
      styles: %{
        transition: nil,
        transform: nil,
        opacity: nil
      }
    }
  end

  defp generate_toast_id, do: to_string(System.unique_integer())
  defp now_unix, do: DateTime.to_unix(DateTime.utc_now(), :millisecond)

  defp update_style(component, key, value) do
    toast = component.state.toast
    styles = Map.put(toast.styles, key, value)
    toast = Map.put(toast, :styles, styles)

    put_state(component, :toast, toast)
  end
end
