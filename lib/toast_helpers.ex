defmodule HogToast.ToastHelpers do
  @moduledoc """
  Macro that injects scoped toast helper functions into a Hologram component or server.

  ## Usage

      use HogToast.ToastHelpers, name: "my-group"

  This injects three functions bound to the named `ToastGroup`:

  - `add_toast/2` — dispatches `:hog_add_toast` to the group component.
  - `remove_toast/2` — dispatches `:hog_remove_toast` to the group component.
  - `create_toast/3,4` — builds a toast map (duration defaults to 4 000 ms).

  The `name` option must match the `name` prop passed to the corresponding
  `<ToastGroup />` in the template.
  """

  defmacro __using__(opts) do
    name = opts[:name] || raise "Missing `name` option"

    quote do
      @hog_toast_group_name unquote(name)

      @spec add_toast(
              component :: HogToast.ToastGroup.cs(),
              toast :: HogToast.Toast.toast()
            ) :: HogToast.ToastGroup.cs()
      def add_toast(cs, toast) do
        HogToast.ToastGroup.add_toast(cs, @hog_toast_group_name, toast)
      end

      @spec remove_toast(
              component :: HogToast.ToastGroup.cs(),
              toast_id :: HogToast.Toast.toast_id()
            ) :: HogToast.ToastGroup.cs()
      def remove_toast(cs, toast_id) do
        HogToast.ToastGroup.remove_toast(cs, @hog_toast_group_name, toast_id)
      end

      @spec create_toast(
              kind :: HogToast.Toast.kind(),
              title :: HogToast.Toast.title(),
              body :: HogToast.Toast.body(),
              duration :: HogToast.Toast.duration()
            ) :: HogToast.Toast.toast()
      def create_toast(kind, title, body, duration \\ 4000) do
        HogToast.Toast.create_toast(kind, title, body, duration)
      end
    end
  end
end
