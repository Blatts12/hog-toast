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
  @swipe_return_step 3

  prop :group_name, :string
  prop :position, :any

  prop :index, :integer, default: nil
  prop :toast, :map
  prop :config, :map

  def init(props, component) do
    styles = Helpers.resolve_styles(props.config, props.toast.kind)

    component =
      component
      |> put_state(:styles, styles)
      |> put_state(:toast, props.toast)
      |> put_state(:group_name, props.group_name)
      |> put_state(:position, props.position)
      |> put_state(:pause_duration_left, nil)
      |> put_state(:pointer_start, {nil, nil})
      |> put_state(:swipe_direction, nil)
      |> put_state(:swipe_offset, nil)

    if duration?(props.toast) do
      put_action(component, :setup_toast_duration)
    else
      component
    end
  end

  def action(:setup_toast_duration, _, component) do
    toast = component.state.toast
    group_name = component.state.group_name

    bar_id = DurationBar.bar_id(group_name, toast.id)
    group_cid = ToastGroup.cid(group_name)
    toast_cid = cid(group_name, toast.id)

    JS.exec("""
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    function tick() {
      const toast = document.getElementById("#{toast_cid}");
      if (!toast || toast.dataset.paused) return;
      const bar = document.getElementById("#{bar_id}");
      const elapsed = Date.now() - #{toast.start};
      if (elapsed >= #{toast.duration}) {
        if (bar && !reducedMotion) bar.style.width = "0%";
        Hologram.dispatchAction("hog_remove_toast", "#{group_cid}", {id: "#{toast.id}"});
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

    component
  end

  def action(:pause, _, component) do
    now = now_unix()
    duration_left = component.state.toast.start + component.state.toast.duration - now

    put_state(component, :pause_duration_left, duration_left)
  end

  def action(:resume, _, component) do
    toast = component.state.toast
    duration_left = component.state.pause_duration_left
    start = now_unix() - (toast.duration - duration_left)

    toast = Map.put(toast, :start, start)

    component
    |> put_state(:pause_duration_left, nil)
    |> put_state(:toast, toast)
    |> put_action(:setup_toast_duration)
  end

  def action(:swipe_start, event, component) do
    JS.call(event, :preventDefault, [])

    blank = JS.new(:Image, [])
    data_transfer = JS.get(event, :dataTransfer)
    JS.call(data_transfer, :setDragImage, [blank, 0, 0])

    x = JS.get(event, :clientX)
    y = JS.get(event, :clientY)

    put_state(component, :pointer_start, {x, y})
  end

  def action(:swipe_end, _params, component) do
    component
    |> put_state(:pointer_start, {nil, nil})
    |> put_state(:swipe_direction, nil)
    |> put_state(:swipe_offset, nil)
  end

  def action(:swipe, event, component) do
    JS.call(event, :preventDefault, [])

    {x, y} = component.state.pointer_start
    dx = JS.get(event, :clientX) - x
    dy = JS.get(event, :clientY) - y

    {direction, component} =
      case component.state.swipe_direction do
        nil ->
          direction = if abs(dx) > abs(dy), do: "x", else: "y"
          {direction, put_state(component, :swipe_direction, direction)}

        direction ->
          {direction, component}
      end

    out_dirs = position_to_out_dirs(component.state.position)

    if direction == "x" do
      put_state(component, :swipe_offset, damp_offset(dx, "x", out_dirs))
    else
      put_state(component, :swipe_offset, damp_offset(dy, "y", out_dirs))
    end
  end

  def action(:swipe_return, _params, component) do
    swipe_offset = component.state.swipe_offset

    new_offset =
      if swipe_offset <= 0 do
        min(0, swipe_offset + @swipe_return_step)
      else
        max(0, swipe_offset - @swipe_return_step)
      end

    if new_offset == 0 do
      put_action(component, :swipe_end)
    else
      group_name = component.state.group_name
      toast_id = component.state.toast.id

      JS.exec("""
      requestAnimationFrame(() => {
        Hologram.dispatchAction('swipe_return', '#{cid(group_name, toast_id)}');
      })
      """)

      put_state(component, :swipe_offset, new_offset)
    end
  end

  @impl true
  def template do
    ~HOLO"""
    <div
      id={cid(@group_name, @toast.id)}
      class={@styles[:toast][:class]}
      style={Helpers.parse_styles([
        "--idx:#{@index}",
        swipe_style(@swipe_direction, @swipe_offset),
        @styles[:toast][:style]])
      }
      role={toast_role(@config, @toast.kind)}
      data-idx={@index}
      data-paused={is_integer(@pause_duration_left) and @pause_duration_left > 0}
      onmouseenter={"Hologram.dispatchAction('pause', '#{cid(@group_name, @toast.id)}')"}
      onmouseleave={"Hologram.dispatchAction('resume', '#{cid(@group_name, @toast.id)}')"}
      draggable="true"
      ondragstart={"Hologram.dispatchAction('swipe_start', '#{cid(@group_name, @toast.id)}', event)"}
      ondragend={"Hologram.dispatchAction('swipe_return', '#{cid(@group_name, @toast.id)}')"}
      ondrag={"Hologram.dispatchAction('swipe', '#{cid(@group_name, @toast.id)}', event)"}
    >

      <button
        $click={action: :hog_remove_toast, target: ToastGroup.cid(@group_name), params: %{id: @toast.id}}
        class={@styles[:close_button][:class]}
        style={@styles[:close_button][:style]}
        aria-label={close_button_label(@toast)}
      >
        <Icons.Close
          class={@styles[:icon][:class]}
          style={@styles[:icon][:style]}
        />
      </button>

      <p
        class={@styles[:title][:class]}
        style={@styles[:title][:style]}
      >{@toast.title} - {@swipe_direction}, {@swipe_offset}</p>
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

  defp duration?(toast) do
    duration = Map.get(toast, :duration)
    is_integer(duration) and duration > 0
  end

  defp toast_role(config, kind) do
    kinds = Map.get(config, :kinds, %{})
    kind = Helpers.get_proper_kind(kinds, kind)

    get_in(kinds, [kind, :role]) || "status"
  end

  defp swipe_style("y", offset), do: "transform:translateY(#{offset}px)"
  defp swipe_style("x", offset), do: "transform:translateX(#{offset}px)"
  defp swipe_style(_, _), do: nil

  defp position_to_out_dirs({"top", "center"}), do: ["up"]
  defp position_to_out_dirs({"top", horizontal}), do: ["up", horizontal]
  defp position_to_out_dirs({"bottom", "center"}), do: ["down"]
  defp position_to_out_dirs({"bottom", horizontal}), do: ["down", horizontal]

  defp damp_offset(offset, axis, out_dirs) do
    dir =
      case axis do
        "y" -> if offset <= 0, do: "up", else: "down"
        "x" -> if offset <= 0, do: "left", else: "right"
      end

    if dir in out_dirs do
      if offset <= 0,
        do: max(-@swipe_out_max, offset),
        else: min(@swipe_out_max, offset)
    else
      offset = offset * 0.1

      if offset <= 0,
        do: max(-@swipe_in_max, offset),
        else: min(@swipe_in_max, offset)
    end
  end

  @type toast_id() :: String.t()
  @type duration() :: non_neg_integer() | nil
  @type kind() :: atom()
  @type title() :: String.t()
  @type body() :: String.t()
  @typedoc "Unix timestamp in milliseconds"
  @type start() :: pos_integer()

  @type toast() :: %{
          required(:id) => toast_id(),
          required(:kind) => kind(),
          optional(:title) => title(),
          optional(:body) => body(),
          optional(:duration) => duration(),
          required(:start) => start()
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
      start: now_unix()
    }
  end

  defp generate_toast_id, do: to_string(System.unique_integer())
  defp now_unix, do: DateTime.to_unix(DateTime.utc_now(), :millisecond)
end
