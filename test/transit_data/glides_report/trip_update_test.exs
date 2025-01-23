defmodule TransitData.GlidesReport.TripUpdateTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TransitData.GlidesReport.Generators.TripUpdate, as: Gen

  alias TransitData.GlidesReport.TripUpdate

  # Clean up a trip update, using a defined constant as the header timestamp.
  defp clean_up(tr_upd) do
    TripUpdate.clean_up(tr_upd, Gen.header_timestamp())
  end

  # Convert a raw-map trip update to a cleaned-up version with atom keys.
  defp normalize(tr_upd) do
    tr_upd
    |> clean_up()
    |> AtomicMap.convert(underscore: false)
    |> TripUpdate.normalize_stop_ids()
  end

  describe "clean_up/2" do
    property "handles all valid trip updates" do
      check all(tr_upd <- Gen.valid_trip_update_generator()) do
        _ = clean_up(tr_upd)
        assert true
      end
    end

    property "removes unused fields" do
      check all(tr_upd <- Gen.relevant_trip_update_generator()) do
        cleaned = clean_up(tr_upd)

        refute is_nil(cleaned)

        assert is_nil(cleaned["trip_update"]["vehicle"])
        assert is_nil(cleaned["trip_update"]["trip"]["direction_id"])

        Enum.each(cleaned["trip_update"]["stop_time_update"], &assert(is_nil(&1["arrival"])))
      end
    end

    property "subs header timestamp in for missing .trip_update.timestamp" do
      check all(tr_upd <- Gen.missing_timestamp_trip_update_generator()) do
        cleaned = clean_up(tr_upd)
        assert cleaned["trip_update"]["timestamp"] == Gen.header_timestamp()
      end
    end

    property "discards stop_times without defined departure times" do
      check all(
              tr_upd <- Gen.relevant_trip_update_generator(),
              Enum.any?(
                tr_upd["trip_update"]["stop_time_update"],
                &is_nil(&1["departure"]["time"])
              )
            ) do
        cleaned = clean_up(tr_upd)

        Enum.each(
          cleaned["trip_update"]["stop_time_update"],
          &refute(is_nil(&1["departure"]["time"]))
        )
      end
    end

    property "discards canceled trips" do
      check all(tr_upd <- Gen.canceled_trip_update_generator()) do
        cleaned = clean_up(tr_upd)
        assert is_nil(cleaned)
      end
    end

    property "discards nonrevenue trips" do
      check all(tr_upd <- Gen.nonrevenue_trip_update_generator()) do
        cleaned = clean_up(tr_upd)
        assert is_nil(cleaned)
      end
    end
  end

  describe "normalize_stop_ids/1" do
    property "converts child stop IDs to terminal IDs" do
      check all(tr_upd <- Gen.relevant_trip_update_generator()) do
        normalized = normalize(tr_upd)

        Enum.each(
          normalized.trip_update.stop_time_update,
          fn stop_time -> assert {:terminal, "place-" <> _} = stop_time.terminal_id end
        )
      end
    end
  end

  describe "filter_terminals/2" do
    property "removes terminals not in the filter list, returns nil if all terminals are filtered" do
      check all(tr_upd <- Gen.relevant_trip_update_generator()) do
        normalized = normalize(tr_upd)
        filtered = TripUpdate.filter_terminals(normalized, [{:terminal, "place-river"}])

        if {:terminal, "place-river"} in get_in(normalized, [
             :trip_update,
             :stop_time_update,
             Access.all(),
             :terminal_id
           ]) do
          Enum.each(
            filtered.trip_update.stop_time_update,
            &assert(&1.terminal_id == {:terminal, "place-river"})
          )
        else
          assert is_nil(filtered)
        end
      end
    end
  end

  describe "filter_by_advance_notice/2" do
    property "returns trip update unchanged if no advance notice filter is set" do
      check all(tr_upd <- Gen.relevant_trip_update_generator()) do
        normalized = normalize(tr_upd)
        filtered = TripUpdate.filter_by_advance_notice(normalized, nil)

        assert normalized == filtered
      end
    end

    property "removes updates with too-short notice, returns nil if all updates are filtered" do
      check all(tr_upd <- Gen.short_notice_trip_update_generator(30, 90)) do
        normalized = normalize(tr_upd)
        filtered = TripUpdate.filter_by_advance_notice(normalized, 60)

        if Enum.any?(
             get_in(normalized, [:trip_update, :stop_time_update, Access.all(), :departure, :time]),
             &(&1 >= normalized.trip_update.timestamp + 60)
           ) do
          Enum.each(
            filtered.trip_update.stop_time_update,
            &assert(&1.departure.time >= filtered.trip_update.timestamp + 60)
          )
        else
          assert is_nil(filtered)
        end
      end
    end
  end
end
