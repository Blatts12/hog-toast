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

  prop :index, :integer, default: nil
  prop :toast, :map
  prop :group_name, :string
  prop :config, :map

  def init(props, component) do
    styles = Helpers.resolve_styles(props.config, props.toast.kind)

    component =
      component
      |> put_state(:styles, styles)
      |> put_state(:toast, props.toast)
      |> put_state(:group_name, props.group_name)
      |> put_state(:pause_duration_left, nil)

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

  @impl true
  def template do
    ~HOLO"""
    <div
      id={cid(@group_name, @toast.id)}
      class={@styles[:toast][:class]}
      style={Helpers.parse_styles(["--idx:#{@index}", @styles[:toast][:style]])}
      role={toast_role(@config, @toast.kind)}
      data-idx={@index}
      data-paused={is_integer(@pause_duration_left) and @pause_duration_left > 0}
      onmouseenter={"Hologram.dispatchAction('pause', '#{cid(@group_name, @toast.id)}')"}
      onmouseleave={"Hologram.dispatchAction('resume', '#{cid(@group_name, @toast.id)}')"}
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
