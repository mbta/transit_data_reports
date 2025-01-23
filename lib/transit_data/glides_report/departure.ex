defmodule TransitData.GlidesReport.Departure do
  @moduledoc """
  Data structure representing a single departure from a stop
  (either predicted or actual)
  """

  alias TransitData.GlidesReport.Spec.Common
  alias TransitData.GlidesReport.Terminal
  alias TransitData.GlidesReport.Util

  @type t :: %__MODULE__{
          trip: Common.trip_id(),
          terminal: Terminal.id(),
          timestamp: Common.timestamp(),
          # Hour part of the timestamp (in Eastern TZ)
          hour: 0..23,
          # Minute part of the timestamp
          minute: 0..59
        }

  @type minute :: 0..59

  @enforce_keys [:trip, :terminal, :timestamp, :hour, :minute]
  defstruct @enforce_keys

  @spec new(Common.trip_id(), Terminal.id(), Common.timestamp()) :: t()
  def new(trip, {:terminal, _} = terminal, timestamp) do
    hour = Util.unix_timestamp_to_local_hour(timestamp)
    minute = Util.unix_timestamp_to_local_minute(timestamp)
    %__MODULE__{trip: trip, terminal: terminal, timestamp: timestamp, hour: hour, minute: minute}
  end
end
