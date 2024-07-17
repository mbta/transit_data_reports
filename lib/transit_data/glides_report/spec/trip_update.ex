defmodule TransitData.GlidesReport.Spec.TripUpdate do
  @moduledoc """
  Structure of an entry in the :TripUpdates table--
  a cleaned/pruned version of a TripUpdate.
  (Typespec for documentation only)
  """

  alias TransitData.GlidesReport.Spec.Common

  @type t :: {key, value}

  # Key is a string of the form "#{timestamp}_#{trip_id}"
  # e.g. "1717524600_62216363"
  # NB: This timestamp can be different from .trip_update.timestamp,
  # it appears to be the time this snapshot was stored while
  # .trip_update.timestamp is the time that the trip update was generated.
  @type key :: String.t()

  @type value :: %{
          id: Common.trip_id(),
          trip_update: %{
            timestamp: Common.timestamp(),
            stop_time_update:
              list(%{
                departure: %{time: Common.timestamp()},
                stop_id: Common.stop_id()
              })
          }
        }
end
