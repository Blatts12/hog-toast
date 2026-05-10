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
    |> put_state(:pause_duration_left, nil)
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
      toast_cid = cid(component.state.group_name, component.state.toast.id)
      JS.exec(~s|document.getElementById("#{toast_cid}").style.transition = "none";|)

      component
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

        toast_id = component.state.toast.id
        toast_cid = cid(component.state.group_name, toast_id)
        JS.exec(~s|document.getElementById("#{toast_cid}").style.transform = "#{transform}";|)

        component = put_state(component, :swipe_direction, direction)

        if swipe_dir in out_dirs and abs(raw) >= @swipe_out_threshold do
          sign = if raw >= 0, do: 1, else: -1
          out = if direction == "x", do: "translateX(#{sign * 500}px)", else: "translateY(#{sign * 500}px)"
          group_cid = ToastGroup.cid(component.state.group_name)

          JS.exec("""
          const el = document.getElementById("#{toast_cid}");
          el.style.transition = "transform 0.25s ease-in, opacity 0.2s ease-in";
          el.style.transform = "#{out}";
          el.style.opacity = "0";
          setTimeout(() => {
            Hologram.dispatchAction("hog_remove_toast", "#{group_cid}", {id: "#{toast_id}"});
          }, 200);
          """)

          component
          |> put_state(:swiping?, false)
          |> put_state(:dismissed, true)
        else
          component
        end
      end
    else
      component
    end
  end

  def action(:swipe_end, _params, component) do
    if component.state.swiping? do
      toast_cid = cid(component.state.group_name, component.state.toast.id)

      JS.exec("""
      const el = document.getElementById("#{toast_cid}");
      if (el && !el.dataset.dismissed) {
        el.style.transition = "transform 0.4s cubic-bezier(0.34, 1.56, 0.64, 1)";
        el.style.transform = "";
      }
      """)

      component
      |> put_state(:swiping?, false)
      |> put_state(:swipe_start_x, nil)
      |> put_state(:swipe_start_y, nil)
      |> put_state(:swipe_direction, nil)
    else
      component
    end
  end

  def action(:pause, _, component) do
    now = now_unix()
    duration_left = component.state.toast.start + component.state.toast.duration - now

    put_state(component, :pause_duration_left, duration_left)
  end

  def action(:resume, _, component) do
    toast = component.state.toast
    duration_left = component.state.pause_duration_left
    start = now_unix() - diff(toast.duration, duration_left)

    toast = Map.put(toast, :start, start)

    component =
      component
      |> put_state(:pause_duration_left, nil)
      |> put_state(:toast, toast)

    setup_toast_duration(component)

    component
  end

  def action(:remove, _, component) do
    put_state(component, :dismissed, true)
  end

  @impl true
  def template do
    ~HOLO"""
    <div
      id={cid(@group_name, @toast.id)}
      class={@styles[:toast][:class]}
      style={Helpers.parse_styles(["--idx:#{@index};touch-action:none", @styles[:toast][:style]])}
      role={toast_role(@config, @toast.kind)}
      data-idx={@index}
      data-paused={is_integer(@pause_duration_left) and @pause_duration_left > 0}
      data-dismissed={@dismissed}
      onmouseenter={"Hologram.dispatchAction('pause', '#{cid(@group_name, @toast.id)}')"}
      onmouseleave={"Hologram.dispatchAction('resume', '#{cid(@group_name, @toast.id)}')"}
      onpointerdown="this.setPointerCapture(event.pointerId)"
      $pointer_down="swipe_start"
      $pointer_move="swipe_move"
      $pointer_up="swipe_end"
      $pointer_cancel="swipe_end"
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
        if (!toast || toast.dataset.paused || toast.dataset.dismissed) return;

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

  def diff(nil, _), do: 0
  def diff(_, nil), do: 0
  def diff(a, b), do: a - b

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
