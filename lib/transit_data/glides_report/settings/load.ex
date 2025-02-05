defmodule TransitData.GlidesReport.Settings.Load do
  @moduledoc """
  User-selected settings for the data load step.
  """

  @type t :: %__MODULE__{
          env_suffix: String.t(),
          start_date: Date.t(),
          end_date: Date.t(),
          sample_rate: pos_integer,
          sample_count: pos_integer | :all
        }

  defstruct [:env_suffix, :start_date, :end_date, :sample_rate, :sample_count]

  @spec new(String.t(), Date.t(), Date.t(), integer, integer | nil) :: t()
  def new(env, start_date, end_date, sample_rate, samples_per_minute) do
    %__MODULE__{
      env_suffix: env,
      start_date: start_date,
      end_date: end_date,
      sample_rate: sample_rate |> trunc(),
      sample_count:
        case samples_per_minute do
          nil -> :all
          n -> trunc(n)
        end
    }
  end
end
