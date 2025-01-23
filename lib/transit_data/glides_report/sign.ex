defmodule TransitData.GlidesReport.Sign do
  @moduledoc "Simulates a countdown clock at one terminal."

  @type t :: %__MODULE__{
          predictions: list({trip_id :: String.t(), departure_time :: integer}),
          top_twos: MapSet.t(departure_time :: integer)
        }

  defstruct predictions: [], top_twos: MapSet.new()

  def new, do: %__MODULE__{}

  def new(trip_id, departure_time, timestamp) when departure_time >= timestamp do
    %__MODULE__{
      predictions: [{trip_id, departure_time}],
      top_twos: MapSet.new([departure_time])
    }
  end

  def new(_trip_id, _departure_time, _timestamp), do: new()

  def apply_stop_time_update(sign, trip_id, departure_time, timestamp) do
    sign = advance_to_time(sign, timestamp)

    update_in(sign.predictions, fn predictions ->
      predictions
      |> List.keystore(trip_id, 0, {trip_id, departure_time})
      |> Enum.sort_by(fn {_, ts} -> ts end)
    end)
    |> update_top_twos()
  end

  def update_top_twos(sign) do
    update_in(sign.top_twos, fn top_twos ->
      sign.predictions
      |> Enum.take(2)
      |> MapSet.new(fn {_trip_id, departure_time} -> departure_time end)
      |> MapSet.union(top_twos)
    end)
  end

  # Simulate time passing until the next timestamped trip update comes in.
  defp advance_to_time(sign, timestamp) do
    {before, not_before} = Enum.split_while(sign.predictions, fn {_, ts} -> ts < timestamp end)
    seen = before ++ Enum.take(not_before, 2)
    seen_departure_times = MapSet.new(seen, &elem(&1, 1))

    sign = put_in(sign.predictions, not_before)
    sign = update_in(sign.top_twos, &MapSet.union(&1, seen_departure_times))
    sign
  end
end
