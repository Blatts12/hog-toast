defmodule HogToast.DurationBar do
  @moduledoc """
  Hologram component that renders the animated countdown bar for a toast.

  Rendered as a visually decorative `<div>` (`aria-hidden="true"`). Its width
  is driven by the `requestAnimationFrame` loop started in `HogToast.Toast`.
  """

  use Hologram.Component
  use Hologram.JS

  alias HogToast.Toast
  alias HogToast.ToastGroup

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

  @spec setup(group_name :: String.t(), toast :: map()) :: term()
  def setup(group_name, toast) do
    if duration?(toast) do
      bar_id = bar_id(group_name, toast.id)
      toast_cid = Toast.cid(group_name, toast.id)
      group_cid = ToastGroup.cid(group_name)

      JS.exec("""
      const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

      function tick() {
        const toast = document.getElementById("#{toast_cid}");
        if (!toast) return;
        if (toast.dataset.paused) return;
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

  defp duration?(toast) do
    duration = Map.get(toast, :duration)
    is_integer(duration) and duration > 0
  end
end
