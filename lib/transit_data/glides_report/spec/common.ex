defmodule TransitData.GlidesReport.Spec.Common do
  @moduledoc "Shared types."

  @type stop_id :: String.t()
  @type trip_id :: String.t()
  @type vehicle_id :: String.t()

  # Unix epoch timestamp
  @type timestamp :: integer
end
