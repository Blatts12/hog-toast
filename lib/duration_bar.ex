defmodule HogToast.DurationBar do
  @moduledoc """
  Hologram component that renders the animated countdown bar for a toast.

  Rendered as a visually decorative `<div>` (`aria-hidden="true"`).  Its width
  is driven by the `requestAnimationFrame` loop started in `HogToast.Toast`.
  """

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
      aria-hidden="true"
    />
    """
  end

  @spec bar_id(name :: String.t(), id :: Toast.toast_id()) :: String.t()
  def bar_id(group_name, toast_id), do: "hog-toast-#{group_name}-#{toast_id}-bar"
end
