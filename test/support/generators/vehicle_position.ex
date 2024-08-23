defmodule TransitData.GlidesReport.Generators.VehiclePosition do
  @moduledoc """
  Generates vehicle positions, particularly for testing the GlidesReport modules.
  """

  import StreamData
  import ExUnitProperties, only: [gen: 2]
  alias TransitData.GlidesReport.Terminals

  def valid_vehicle_position_generator(opts \\ []) do
    current_status_members =
      opts[:current_status] || ["INCOMING_AT", "IN_TRANSIT_TO", "STOPPED_AT"]

    stop_id_gen_base =
      case opts[:stop_ids] do
        nil -> stop_id_generator()
        :relevant -> second_stop_id_generator()
        :irrelevant -> non_second_stop_id_generator()
      end

    stop_id_gen =
      case opts[:define_stop_id] do
        nil -> one_of([stop_id_gen_base, constant(nil)])
        true -> stop_id_gen_base
        false -> constant(nil)
      end

    gen all(
          vehicle_id <- string(:ascii),
          current_status <- member_of(current_status_members),
          position <- position_generator(),
          timestamp <- positive_integer(),
          trip <- trip_generator(opts[:revenue]),
          sub_vehicle <- vehicle_generator(vehicle_id),
          stop_sequence <- one_of([positive_integer(), constant(nil)]),
          carriage_details <- one_of([carriage_details_generator(), constant(nil)]),
          occupancy_percentage <- one_of([integer(0..100//1), constant(nil)]),
          occupancy_status <-
            one_of([
              member_of(["MANY_SEATS_AVAILABLE", "FEW_SEATS_AVAILABLE", "FULL"]),
              constant(nil)
            ]),
          stop_id <- stop_id_gen
        ) do
      vehicle =
        %{
          "current_status" => current_status,
          "position" => position,
          "timestamp" => timestamp,
          "trip" => trip,
          "vehicle" => sub_vehicle,
          "current_stop_sequence" => stop_sequence,
          "multi_carriage_details" => carriage_details,
          "occupancy_percentage" => occupancy_percentage,
          "occupancy_status" => occupancy_status,
          "stop_id" => stop_id
        }
        |> Map.reject(&match?({_k, nil}, &1))

      %{"id" => vehicle_id, "vehicle" => vehicle}
    end
  end

  def stopped_vehicle_position_generator do
    valid_vehicle_position_generator(
      stop_ids: :relevant,
      current_status: ["STOPPED_AT"],
      define_stop_id: true,
      revenue: true
    )
  end

  def missing_stop_id_vehicle_position_generator do
    valid_vehicle_position_generator(
      stop_ids: :relevant,
      current_status: ["INCOMING_AT", "IN_TRANSIT_TO"],
      define_stop_id: false,
      revenue: true
    )
  end

  def nonrevenue_vehicle_position_generator do
    valid_vehicle_position_generator(
      stop_ids: :relevant,
      current_status: ["INCOMING_AT", "IN_TRANSIT_TO"],
      define_stop_id: true,
      revenue: false
    )
  end

  def present_fields_vehicle_position_generator do
    valid_vehicle_position_generator(
      current_status: ["INCOMING_AT", "IN_TRANSIT_TO"],
      define_stop_id: true,
      revenue: true
    )
  end

  def irrelevant_vehicle_position_generator do
    valid_vehicle_position_generator(
      stop_ids: :irrelevant,
      current_status: ["INCOMING_AT", "IN_TRANSIT_TO"],
      define_stop_id: true,
      revenue: true
    )
  end

  def relevant_vehicle_position_generator do
    valid_vehicle_position_generator(
      stop_ids: :relevant,
      current_status: ["INCOMING_AT", "IN_TRANSIT_TO"],
      define_stop_id: true,
      revenue: true
    )
  end

  defp position_generator do
    optional_map(
      %{
        "latitude" => float(min: 40.0, max: 42.0),
        "longitude" => float(min: -75.0, max: -71.0),
        "bearing" => integer(0..360//1),
        "speed" => float(min: 0.0, max: 50.0)
      },
      ["bearing", "speed"]
    )
  end

  defp trip_generator(revenue_opt) do
    optional_map(
      %{
        "last_trip" => boolean(),
        "revenue" => if(is_nil(revenue_opt), do: boolean(), else: constant(revenue_opt)),
        "route_id" => string(:alphanumeric),
        "schedule_relationship" => member_of(["SCHEDULED", "ADDED", "CANCELED", "UNSCHEDULED"]),
        "trip_id" => string(:ascii),
        "direction_id" => member_of([0, 1]),
        "start_date" => map(positive_integer(), &Integer.to_string/1),
        "start_time" => time_generator()
      },
      ["direction_id", "start_date", "start_time"]
    )
  end

  defp time_generator do
    tuple({integer(0..23), integer(0..59), integer(0..59)})
    |> map(fn parts ->
      parts
      |> Tuple.to_list()
      |> Enum.map_join(":", &(&1 |> Integer.to_string() |> String.pad_leading(2, "0")))
    end)
  end

  defp vehicle_generator(id) do
    fixed_map(%{"id" => constant(id), "label" => string(:ascii)})
  end

  defp carriage_details_generator do
    optional_map(
      %{
        "label" => map(positive_integer(), &Integer.to_string/1),
        "occupancy_status" =>
          member_of([
            "NO_DATA_AVAILABLE",
            "MANY_SEATS_AVAILABLE",
            "FEW_SEATS_AVAILABLE",
            "STANDING_ROOM_ONLY"
          ]),
        "orientation" => member_of(["AB", "BA"]),
        "occupancy_percentage" => positive_integer()
      },
      ["orientation", "occupancy_percentage"]
    )
    |> list_of(min_length: 2, max_length: 4)
    |> map(fn l ->
      Enum.with_index(l, fn detail, i ->
        Map.put(detail, "carriage_sequence", i + 1)
      end)
    end)
  end

  defp stop_id_generator do
    one_of([
      second_stop_id_generator(),
      non_second_stop_id_generator()
    ])
  end

  defp second_stop_id_generator do
    member_of(Terminals.all_next_stops())
  end

  defp non_second_stop_id_generator do
    gen all(
          i <- integer(70_000..79_999//1),
          id = Integer.to_string(i),
          id not in Terminals.all_next_stops()
        ) do
      id
    end
  end
end

# Rough schema of a vehicle position
"""
id: string
vehicle:
  current_status: "INCOMING_AT", "IN_TRANSIT_TO", "STOPPED_AT"
  position:
    latitude:  float min_max={39.83250807, 42.765830993652344}
    longitude: float min_max={-75.0711326, -70.30698791}
    bearing?:  0..360
    speed?:    float
  timestamp:   int
  trip:
    last_trip:             boolean
    revenue:               boolean
    route_id:              string
    schedule_relationship: "SCHEDULED", "ADDED", "CANCELED", "UNSCHEDULED"
    trip_id:               string

    direction_id?:         boolean
    start_date?:           string - e.g. "20240820"
    start_time?:           string - e.g. "19:15:00"
  vehicle:
    id:    string
    label: string

  current_stop_sequence?: int
  multi_carriage_details?: [
    carriage_sequence:     int
    label:                 string - e.g. "1403"
    occupancy_status:      "NO_DATA_AVAILABLE", "MANY_SEATS_AVAILABLE", "FEW_SEATS_AVAILABLE", "STANDING_ROOM_ONLY"

    orientation?:          "AB", "BA"
    occupancy_percentage?: int
  ]
  occupancy_percentage?: int
  occupancy_status?:     "MANY_SEATS_AVAILABLE", "FEW_SEATS_AVAILABLE", "FULL"
  stop_id?:              string
"""
