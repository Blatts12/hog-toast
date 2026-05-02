defmodule HogToast.ToastGroup do
  @moduledoc false

  use Hologram.Component

  alias HogToast.Config
  alias HogToast.Toast

  prop :name, :string
  prop :config, :map, default: %Config{}
  prop :toasts, :list, default: []

  def init(props, component, server) do
    component =
      component
      |> put_state(:toasts, props.toasts)
      |> put_state(:config, props.config)
      |> put_state(:name, props.name)

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

  @impl true
  def template do
    ~HOLO"""
    <div
      id={cid(@name)}
      class={@config.group[:class]}
      style={@config.group[:style]}
      role="region"
      aria-label="Notifications"
      aria-live="polite"
      aria-atomic="false"
      aria-relevant="additions"
    >
      {%for {toast, index} <- @toasts |> Enum.reverse() |> Enum.with_index()}
        <Toast
          cid={Toast.cid(@name, toast.id)}
          index={index}
          toast={toast}
          group_name={@name}
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
end
