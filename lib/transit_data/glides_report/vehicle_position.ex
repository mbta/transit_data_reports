defmodule TransitData.GlidesReport.VehiclePosition do
  @moduledoc """
  Functions to work with VehiclePosition data structures.
  """

  alias TransitData.GlidesReport

  def clean_up(
        ve_pos = %{
          "vehicle" => %{
            "timestamp" => timestamp,
            "current_status" => current_status,
            "stop_id" => stop_id,
            "trip" => %{"trip_id" => trip_id, "revenue" => true}
          }
        }
      )
      when is_integer(timestamp) and
             is_binary(stop_id) and
             is_binary(trip_id) and
             current_status in ["IN_TRANSIT_TO", "INCOMING_AT"] do
    if stop_id in GlidesReport.Terminals.all_next_stops() do
      ve_pos
      |> update_in(["vehicle", "trip"], &Map.take(&1, ["trip_id"]))
      |> update_in(
        ["vehicle"],
        &Map.take(&1, ["timestamp", "stop_id", "trip"])
      )
      |> Map.take(["id", "vehicle"])
    else
      nil
    end
  end

  def clean_up(_), do: nil

  # Prevents double-counting of actual departure times caused by multiple vehicle positions
  # being logged for a single vehicle's travel between two stops.
  #
  # E.g. We might get both an IN_TRANSIT_TO and an INCOMING_AT vehicle position for a train
  # traveling from Riverside to Woodland. In that case, this fn chooses the earlier of the two.
  def dedup_statuses(vehicle_positions) do
    vehicle_positions
    |> Enum.group_by(&{&1.vehicle.trip.trip_id, &1.vehicle.stop_id, &1.id})
    |> Stream.map(fn {_key, ve_positions} ->
      Enum.min_by(ve_positions, & &1.vehicle.timestamp)
    end)
  end
end
