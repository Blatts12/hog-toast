defmodule HogToast.DurationBar do
  @moduledoc false

  use Hologram.Component

  alias HogToast.Toast

  prop :group_name, :string
  prop :toast, :map
  prop :styles, :map

  @impl true
  def template do
    ~HOLO"""
    <div
      id={bar_id(@group_name, @toast.id)}
      class={@styles[:duration_bar][:class]}
      style={@styles[:duration_bar][:style]}
    />
    """
  end

  @spec bar_id(name :: String.t(), id :: Toast.toast_id()) :: String.t()
  def bar_id(group_name, toast_id), do: "hog-toast-#{group_name}-#{toast_id}-bar"
end
