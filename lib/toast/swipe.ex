defmodule HogToast.Toast.Swipe do
  @moduledoc false

  alias HogToast.Helpers
  alias HogToast.ToastGroup
  alias Hologram.Component

  @swipe_in_max 16
  @swipe_out_threshold 120
  @swipe_out_max 360

  @spec swipe_move(component :: Component.t(), toast_id :: String.t(), event :: map()) :: Component.t()
  def swipe_move(component, toast_id, event) do
    toasts = component.state.toasts
    toast = Enum.find(toasts, &(&1.id == toast_id))

    handle_swipe_move(component, toast, event)
  end

  defp handle_swipe_move(component, nil, _event), do: component
  defp handle_swipe_move(component, %{state: %{swiping?: false}}, _event), do: component

  defp handle_swipe_move(component, toast, event) do
    dx = event.client_x - toast.state.swipe_start_x
    dy = event.client_y - toast.state.swipe_start_y
    direction = toast.state.swipe_direction || determine_direction(dx, dy)

    if is_nil(direction) or toast.state.dismissed? do
      component
    else
      raw = if direction == "x", do: dx, else: dy
      swipe_dir = swipe_direction(raw, direction)
      {vertical, horizontal} = component.state.position
      out_dirs = position_to_out_dirs(vertical, horizontal)
      offset = damp_offset(raw, direction, out_dirs)
      transform = if direction == "x", do: "translateX(#{offset}px)", else: "translateY(#{offset}px)"

      toast =
        toast
        |> update_state(:swipe_direction, direction)
        |> update_style(:transform, transform)

      toast =
        if swipe_dir in out_dirs and abs(raw) >= @swipe_out_threshold do
          sign = if raw >= 0, do: 1, else: -1
          out = if direction == "x", do: "translateX(#{sign * 500}px)", else: "translateY(#{sign * 500}px)"

          toast
          |> update_style(:transition, "transform 0.25s ease-in, opacity 0.2s ease-in")
          |> update_style(:transform, out)
          |> update_style(:opacity, "0")
          |> update_state(:swiping?, false)
          |> update_state(:dismissed?, true)
        else
          toast
        end

      component
      |> replace_toast(toast)
      |> dismiss_toast(toast)
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

  defp position_to_out_dirs("top", "center"), do: ["up"]
  defp position_to_out_dirs("top", h), do: ["up", h]
  defp position_to_out_dirs("bottom", "center"), do: ["down"]
  defp position_to_out_dirs("bottom", h), do: ["down", h]

  def swipe_start(component, toast_id, event) do
    toasts = component.state.toasts
    toast = Enum.find(toasts, &(&1.id == toast_id))

    handle_swipe_start(component, toast, event)
  end

  defp handle_swipe_start(component, nil, _event), do: component
  defp handle_swipe_start(component, %{state: %{dismissed?: true}}, _event), do: component

  defp handle_swipe_start(component, toast, event) do
    toast =
      toast
      |> update_style(:transition, "none")
      |> update_state(:swiping?, true)
      |> update_state(:swipe_start_x, event.client_x)
      |> update_state(:swipe_start_y, event.client_y)
      |> update_state(:swipe_direction, nil)

    replace_toast(component, toast)
  end

  def swipe_end(component, toast_id, event) do
    toasts = component.state.toasts
    toast = Enum.find(toasts, &(&1.id == toast_id))

    handle_swipe_end(component, toast, event)
  end

  defp handle_swipe_end(component, nil, _event), do: component
  defp handle_swipe_end(component, %{state: %{swiping?: false}}, _event), do: component
  defp handle_swipe_end(component, %{state: %{dismissed?: true}}, _event), do: component

  defp handle_swipe_end(component, toast, _event) do
    toast =
      toast
      |> update_style(:transition, "transform 0.4s cubic-bezier(0.34, 1.56, 0.64, 1)")
      |> update_style(:transform, nil)
      |> update_state(:swiping?, false)
      |> update_state(:swipe_start_x, nil)
      |> update_state(:swipe_start_y, nil)
      |> update_state(:swipe_direction, nil)

    replace_toast(component, toast)
  end

  defp update_style(toast, key, value) do
    styles = Map.put(toast.styles, key, value)
    Map.put(toast, :styles, styles)
  end

  defp update_state(toast, key, value) do
    state = Map.put(toast.state, key, value)
    Map.put(toast, :state, state)
  end

  defp replace_toast(component, %{id: id} = toast) do
    toasts = Helpers.find_and_replace(component.state.toasts, &(&1.id == id), toast)
    Component.put_state(component, :toasts, toasts)
  end

  defp dismiss_toast(component, %{id: id, state: %{dismissed?: true}}) do
    Component.put_action(component,
      name: :hog_remove_toast,
      target: ToastGroup.cid(component.state.name),
      params: %{id: id},
      delay: 200
    )
  end

  defp dismiss_toast(component, _toast), do: component
end
