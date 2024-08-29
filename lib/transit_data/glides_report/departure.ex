defmodule TransitData.GlidesReport.Departure do
  @moduledoc """
  Data structure representing a single departure from a stop
  (either predicted or actual)
  """

  alias TransitData.GlidesReport.Spec.Common
  alias TransitData.GlidesReport.Util

  @type t :: %__MODULE__{
          trip: Common.trip_id(),
          stop: Common.stop_id(),
          timestamp: Common.timestamp(),
          # Hour part of the timestamp (in Eastern TZ)
          hour: 0..23,
          # Minute part of the timestamp
          minute: 0..59
        }

  @type minute :: 0..59

  @enforce_keys [:trip, :stop, :timestamp, :hour, :minute]
  defstruct @enforce_keys

  @spec new(Common.trip_id(), Common.stop_id(), Common.timestamp()) :: t()
  def new(trip, stop, timestamp) do
    hour = Util.unix_timestamp_to_local_hour(timestamp)
    minute = Util.unix_timestamp_to_local_minute(timestamp)
    %__MODULE__{trip: trip, stop: stop, timestamp: timestamp, hour: hour, minute: minute}
  end
end
