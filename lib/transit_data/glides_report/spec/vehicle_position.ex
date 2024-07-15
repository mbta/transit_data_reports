defmodule TransitData.GlidesReport.Spec.VehiclePosition do
  @moduledoc """
  Structure of an entry in the :VehiclePositions table--
  a cleaned/pruned version of a VehiclePosition.
  (Typespec for documentation only)
  """

  alias TransitData.GlidesReport.Common

  @type t :: {key, value}

  # Key is a string of the form "#{timestamp}_#{vehicle_id}"
  # e.g. "1717471500_G-10351"
  @type key :: String.t()

  @type value :: %{
          id: Common.vehicle_id(),
          vehicle: %{
            # "IN_TRANSIT_TO" | "STOPPED_AT" | "INCOMING_AT"
            current_status: String.t(),
            stop_id: Commmon.stop_id(),
            timestamp: Commmon.timestamp(),
            trip: %{
              trip_id: Commmon.trip_id()
            }
          }
        }
end
