defmodule TransitData.GlidesReport.Spec.VehiclePosition do
  @moduledoc """
  Structure of an entry in the :VehiclePositions table--
  a cleaned/pruned version of a VehiclePosition.
  (Typespec for documentation only)
  """

  alias TransitData.GlidesReport.Spec.Common
  alias TransitData.GlidesReport.Terminal

  @type t :: {key, value}

  # Key is a string of the form "#{timestamp}_#{vehicle_id}"
  # e.g. "1717471500_G-10351"
  @type key :: String.t()

  @type value :: %{
          id: Common.vehicle_id(),
          vehicle: %{
            # "IN_TRANSIT_TO" | "STOPPED_AT" | "INCOMING_AT"
            current_status: String.t(),
            # A child stop ID initially, but we convert it to the
            # ID of the relevant terminal by calling
            # GlidesReport.VehiclePosition.normalize_stop_id/1 on it.
            terminal_id: Terminal.id(),
            timestamp: Common.timestamp(),
            trip: %{
              trip_id: Common.trip_id()
            }
          }
        }
end
