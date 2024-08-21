defmodule TransitData.GlidesReport.Util do
  @moduledoc """
  Miscellaneous utility functions for the report.
  """

  alias TransitData.GlidesReport

  @doc """
  Streams all values from an ETS table.

  (Assuming table's objects are {key, value} 2-tuples)
  """
  @spec stream_values(:ets.table()) :: Enumerable.t()
  def stream_values(table) do
    :ets.first(table)
    |> Stream.iterate(fn key -> :ets.next(table, key) end)
    |> Stream.take_while(fn key -> key != :"$end_of_table" end)
    |> Stream.map(fn key -> :ets.lookup_element(table, key, 2) end)
  end

  @doc """
  Formats an integer to a string, with left zero-padding to at least `count` digits.
  """
  @spec zero_pad(non_neg_integer, non_neg_integer) :: String.t()
  def zero_pad(n, count \\ 2) when is_integer(n) and n >= 0 do
    n
    |> Integer.to_string()
    |> String.pad_leading(count, "0")
  end

  @doc """
  Formats the ratio of two numbers as a percentage.
  """
  @spec format_percent(number, number, String.t()) :: String.t()
  def format_percent(_numerator, denominator, zero_fallback) when denominator == 0 do
    zero_fallback
  end

  def format_percent(numerator, denominator, _zero_fallback) do
    p = round(100.0 * (numerator / denominator))
    "#{p}%"
  end

  @spec unix_timestamp_to_local_hour(integer) :: 0..23
  def unix_timestamp_to_local_hour(timestamp) do
    unix_timestamp_to_local_datetime(timestamp).hour
  end

  @spec unix_timestamp_to_local_hour(integer) :: 0..59
  def unix_timestamp_to_local_minute(timestamp) do
    unix_timestamp_to_local_datetime(timestamp).minute
  end

  defp unix_timestamp_to_local_datetime(timestamp) do
    timestamp
    |> DateTime.from_unix!()
    |> DateTime.shift_zone!("America/New_York")
  end

  @doc """
  Returns /absolute/path/to/transit_data_reports/dataset.
  """
  @spec dataset_dir() :: String.t()
  def dataset_dir do
    # I'm sure there's a more concise way to do this, but I couldn't find it. :\
    project_root =
      __DIR__
      |> Path.split()
      |> Enum.take_while(&(&1 != "lib"))
      |> Path.join()

    Path.join(project_root, "dataset")
  end

  @doc ~S'''
  Converts a nonempty list of KW-lists to a CSV string.

      iex> table_to_csv([
      ...>   [{"headerA", "valueA1"}, {"headerB", "valueB1"}],
      ...>   [{"headerA", "valueA2"}, {"headerB", "valueB2"}]
      ...> ])
      """
      headerA,headerB
      valueA1,valueB1
      valueA2,valueB2
      """
  '''
  def table_to_csv(table) do
    table
    |> Stream.map(&Map.new/1)
    |> CSV.encode(headers: Enum.map(hd(table), &elem(&1, 0)), delimiter: "\n")
    |> Enum.join()
  end

  @stop_filters GlidesReport.Terminals.all_labeled_stops_and_groups()
  defp stop_filters, do: @stop_filters

  def build_csv_name(table_name, loader_settings, filter_settings) do
    %{
      env_suffix: env_suffix,
      start_dt: start_dt,
      end_dt: end_dt,
      sample_rate: sample_rate,
      sample_count: sample_count
    } = loader_settings

    %{
      stop_ids: stop_ids,
      limit_to_next_2_predictions: limit_to_next_2_predictions
    } = filter_settings

    env = if env_suffix == "", do: "prod", else: String.slice(env_suffix, 1..-1//1)

    dt_range =
      [start_dt, end_dt]
      |> Enum.map(&DateTime.shift_zone!(&1, "America/New_York"))
      |> Enum.map_join(
        "-",
        &(&1 |> DateTime.shift_zone!("America/New_York") |> Calendar.strftime("%xT%H:%M"))
      )

    stop_filter =
      Enum.find_value(stop_filters(), fn {parent_ids_set, label} ->
        if MapSet.equal?(parent_ids_set, stop_ids), do: label
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

    "Glides report - #{table_name} - #{env},#{dt_range}#{optionals},#{sampling}.csv"
  end
end
