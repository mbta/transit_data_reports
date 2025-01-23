defmodule TransitData.GlidesReport.Spec.TripUpdate do
  @moduledoc """
  Structure of an entry in the :TripUpdates table--
  a cleaned/pruned version of a TripUpdate.
  (Typespec for documentation only)
  """

  alias TransitData.GlidesReport.Spec.Common
  alias TransitData.GlidesReport.Terminal

  @type t :: {key, value}

  # Key is a string of the form "#{timestamp}_#{trip_id}"
  # e.g. "1717524600_62216363"
  # NB: This timestamp can be different from .trip_update.timestamp,
  # it appears to be the time this snapshot was stored while
  # .trip_update.timestamp is the time that the trip update was generated.
  @type key :: String.t()

  @type value :: %{
          # Normally the same trip ID as .trip_update.trip.trip_id,
          # but in dev-blue it seems to be getting prefixed with the timestamp for some reason.
          # (So it's inadvisable to use this field for anything but a unique ID)
          id: String.t(),
          trip_update: %{
            timestamp: Common.timestamp(),
            stop_time_update:
              list(%{
                departure: %{time: Common.timestamp()},
                # A child stop ID initially, but we convert it to the
                # ID of the relevant terminal by calling
                # GlidesReport.TripUpdate.normalize_stop_id/1 on it.
                terminal_id: Terminal.id()
              }),
            trip: %{trip_id: Common.trip_id()}
          }
        }
end
