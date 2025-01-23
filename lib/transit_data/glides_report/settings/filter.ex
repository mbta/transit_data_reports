defmodule TransitData.GlidesReport.Settings.Filter do
  @moduledoc "User-selected filtering settings."

  alias TransitData.GlidesReport.Terminal

  @type t :: %__MODULE__{
          # A set of terminal IDs
          terminal_ids: MapSet.t(Terminal.id()),
          limit_to_next_2_predictions: boolean,
          min_advance_notice_sec: pos_integer | nil
        }

  defstruct [
    :terminal_ids,
    :limit_to_next_2_predictions,
    :min_advance_notice_sec
  ]

  @spec new(MapSet.t(Terminal.id()), boolean, pos_integer | nil) :: t()
  def new(terminal_ids, limit_to_next_2_predictions, min_advance_notice) do
    %__MODULE__{
      terminal_ids: terminal_ids,
      limit_to_next_2_predictions: limit_to_next_2_predictions,
      min_advance_notice_sec:
        case min_advance_notice do
          nil -> nil
          n -> trunc(n)
        end
    }
  end
end
