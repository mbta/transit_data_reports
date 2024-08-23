defmodule TransitData.GlidesReport.Generators.TripUpdate do
  @moduledoc """
  Generates trip updates, particularly for testing the GlidesReport modules.
  """

  import StreamData
  import ExUnitProperties, only: [gen: 2]

  # (Ignore first item, it keeps the formatter from moving the first comment)
  @type trip_update_gen_opt ::
          :___
          # Force all trip updates to be canceled, or not canceled.
          | {:canceled?, boolean}
          # Force all trip updates to be revenue, or nonrevenue.
          | {:revenue?, boolean}
          # Force all trip updates to have timestamps defined at .trip_update.timestamp, or not.
          | {:define_timestamp, boolean}
          # Force the first element of stop_time_update to be at a Glides terminal, or not.
          | {:force_glides_terminal, boolean}
          # Force the first / all stop time(s) to have defined departure time, or not.
          | {:force_departure_time, {:first, boolean} | {:all, boolean}}
          # Force departure times to be within a range from the main timestamp
          | {:force_notice_range, Range.t()}

  @doc """
  Returns a StreamData generator that yields valid trip updates.

  Use opts to narrow the output.
  """
  @spec valid_trip_update_generator([trip_update_gen_opt]) :: StreamData.t(map())
  def valid_trip_update_generator(opts \\ []) do
    canceled_gen =
      case opts[:canceled?] do
        nil -> boolean()
        canceled? -> constant(canceled?)
      end

    make_revenue_gen = fn canceled? ->
      case opts[:revenue?] do
        nil -> map(boolean(), &if(canceled?, do: &1, else: true))
        revenue? -> constant(revenue?)
      end
    end

    gen all(
          trip_id <- map(positive_integer(), &Integer.to_string/1),
          canceled? <- canceled_gen,
          # Revenue can be false only if canceled is true.
          # (There are some exceptions to this, but let's not complicate things even more.)
          revenue? <- make_revenue_gen.(canceled?),
          timestamp <- timestamp_generator_(canceled?, revenue?, opts[:define_timestamp]),
          stop_time_update <-
            stop_time_update_generator_(
              canceled?,
              revenue?,
              opts[:force_glides_terminal],
              opts[:force_departure_time],
              opts[:force_notice_range]
            ),
          vehicle <- vehicle_generator_(canceled?, revenue?),
          trip <- trip_generator(trip_id, canceled?, revenue?)
        ) do
      trip_update =
        %{
          "trip" => trip,
          "timestamp" => timestamp,
          "stop_time_update" => stop_time_update,
          "vehicle" => vehicle
        }
        |> Map.reject(&match?({_k, nil}, &1))

      %{
        "id" => trip_id,
        "trip_update" => trip_update
      }
    end
  end

  def canceled_trip_update_generator do
    valid_trip_update_generator(canceled?: true)
  end

  def nonrevenue_trip_update_generator do
    valid_trip_update_generator(revenue?: false)
  end

  def missing_timestamp_trip_update_generator do
    valid_trip_update_generator(
      define_timestamp: false,
      revenue?: true,
      canceled?: false,
      force_glides_terminal: true,
      force_departure_time: {:first, true}
    )
  end

  def relevant_trip_update_generator do
    valid_trip_update_generator(
      revenue?: true,
      canceled?: false,
      force_glides_terminal: true,
      force_departure_time: {:first, true}
    )
  end

  def short_notice_trip_update_generator(min_notice, max_notice) do
    valid_trip_update_generator(
      define_timestamp: false,
      revenue?: true,
      canceled?: false,
      force_glides_terminal: true,
      force_departure_time: {:first, true},
      force_notice_range: min_notice..max_notice//1
    )
  end

  # An arbitrary unix timestamp to use in tests.
  @header_timestamp 1_698_235_200
  def header_timestamp, do: @header_timestamp

  # Generator fns with names ending in `_` may generate nil.

  defp vehicle_generator_(true, false), do: constant(nil)

  defp vehicle_generator_(_, _) do
    gen all(
          keys <- member_of([["id"], ["id", "label"], []]),
          base <- fixed_map(%{"id" => string(:ascii), "label" => string(:ascii)})
        ) do
      vehicle = Map.take(base, keys)
      if vehicle == %{}, do: nil, else: vehicle
    end
  end

  defp stop_time_update_generator_(
         canceled?,
         revenue?,
         force_glides_terminal,
         force_departure_time,
         force_notice_range
       )

  defp stop_time_update_generator_(true, false, _, _, _), do: constant(nil)

  defp stop_time_update_generator_(
         canceled?,
         _,
         force_glides_terminal,
         force_departure_time,
         force_notice_range
       ) do
    first_stop_id_generator =
      case force_glides_terminal do
        nil -> &maybe_terminal_stop_id_generator/0
        true -> &terminal_stop_id_generator/0
        false -> &non_terminal_stop_id_generator/0
      end

    {force_first_departure_time, force_all_departure_times} =
      case force_departure_time do
        nil -> {nil, nil}
        {:first, force?} -> {force?, nil}
        {:all, force?} -> {force?, force?}
      end

    first_stop_time =
      stop_time_generator(
        canceled?,
        first_stop_id_generator,
        force_first_departure_time,
        force_notice_range
      )
      |> Enum.at(1)

    # length -> start with a stop_id -> rest can be whatever
    stop_time_generator(
      canceled?,
      &non_terminal_stop_id_generator/0,
      force_all_departure_times,
      force_notice_range
    )
    |> list_of(min_length: 4, max_length: 19)
    |> map(fn l ->
      [first_stop_time | l]
      |> Enum.with_index(fn stop_time, i ->
        Map.put(stop_time, "stop_sequence", i + 1)
      end)
    end)
  end

  # Generates stop_time objects sans stop_sequence field,
  # due to a limitation of generators (they're stateless).
  # stop_sequence is added later on, once the full stop_time_update
  # list has been generated.
  defp stop_time_generator(
         skipped?,
         get_stop_id_generator,
         force_departure_time,
         force_notice_range
       )

  defp stop_time_generator(true, _, _, _) do
    non_terminal_stop_id_generator()
    |> map(&%{"stop_id" => &1, "schedule_relationship" => "SKIPPED"})
  end

  defp stop_time_generator(false, get_stop_id_generator, force_departure_time, force_notice_range) do
    gen all(
          stop_id <- get_stop_id_generator.(),
          {arrival_t, departure_t} <- timespan_generator(force_notice_range),
          departure <- arrival_departure_generator(departure_t, force_departure_time),
          arrival <- arrival_departure_generator(arrival_t, is_nil(departure)),
          boarding_status <- boarding_status_generator()
        ) do
      %{
        "stop_id" => stop_id,
        "arrival" => arrival,
        "departure" => departure,
        "boarding_status" => boarding_status
      }
      |> Map.reject(&match?({_k, nil}, &1))
    end
  end

  defp timespan_generator(nil) do
    gen all(
          arrival_t <- integer((header_timestamp() + 30)..(header_timestamp() + 3600)//1),
          departure_t <- integer((arrival_t + 1)..(arrival_t + 1800)//1)
        ) do
      {arrival_t, departure_t}
    end
  end

  defp timespan_generator(min_notice..max_notice//1) do
    gen all(
          arrival_t <- constant(header_timestamp() + min_notice - 1),
          departure_t <-
            integer((header_timestamp() + min_notice)..(header_timestamp() + max_notice)//1)
        ) do
      {arrival_t, departure_t}
    end
  end

  defp boarding_status_generator do
    member_of([nil, "Now boarding", "On time", "Stopped 3 stops away"])
  end

  defp arrival_departure_generator(t, force_define_time) do
    key_combos =
      case force_define_time do
        nil -> [[], ["time"], ["time", "uncertainty"]]
        true -> [["time"], ["time", "uncertainty"]]
        false -> [[]]
      end

    gen all(
          keys <- member_of(key_combos),
          base <- fixed_map(%{"time" => constant(t), "uncertainty" => positive_integer()})
        ) do
      arr_or_dep = Map.take(base, keys)
      if arr_or_dep == %{}, do: nil, else: arr_or_dep
    end
  end

  # May produce Glides terminal stop IDs.
  defp maybe_terminal_stop_id_generator do
    one_of([
      terminal_stop_id_generator(),
      non_terminal_stop_id_generator()
    ])
  end

  defp terminal_stop_id_generator do
    member_of(TransitData.GlidesReport.Terminals.all_first_stops())
  end

  # Never produces Glides terminal stop IDs.
  defp non_terminal_stop_id_generator do
    gen all(
          i <- integer(70_000..79_999//1),
          id = Integer.to_string(i),
          id not in TransitData.GlidesReport.Terminals.all_first_stops()
        ) do
      id
    end
  end

  defp trip_generator(trip_id, canceled?, revenue?) do
    gen all(
          direction_id <- member_of([0, 1]),
          last_trip? <- boolean(),
          route_id <- member_of(["Mattapan" | Enum.map(~w[B C D E], &("Green-" <> &1))]),
          start_date <- map(positive_integer(), &Integer.to_string/1),
          start_time <- time_generator(),
          route_pattern_id <- string(:ascii)
        ) do
      trip = %{
        "direction_id" => direction_id,
        "last_trip" => last_trip?,
        "revenue" => revenue?,
        "route_id" => route_id,
        "trip_id" => trip_id,
        "start_date" => start_date,
        "start_time" => start_time,
        "route_pattern_id" => route_pattern_id
      }

      if canceled?, do: Map.put(trip, "schedule_relationship", "CANCELED"), else: trip
    end
  end

  defp time_generator do
    tuple({integer(0..23), integer(0..59), integer(0..59)})
    |> map(fn parts ->
      parts
      |> Tuple.to_list()
      |> Enum.map_join(":", &(&1 |> Integer.to_string() |> String.pad_leading(2, "0")))
    end)
  end

  defp timestamp_generator_(canceled?, revenue?, force_define)

  defp timestamp_generator_(_, _, true), do: positive_integer()

  defp timestamp_generator_(_, _, false), do: constant(nil)

  defp timestamp_generator_(true, false, _), do: constant(nil)

  defp timestamp_generator_(_, _, _) do
    one_of([positive_integer(), constant(nil)])
  end
end
