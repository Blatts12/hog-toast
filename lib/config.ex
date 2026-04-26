defmodule HogToast.Config do
  @moduledoc false

  alias HogToast.Helpers

  defstruct group: %{class: "hog-toast-group"},
            toast: %{
              class: "hog-toast",
              title: %{class: "hog-toast-title"},
              body: %{class: "hog-toast-body"},
              duration_bar: %{class: "hog-toast-duration-bar"},
              close_button: %{
                class: "hog-toast-close-button",
                icon: %{class: "hog-toast-close-button-icon"}
              }
            },
            kinds: %{
              default: %{},
              info: %{class: "hog-toast-info"},
              warning: %{class: "hog-toast-warning"},
              danger: %{class: "hog-toast-danger"},
              success: %{class: "hog-toast-success"}
            }

  @type cs() :: Hologram.Component.t() | Hologram.Server.t() | map()

  @type class :: binary() | nil
  @type classes :: [class() | classes()]

  @typep part() :: %{
           optional(:class) => class() | classes(),
           optional(:style) => String.t()
         }

  @typep group() :: part()

  @typep close_button() :: %{
           optional(:class) => class() | classes(),
           optional(:style) => String.t(),
           optional(:icon) => part()
         }

  @typep toast() :: %{
           optional(:class) => class() | classes(),
           optional(:style) => String.t(),
           optional(:title) => part(),
           optional(:body) => part(),
           optional(:duration_bar) => part(),
           optional(:close_button) => close_button()
         }

  @typep kinds() :: %{
           required(atom()) => toast()
         }

  @type t() :: %{
          required(:group) => group(),
          required(:toast) => toast(),
          required(:kinds) => kinds()
        }

  @spec new!(attrs :: map() | t()) :: t()
  def new!(attrs) do
    base = Map.from_struct(%__MODULE__{})
    merged_attrs = Helpers.deep_merge(base, attrs)

    struct!(__MODULE__, merged_attrs)
  end
end
