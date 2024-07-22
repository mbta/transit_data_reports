defmodule TransitData.GlidesReport.Util do
  @moduledoc """
  Miscellaneous utility functions for the report.
  """

  alias TransitData.GlidesReport

  # Streams all values from an ETS table. (Assuming table's objects are {key, value} 2-tuples)
  def stream_values(table) do
    :ets.first(table)
    |> Stream.iterate(fn key -> :ets.next(table, key) end)
    |> Stream.take_while(fn key -> key != :"$end_of_table" end)
    |> Stream.map(fn key -> :ets.lookup_element(table, key, 2) end)
  end

  # Formats an integer to a string, with left zero-padding to at least `count` digits.
  def zero_pad(n, count \\ 2) do
    n
    |> Integer.to_string()
    |> String.pad_leading(count, "0")
  end

  def unix_timestamp_to_local_hour(timestamp) do
    unix_timestamp_to_local_datetime(timestamp).hour
  end

  def unix_timestamp_to_local_minute(timestamp) do
    unix_timestamp_to_local_datetime(timestamp).minute
  end

  defp unix_timestamp_to_local_datetime(timestamp) do
    timestamp
    |> DateTime.from_unix!()
    |> DateTime.shift_zone!("America/New_York")
  end

  # Converts a nonempty list of KW-lists, e.g.:
  # [
  #   [{"headerA", "valueA1"}, {"headerB", "valueB1"}],
  #   [{"headerA", "valueA2"}, {"headerB", "valueB2"}]
  # ]
  # to a CSV string.
  def table_to_csv(table) do
    table
    |> Stream.map(&Map.new/1)
    |> CSV.encode(headers: Enum.map(hd(table), &elem(&1, 0)), delimiter: "\n")
    |> Enum.join()
  end

  @stop_filters GlidesReport.Terminals.all_labeled_stops_and_groups()
  defp stop_filters, do: @stop_filters

  def build_csv_name(table_name, settings) do
    %{
      env_suffix: env_suffix,
      date: date,
      stop_ids: stop_ids,
      limit_to_next_2_predictions: limit_to_next_2_predictions,
      sample_rate: sample_rate,
      sample_count: sample_count
    } = settings

    env = if env_suffix == "", do: "prod", else: String.slice(env_suffix, 1..-1//1)

    stop_filter =
      Enum.find_value(stop_filters(), fn {set, label} ->
        if MapSet.equal?(set, stop_ids), do: label
      end)

    true = not is_nil(stop_filter)

    sample_count = if sample_count == :all, do: "ALL", else: sample_count

    sampling = "sampling=#{sample_count}per#{sample_rate}min"

    optionals =
      [
        {stop_ids, "stops=#{stop_filter}"},
        {limit_to_next_2_predictions, "next 2 predictions only"}
      ]
      |> Enum.filter(&elem(&1, 0))
      |> Enum.map_join(",", &elem(&1, 1))
      |> case do
        "" -> ""
        str -> ",#{str}"
      end

    "Glides report - #{table_name} - #{env},#{date}#{optionals},#{sampling}.csv"
  end
end
