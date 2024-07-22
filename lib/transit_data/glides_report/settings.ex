defmodule TransitData.GlidesReport.Settings do
  @moduledoc "User-selected settings for the report."

  @type t :: %__MODULE__{
          env_suffix: String.t(),
          date: Date.t(),
          stop_ids: MapSet.t(String.t()),
          limit_to_next_2_predictions: boolean,
          sample_rate: integer,
          sample_count: integer | :all,
          min_advance_notice_sec: pos_integer | nil
        }

  defstruct [
    :env_suffix,
    :date,
    :stop_ids,
    :limit_to_next_2_predictions,
    :sample_rate,
    :sample_count,
    :min_advance_notice_sec
  ]

  # Parses initial data source settings from input elements.
  @spec new(String.t(), Date.t(), integer, integer | nil) :: t()
  def new(env, date, sample_rate, samples_per_minute) do
    %__MODULE__{
      env_suffix: env,
      date: date,
      sample_rate: sample_rate |> trunc(),
      sample_count:
        case samples_per_minute do
          nil -> :all
          n -> trunc(n)
        end
    }
  end

  # Adds filtering settings.
  @spec set_filters(t(), MapSet.t(String.t()), boolean, pos_integer | nil) :: t()
  def set_filters(settings, stop_ids, limit_to_next_2_predictions, min_advance_notice) do
    %{
      settings
      | stop_ids: stop_ids,
        limit_to_next_2_predictions: limit_to_next_2_predictions,
        min_advance_notice_sec:
          case min_advance_notice do
            nil -> nil
            n -> trunc(n)
          end
    }
  end
end
