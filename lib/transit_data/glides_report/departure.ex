defmodule TransitData.GlidesReport.Departure do
  @moduledoc """
  Data structure representing a single departure from a stop
  (either predicted or actual)
  """

  alias TransitData.GlidesReport.Spec.Common
  alias TransitData.GlidesReport.Terminal

  @type t :: %__MODULE__{
          trip: Common.trip_id(),
          terminal: Terminal.id(),
          timestamp: Common.timestamp(),
          # `timestamp` as a DateTime in Eastern time, truncated to minutes
          local_dt: DateTime.t()
        }

  @enforce_keys [:trip, :terminal, :timestamp, :local_dt]
  defstruct @enforce_keys

  @spec new(Common.trip_id(), Terminal.id(), Common.timestamp()) :: t()
  def new(trip, {:terminal, _} = terminal, timestamp) do
    local_dt =
      timestamp
      |> DateTime.from_unix!()
      |> DateTime.shift_zone!("America/New_York")
      |> then(&%{&1 | second: 0, microsecond: {0, 0}})

    %__MODULE__{trip: trip, terminal: terminal, timestamp: timestamp, local_dt: local_dt}
  end
end
