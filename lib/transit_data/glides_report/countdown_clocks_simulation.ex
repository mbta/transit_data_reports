defmodule TransitData.GlidesReport.CountdownClocksSimulation do
  @moduledoc "Simulates countdown clock signs."

  alias TransitData.GlidesReport

  @type t :: %{stop_id => GlidesReport.Sign.t()}

  @type stop_id :: String.t()

  @type timestamp :: integer

  @doc """
  Returns a set of {stop_id, timestamp} tuples, each representing an instance where
  a predicted time (timestamp) appeared on the countdown clock for a stop (stop_id).
  """
  @spec get_all_top_two_times(Enumerable.t(stop_id)) :: MapSet.t({stop_id, timestamp})
  def get_all_top_two_times(stop_ids) do
    trip_updates_for_simulation(stop_ids)
    |> Enum.reduce(%{}, fn tr_upd, signs -> apply_trip_update(signs, tr_upd) end)
    |> Stream.map(fn {stop_id, sign} ->
      MapSet.new(sign.top_twos, fn timestamp -> {stop_id, timestamp} end)
    end)
    |> Enum.reduce(MapSet.new(), &MapSet.union/2)
  end

  def apply_trip_update(signs, tr_upd) do
    trip_id = tr_upd.id
    timestamp = tr_upd.trip_update.timestamp

    Enum.reduce(tr_upd.trip_update.stop_time_update, signs, fn
      stop_time_update, signs ->
        departure_time = stop_time_update.departure.time

        Map.update(
          signs,
          stop_time_update.stop_id,
          GlidesReport.Sign.new(trip_id, departure_time, timestamp),
          &GlidesReport.Sign.apply_stop_time_update(&1, trip_id, departure_time, timestamp)
        )
    end)
  end

  defp trip_updates_for_simulation(stop_ids) do
    :TripUpdates
    |> GlidesReport.Util.stream_values()
    |> Stream.map(&GlidesReport.TripUpdate.normalize_stop_ids/1)
    # Filter each trip update's stop_time_update to just the user's selected stops.
    # If filtered list is empty for any trip update, the trip update is removed entirely.
    |> Stream.map(&GlidesReport.TripUpdate.filter_stops(&1, stop_ids))
    |> Stream.reject(&is_nil/1)
    |> Enum.sort_by(& &1.trip_update.timestamp)
  end
end
