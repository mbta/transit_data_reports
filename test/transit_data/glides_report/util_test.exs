defmodule TransitData.GlidesReport.UtilTest do
  use ExUnit.Case, async: true
  doctest TransitData.GlidesReport.Util, import: true

  alias TransitData.GlidesReport.Util

  describe "stream_values/1" do
    test "streams values from a table" do
      table = :ets.new(__MODULE__.StreamValuesTable, [])

      objects = [a: 1, b: 2, c: 3, d: 4]
      :ets.insert(table, objects)

      expected_values = [1, 2, 3, 4]
      values_stream = Util.stream_values(table)

      assert expected_values == Enum.sort(values_stream)
    end
  end

  describe "zero_pad/2" do
    test "left-pads n with zeroes" do
      assert "00012" == Util.zero_pad(12, 5)
    end

    test "doesn't add padding when n is already long enough" do
      assert "12345" == Util.zero_pad(12_345, 3)
      assert "15" == Util.zero_pad(15, 2)
    end

    test "defaults to padding of 2" do
      assert "01" == Util.zero_pad(1)
    end
  end

  describe "format_percent/3" do
    test "formats ratio as a whole-number percentage" do
      assert "33%" == Util.format_percent(1, 3, "N/A")
    end

    test "uses zero fallback when denominator is integer 0" do
      assert "N/A" == Util.format_percent(5, 0, "N/A")
    end

    test "uses zero fallback when denominator is float 0" do
      assert "Not Applicable" == Util.format_percent(27, 0.0, "Not Applicable")
    end
  end

  describe "dataset_dir/0" do
    test "returns dataset directory" do
      assert String.ends_with?(Util.dataset_dir(), "transit_data_reports/dataset")
    end
  end

  describe "build_csv_name/3" do
    test "creates a descriptive filename for the table download" do
      alias TransitData.GlidesReport.Settings.{Filter, Load}
      alias TransitData.GlidesReport.Terminal

      table_name = "The Results"
      loader_settings = Load.new("", ~D[2024-08-05], ~D[2024-08-06], 1, nil)

      filter_settings =
        Filter.new(Terminal.by_tags([:green]), true, nil)

      expected =
        "Glides report - The Results - " <>
          "prod,2024-08-05 to 2024-08-06,terminals=Green Line," <>
          "next 2 predictions only,sampling=ALLper1min.csv"

      assert expected == Util.build_csv_name(table_name, loader_settings, filter_settings)
    end
  end
end
