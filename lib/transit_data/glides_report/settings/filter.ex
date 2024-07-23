defmodule TransitData.GlidesReport.Settings.Filter do
  @moduledoc "User-selected filtering settings."

  @type t :: %__MODULE__{
          # A set of parent stop IDs
          stop_ids: MapSet.t(String.t()),
          limit_to_next_2_predictions: boolean,
          min_advance_notice_sec: pos_integer | nil
        }

  defstruct [
    :stop_ids,
    :limit_to_next_2_predictions,
    :min_advance_notice_sec
  ]

  @spec new(MapSet.t(String.t()), boolean, pos_integer | nil) :: t()
  def new(stop_ids, limit_to_next_2_predictions, min_advance_notice) do
    %__MODULE__{
      stop_ids: stop_ids,
      limit_to_next_2_predictions: limit_to_next_2_predictions,
      min_advance_notice_sec:
        case min_advance_notice do
          nil -> nil
          n -> trunc(n)
        end
    }
  end
end
