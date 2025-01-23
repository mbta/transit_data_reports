defmodule TransitData.GlidesReport.VehiclePositionTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TransitData.GlidesReport.Generators.VehiclePosition, as: Gen

  alias TransitData.GlidesReport.VehiclePosition

  defp normalize(ve_pos) do
    ve_pos
    |> VehiclePosition.clean_up()
    |> AtomicMap.convert(underscore: false)
    |> VehiclePosition.normalize_stop_id()
  end

  describe "clean_up/1" do
    property "handles all vehicle positions" do
      check all(ve_pos <- Gen.valid_vehicle_position_generator()) do
        _ = VehiclePosition.clean_up(ve_pos)
        assert true
      end
    end

    property "removes unused fields" do
      check all(ve_pos <- Gen.relevant_vehicle_position_generator()) do
        cleaned = VehiclePosition.clean_up(ve_pos)
        assert is_nil(cleaned["vehicle"]["position"])
        assert is_nil(cleaned["vehicle"]["trip"]["last_trip"])
      end
    end

    property "discards nonrevenue vehicle positions" do
      check all(ve_pos <- Gen.nonrevenue_vehicle_position_generator()) do
        cleaned = VehiclePosition.clean_up(ve_pos)
        assert is_nil(cleaned)
      end
    end

    property "discards vehicle positions at stops other than those immediately following Glides terminals" do
      check all(ve_pos <- Gen.irrelevant_vehicle_position_generator()) do
        cleaned = VehiclePosition.clean_up(ve_pos)
        assert is_nil(cleaned)
      end
    end

    property "discards vehicle positions with missing stop_id" do
      check all(ve_pos <- Gen.missing_stop_id_vehicle_position_generator()) do
        cleaned = VehiclePosition.clean_up(ve_pos)
        assert is_nil(cleaned)
      end
    end

    property "discards vehicle positions with current_status other than IN_TRANSIT_TO/INCOMING_AT" do
      check all(ve_pos <- Gen.stopped_vehicle_position_generator()) do
        cleaned = VehiclePosition.clean_up(ve_pos)
        assert is_nil(cleaned)
      end
    end
  end

  describe "normalize_stop_ids/1" do
    property "converts child stop ID to parent stop ID" do
      check all(ve_pos <- Gen.relevant_vehicle_position_generator()) do
        normalized = normalize(ve_pos)
        assert {:terminal, "place-" <> _} = normalized.vehicle.terminal_id
      end
    end
  end

  describe "dedup_statuses/1" do
    property "chooses earlier of 2+ vehicle positions for same vehicle+trip+stop, no matter what order they appear in" do
      ###############################################
      # Create a list of vehicle positions composed #
      # of "filler" and a known set of duplicates.  #
      ###############################################
      filler =
        Gen.relevant_vehicle_position_generator()
        |> Stream.map(&normalize/1)
        |> Enum.take(50)

      trip_id = "a unique trip id"
      terminal_id = {:terminal, "a unique terminal id"}
      vehicle_id = "a unique vehicle id"

      dups =
        Gen.relevant_vehicle_position_generator()
        |> StreamData.map(fn ve_pos ->
          ve_pos
          |> normalize()
          |> put_in([:vehicle, :trip, :trip_id], trip_id)
          |> put_in([:vehicle, :terminal_id], terminal_id)
          |> put_in([:id], vehicle_id)
        end)
        |> Enum.take(3)

      earliest_time =
        dups
        |> Enum.map(& &1.vehicle.timestamp)
        |> Enum.min()

      ve_posns = dups ++ filler

      #############################################################
      # Repeatedly shuffle the list and check that dedup_statuses #
      # chooses the earliest of the dups in all cases.            #
      #############################################################
      check all(ordering <- StreamData.repeatedly(fn -> Enum.shuffle(ve_posns) end)) do
        deduped = VehiclePosition.dedup_statuses(ordering)

        matches =
          Enum.filter(
            deduped,
            &(&1.vehicle.trip.trip_id == trip_id and &1.vehicle.terminal_id == terminal_id and
                &1.id == vehicle_id)
          )

        assert length(matches) == 1
        assert hd(matches).vehicle.timestamp == earliest_time
      end
    end
  end
end
