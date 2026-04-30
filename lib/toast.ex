defmodule HogToast.Toast do
  @moduledoc false

  use Hologram.Component
  use Hologram.JS

  alias HogToast.DurationBar
  alias HogToast.Helpers
  alias HogToast.Icons
  alias HogToast.ToastGroup

  prop :toast, :map
  prop :group_name, :string
  prop :config, :map

  def init(props, component) do
    styles = Helpers.resolve_styles(props.config, props.toast.kind)
    component = put_state(component, :styles, styles)

    if duration?(props.toast) do
      put_action(
        component,
        :setup_toast_duration,
        toast: props.toast,
        group_name: props.group_name
      )
    else
      component
    end
  end

  def action(:setup_toast_duration, %{toast: toast, group_name: group_name}, component) do
    bar_id = DurationBar.bar_id(group_name, toast.id)
    group_cid = ToastGroup.cid(group_name)

    JS.exec("""
    function tick() {
      const bar = document.getElementById("#{bar_id}");
      if (!bar) return;
      const elapsed = Date.now() - #{toast.start};
      if (elapsed >= #{toast.duration}) {
        bar.style.width = "0%";
        Hologram.dispatchAction("hog_remove_toast", "#{group_cid}", {id: "#{toast.id}"});
        return;
      }

      const fraction = Math.max(0, 1 - elapsed / #{toast.duration});
      bar.style.width = `${fraction * 100}%`;
      requestAnimationFrame(tick);
    }
    requestAnimationFrame(tick);
    """)

    component
  end

  @impl true
  def template do
    ~HOLO"""
    <div
      id={cid(@group_name, @toast.id)}
      class={@styles[:toast][:class]}
      style={@styles[:toast][:style]}
      role={toast_role(@config, @toast.kind)}
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
