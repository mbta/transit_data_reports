defmodule TransitData.GlidesReport.TripUpdate do
  @moduledoc """
  Functions to work with TripUpdate data structures.
  """

  alias TransitData.GlidesReport

  def clean_up(tr_upd, header_timestamp)

  def clean_up(%{"trip_update" => %{"trip" => %{"schedule_relationship" => "CANCELED"}}}, _) do
    nil
  end

  def clean_up(
        %{
          "trip_update" => %{"trip" => %{"revenue" => true}, "stop_time_update" => [_ | _]}
        } = tr_upd,
        header_timestamp
      ) do
    tr_upd
    |> update_in(["trip_update", "stop_time_update"], &clean_up_stop_times/1)
    # If the trip update is missing a timestamp, substitute the timestamp from the header.
    |> update_in(["trip_update", "timestamp"], &(&1 || header_timestamp))
    |> update_in(["trip_update"], &Map.take(&1, ["timestamp", "stop_time_update"]))
    |> then(fn cleaned_tr_upd ->
      # If all stop times have been removed, discard the entire trip update.
      if Enum.empty?(cleaned_tr_upd["trip_update"]["stop_time_update"]) do
        nil
      else
        Map.take(cleaned_tr_upd, ["id", "trip_update"])
      end
    end)
  end

  def clean_up(_, _) do
    nil
  end

  def normalize_stop_ids(tr_upd) do
    update_in(
      tr_upd,
      [:trip_update, :stop_time_update, Access.all(), :stop_id],
      &GlidesReport.Terminals.normalize_stop_id/1
    )
  end

  defp clean_up_stop_times(stop_times) do
    stop_times
    # Ignore stop times that aren't relevant to Glides terminals.
    |> Stream.reject(&(&1["stop_id"] not in GlidesReport.Terminals.all_stops()))
    # Select stop times that have departure times and aren't skipped.
    |> Stream.filter(fn stop_time ->
      has_departure_time = not is_nil(stop_time["departure"]["time"])
      is_skipped = stop_time["schedule_relationship"] == "SKIPPED"
      has_departure_time and not is_skipped
    end)
    # Prune all but the relevant fields.
    |> Enum.map(fn
      stop_time ->
        stop_time
        |> update_in(["departure"], &Map.take(&1, ["time"]))
        |> Map.take(["stop_id", "departure"])
    end)
  end

  # Removes, from a trip update's stop_time_update, all entries that don't apply to the target stop(s).
  # Returns nil if trip update doesn't contain any relevant stop times.
  def filter_stops(tr_upd, stop_ids) do
    case Enum.filter(tr_upd.trip_update.stop_time_update, &(&1.stop_id in stop_ids)) do
      [] ->
        nil

      filtered_stop_times ->
        put_in(tr_upd.trip_update.stop_time_update, filtered_stop_times)
    end
  end

  def filter_by_advance_notice(tr_upd, nil), do: tr_upd

  def filter_by_advance_notice(tr_upd, min_advance_notice_sec) do
    time_of_creation = tr_upd.trip_update.timestamp

    update_in(tr_upd.trip_update.stop_time_update, fn stop_times ->
      Enum.filter(stop_times, &(&1.departure.time - time_of_creation >= min_advance_notice_sec))
    end)
  end
end
