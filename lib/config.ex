defmodule HogToast.Config do
  @moduledoc """
  Configuration struct for `HogToast.ToastGroup`.

  Defines default CSS classes and per-kind overrides for every visual part of a
  toast (group wrapper, toast container, title, body, duration bar, close button,
  and its icon).  Call `new!/1` with a partial map to deep-merge your overrides
  on top of the built-in defaults.

  ## Built-in kinds

  | Kind      | Extra class            | ARIA role |
  |-----------|------------------------|-----------|
  | `:default`| —                      | `"status"` |
  | `:info`   | `hog-toast-info`       | `"status"` |
  | `:warning`| `hog-toast-warning`    | `"status"` |
  | `:danger` | `hog-toast-danger`     | `"alert"`  |
  | `:success`| `hog-toast-success`    | `"status"` |
  """

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
              danger: %{class: "hog-toast-danger", role: "alert"},
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
           optional(:close_button) => close_button(),
           optional(:role) => String.t()
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
