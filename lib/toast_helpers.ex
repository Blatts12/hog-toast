defmodule HogToast.ToastHelpers do
  @moduledoc false
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
      def create_toast(kind, title, body, duration \\ nil) do
        HogToast.Toast.create_toast(kind, title, body, duration)
      end
    end
  end
end
