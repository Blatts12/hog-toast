defmodule HogToast.Helpers do
  @moduledoc false

  alias HogToast.Config

  @spec deep_merge(map(), map()) :: map()
  def deep_merge(left, right) do
    Map.merge(left, right, &deep_resolve/3)
  end

  defp deep_resolve(_key, %{} = left, %{} = right) do
    deep_merge(left, right)
  end

  defp deep_resolve(_key, _left, right) do
    right
  end

  @elements [:toast, :close_button, :icon, :title, :body, :duration_bar]

  @spec resolve_styles(Config.t(), kind :: atom()) :: map()
  def resolve_styles(config, kind) do
    toast = Map.get(config, :toast, %{})
    kinds = Map.get(config, :kinds, %{})
    kind = get_proper_kind(kinds, kind)

    Map.new(@elements, fn key ->
      {key, get_element_styles(toast, kinds, kind, key)}
    end)
  end

  defp get_element_styles(toast, kinds, kind, element_key) do
    {base, override} =
      case element_key do
        :toast ->
          {toast, Map.get(kinds, kind, %{})}

        :icon ->
          {
            get_in(toast, [:close_button, :icon]) || %{},
            get_in(kinds, [kind, :close_button, :icon]) || %{}
          }

        key ->
          {Map.get(toast, key, %{}), get_in(kinds, [kind, key]) || %{}}
      end

    %{
      class: parse_classes([base[:class], override[:class]]),
      style: parse_styles([base[:style], override[:style]])
    }
  end

  @spec get_proper_kind(map(), atom()) :: atom()
  def get_proper_kind(kinds, kind) do
    if Map.has_key?(kinds, kind),
      do: kind,
      else: kinds |> Map.keys() |> List.first()
  end

  defp parse_classes(classes) when is_binary(classes) do
    case String.trim(classes) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp parse_classes([nested_classes]), do: parse_classes(nested_classes)

  defp parse_classes([_ | _] = classes) do
    classes
    |> Enum.map(&parse_classes/1)
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      classes -> Enum.join(classes, " ")
    end
  end

  defp parse_classes(_), do: nil

  @spec parse_styles([term()]) :: String.t() | nil
  def parse_styles(styles) do
    styles
    |> Enum.reject(&falsy?/1)
    |> case do
      [] -> nil
      styles -> Enum.join(styles, ";")
    end
  end

  @spec falsy?(term()) :: boolean()
  def falsy?(nil), do: true
  def falsy?(""), do: true
  def falsy?(%{type: :object}), do: false
  def falsy?(%{type: :undefined}), do: true
  def falsy?(map) when is_map(map), do: Enum.empty?(map)
  def falsy?(list) when is_list(list), do: Enum.empty?(list)
  def falsy?(_), do: false

  @spec truthy?(term()) :: boolean()
  def truthy?(term), do: not falsy?(term)
end
