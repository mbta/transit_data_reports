defmodule TransitData.GlidesReport.Util do
  @moduledoc """
  Miscellaneous utility functions for the report.
  """

  alias TransitData.GlidesReport.Terminal

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
  Combines any consecutive, overlapping ranges in an enumerable.

  All ranges in the enumerable must have a step of 1.
  The returned list will be sorted.

      iex> ranges = [1..2, 3..8, 7..12, 7..10, 15..20]
      iex> merge_ranges(ranges)
      [1..2, 3..12, 15..20]
      iex> merge_ranges(Enum.reverse(ranges)) == merge_ranges(ranges)
      true
      iex> merge_ranges(Enum.shuffle(ranges)) == merge_ranges(ranges)
      true

      iex> merge_ranges([1..2//1, 2..0//-1])
      ** (ArgumentError) received range(s) with step != 1: [2..0//-1]

      iex> merge_ranges([1..5//2, 3..12//3])
      ** (ArgumentError) received range(s) with step != 1: [1..5//2, 3..12//3]

      iex> merge_ranges([])
      []
  """
  @spec merge_ranges(Enumerable.t(Range.t())) :: list(Range.t())
  def merge_ranges(ranges) do
    bad_ranges = Enum.reject(ranges, &match?(_.._//1, &1))

    unless bad_ranges == [],
      do: raise(ArgumentError, "received range(s) with step != 1: #{inspect(bad_ranges)}")

    ranges
    |> Enum.sort_by(fn l.._r//1 -> l end)
    |> Enum.reject(&(Range.size(&1) == 0))
    |> Enum.chunk_while(
      nil,
      fn
        range, nil ->
          {:cont, range}

        range, acc_range ->
          if Range.disjoint?(range, acc_range),
            do: {:cont, acc_range, range},
            else: {:cont, merge_range_pair(acc_range, range)}
      end,
      fn
        nil -> {:cont, nil}
        final_acc -> {:cont, final_acc, nil}
      end
    )
  end

  defp merge_range_pair(l1..r1//1, l2..r2//1) do
    min(l1, l2)..max(r1, r2)//1
  end

  @doc """
  Formats the ratio of two numbers as a percentage.
  """
  @spec format_percent(number, number, String.t()) :: String.t()
  def format_percent(_numerator, denominator, zero_fallback)
      # Using a guard with `==` instead of directly pattern matching on 0
      # (which implicitly uses `===`) so that both int 0 and float 0.0
      # fall within this clause.
      when denominator == 0 do
    zero_fallback
  end

  def format_percent(numerator, denominator, _zero_fallback) do
    p = round(100.0 * (numerator / denominator))
    "#{p}%"
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

  def build_csv_name(table_name, loader_settings, filter_settings) do
    %{
      env_suffix: env_suffix,
      start_date: start_date,
      end_date: end_date,
      sample_rate: sample_rate,
      sample_count: sample_count
    } = loader_settings

    %{
      terminal_ids: terminal_ids,
      limit_to_next_2_predictions: limit_to_next_2_predictions
    } = filter_settings

    env = if env_suffix == "", do: "prod", else: String.slice(env_suffix, 1..-1//1)

    dt_range =
      if Date.compare(start_date, end_date) == :eq,
        do: "#{start_date}",
        else: "#{start_date} to #{end_date}"

    terminals_filter =
      Enum.find_value(Terminal.labeled_terminal_groups(), fn {_id, label, terminals_in_group} ->
        if MapSet.equal?(terminals_in_group, terminal_ids), do: label
      end)

    terminals_filter =
      if terminals_filter do
        terminals_filter
      else
        terminal_to_name = Map.new(Terminal.labeled_terminals())
        Enum.map_join(terminal_ids, ",", &Map.fetch!(terminal_to_name, &1))
      end

    sample_count = if sample_count == :all, do: "ALL", else: sample_count

    sampling = "sampling=#{sample_count}per#{sample_rate}min"

    terminals = "terminals=#{terminals_filter}"

    optionals =
      [{limit_to_next_2_predictions, "next 2 predictions only"}]
      |> Enum.filter(&elem(&1, 0))
      |> Enum.map_join(",", &elem(&1, 1))
      |> case do
        "" -> ""
        str -> ",#{str}"
      end

    "Glides report - #{table_name} - #{env},#{dt_range},#{terminals}#{optionals},#{sampling}.csv"
  end
end
