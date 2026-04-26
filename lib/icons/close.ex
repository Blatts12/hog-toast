defmodule HogToast.Icons.Close do
  @moduledoc false

  use Hologram.Component

  # https://tabler.io/icons
  # MIT License

  prop :class, :string, default: nil
  prop :style, :string, default: nil

  @impl Hologram.Component
  def template do
    ~HOLO"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
      class={@class}
      style={@style}
    >
      <path stroke="none" d="M0 0h24v24H0z" fill="none" />
      <path d="M18 6l-12 12" />
      <path d="M6 6l12 12" />
    </svg>
    """
  end
end
