defmodule TransitData.GlidesReport.UtilTest do
  use ExUnit.Case, async: true

  alias TransitData.GlidesReport.Util

  describe "stream_values/1" do
    setup do
      table = :ets.new(TransitData.GlidesReport.UtilTest.Table)
      on_exit(fn -> :ets.delete(table) end)

      %{table: table}
    end

    test "streams values from a table", %{table: table} do
      objects = [a: 1, b: 2, c: 3, d: 4]
      :ets.insert(table, objects)

      from_stream = Util.stream_values(table)

      assert Enum.sort(objects) == Enum.sort(from_stream)
    end
  end
end
