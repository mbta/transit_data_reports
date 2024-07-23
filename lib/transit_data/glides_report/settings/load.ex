defmodule TransitData.GlidesReport.Settings.Load do
  @moduledoc """
  User-selected settings for the data load step.
  """

  @type t :: %__MODULE__{
          env_suffix: String.t(),
          start_dt: DateTime.t(),
          end_dt: DateTime.t(),
          sample_rate: integer,
          sample_count: integer | :all
        }

  defstruct [
    :env_suffix,
    :start_dt,
    :end_dt,
    :sample_rate,
    :sample_count
  ]

  @spec new(String.t(), Date.t(), integer, integer | nil) :: t()
  def new(env, date, sample_rate, samples_per_minute) do
    {start_dt, end_dt} = date_to_start_end_dt(date)
    new(env, start_dt, end_dt, sample_rate, samples_per_minute)
  end

  @spec new(String.t(), DateTime.t(), DateTime.t(), integer, integer | nil) :: t()
  def new(env, start_dt, end_dt, sample_rate, samples_per_minute) do
    %__MODULE__{
      env_suffix: env,
      start_dt: start_dt,
      end_dt: end_dt,
      sample_rate: sample_rate |> trunc(),
      sample_count:
        case samples_per_minute do
          nil -> :all
          n -> trunc(n)
        end
    }
  end

  defp date_to_start_end_dt(date) do
    # We assume they want a full service day on the given date.
    start_dt =
      date
      |> DateTime.new!(~T[04:00:00], "America/New_York")
      |> DateTime.shift_zone!("Etc/UTC")

    end_dt =
      date
      |> Date.add(1)
      |> DateTime.new!(~T[03:59:59], "America/New_York")
      |> DateTime.shift_zone!("Etc/UTC")

    {start_dt, end_dt}
  end
end
