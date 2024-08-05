defmodule TransitData.GlidesReport.UtilTest do
  use ExUnit.Case, async: true

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
end
