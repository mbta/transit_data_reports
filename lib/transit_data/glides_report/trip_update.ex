defmodule TransitData.GlidesReport.TripUpdate do
  @moduledoc """
  Functions to work with TripUpdate data structures.
  """

  alias TransitData.GlidesReport

  @doc """
  Cleans up a TripUpdate parsed from raw JSON. (With keys not yet converted to
  atoms)

  Returns nil if there is no data relevant to Glides terminals in the TripUpdate.

  - Canceled TripUpdates are discarded.
  - Nonrevenue TripUpdates are discarded.
  - `.trip_update.timestamp` is replaced with the given `header_timestamp` if
    missing or nil
  - `.trip_update.stop_time_update` list is filtered to non-skipped entries with
    defined departure times, at Glides terminal stops. If the filtered list is
    empty, the entire TripUpdate is discarded.
  - All unused fields are removed.
  """
  @spec clean_up(map, integer) :: map | nil
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
    # If the trip update is missing a timestamp, substitute the timestamp from the header.
    |> update_in(["trip_update", "timestamp"], &(&1 || header_timestamp))
    |> update_in(["trip_update", "stop_time_update"], &clean_up_stop_times/1)
    |> update_in(["trip_update", "trip"], &Map.take(&1, ["trip_id"]))
    |> update_in(["trip_update"], &Map.take(&1, ["timestamp", "stop_time_update", "trip"]))
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
    glides_terminals = GlidesReport.Terminals.all_first_stops()

    stop_times
    |> Stream.filter(fn stop_time ->
      cond do
        is_nil(stop_time["departure"]["time"]) -> false
        stop_time["schedule_relationship"] == "SKIPPED" -> false
        stop_time["stop_id"] not in glides_terminals -> false
        :else -> true
      end
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

    filtered_stop_times =
      Enum.filter(
        tr_upd.trip_update.stop_time_update,
        &(&1.departure.time - time_of_creation >= min_advance_notice_sec)
      )

    case filtered_stop_times do
      [] ->
        nil

      filtered_stop_times ->
        put_in(tr_upd.trip_update.stop_time_update, filtered_stop_times)
    end
  end
end
