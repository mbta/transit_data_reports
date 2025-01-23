defmodule TransitData.GlidesReport.Terminal do
  @moduledoc "Harcoded data on terminal stops, and fns to query it."

  @typedoc """
  ID for a terminal. Not the same as a stop ID!

  Convert to a parent stop ID with `to_parent_stop_id/1`.
  """
  @type id :: {:terminal, String.t()}

  @terminals [
    ##############
    # Green Line #
    ##############
    %{
      name: "Boston College",
      id: {:terminal, "place-lake"},
      tags: MapSet.new([:glides, :green, :b, :western, :light_rail]),
      stop_ids: MapSet.new(["70106"]),
      # -> South Street
      next: MapSet.new(["70110"])
    },
    %{
      name: "Cleveland Circle",
      id: {:terminal, "place-clmnl"},
      tags: MapSet.new([:glides, :green, :c, :western, :light_rail]),
      stop_ids: MapSet.new(["70238"]),
      # -> Englewood Avenue
      next: MapSet.new(["70236"])
    },
    %{
      name: "Riverside",
      id: {:terminal, "place-river"},
      tags: MapSet.new([:glides, :green, :d, :western, :light_rail]),
      stop_ids: MapSet.new(["70160", "70161"]),
      # -> Woodland
      next: MapSet.new(["70162"])
    },
    %{
      name: "Heath Street",
      id: {:terminal, "place-hsmnl"},
      tags: MapSet.new([:green, :e, :western, :light_rail]),
      stop_ids: MapSet.new(["70260"]),
      # -> Back of the Hill
      next: MapSet.new(["70258"])
    },
    %{
      name: "Union Square",
      id: {:terminal, "place-unsqu"},
      tags: MapSet.new([:glides, :green, :d, :northern, :light_rail]),
      stop_ids: MapSet.new(["70503", "70504"]),
      # -> Lechmere
      next: MapSet.new(["70502"])
    },
    %{
      name: "Medford/Tufts",
      id: {:terminal, "place-mdftf"},
      tags: MapSet.new([:glides, :green, :e, :northern, :light_rail]),
      stop_ids: MapSet.new(["70511", "70512"]),
      # -> Ball Square
      next: MapSet.new(["70510"])
    },
    ####################
    # Mattapan Trolley #
    ####################
    %{
      name: "Ashmont (Mattapan Trolley)",
      id: {:terminal, "place-asmnl__Mattapan"},
      tags: MapSet.new([:mattapan, :light_rail]),
      stop_ids: MapSet.new(["70261"]),
      # -> Cedar Grove
      next: MapSet.new(["70263"])
    },
    %{
      name: "Mattapan",
      id: {:terminal, "place-matt"},
      tags: MapSet.new([:glides, :mattapan, :light_rail]),
      stop_ids: MapSet.new(["70276"]),
      # -> Capen Street
      next: MapSet.new(["70274"])
    },
    ############
    # Red Line #
    ############
    %{
      name: "Alewife",
      id: {:terminal, "place-alfcl"},
      tags: MapSet.new([:red, :ashmont, :braintree, :heavy_rail]),
      stop_ids: MapSet.new(["70061", "Alewife-01", "Alewife-02"]),
      # -> Davis
      next: MapSet.new(["70063"])
    },
    %{
      name: "Ashmont (Red Line)",
      id: {:terminal, "place-asmnl__Red"},
      tags: MapSet.new([:red, :ashmont, :heavy_rail]),
      stop_ids: MapSet.new(["70094"]),
      # -> Shawmut
      next: MapSet.new(["70092"])
    },
    %{
      name: "Braintree",
      id: {:terminal, "place-brntn"},
      tags: MapSet.new([:red, :braintree, :heavy_rail]),
      stop_ids: MapSet.new(["70105", "Braintree-01", "Braintree-02"]),
      # -> Quincy Adams
      next: MapSet.new(["70104"])
    },
    ###############
    # Orange Line #
    ###############
    %{
      name: "Oak Grove",
      id: {:terminal, "place-ogmnl"},
      tags: MapSet.new([:orange, :heavy_rail]),
      stop_ids: MapSet.new(["70036", "Oak Grove-01", "Oak Grove-02"]),
      # -> Malden Center
      next: MapSet.new(["70034"])
    },
    %{
      name: "Forest Hills",
      id: {:terminal, "place-forhl"},
      tags: MapSet.new([:orange, :heavy_rail]),
      stop_ids: MapSet.new(["70001", "Forest Hills-01", "Forest Hills-02"]),
      # -> Green Street
      next: MapSet.new(["70003"])
    },
    #############
    # Blue Line #
    #############
    %{
      name: "Wonderland",
      id: {:terminal, "place-wondl"},
      tags: MapSet.new([:blue, :heavy_rail]),
      stop_ids: MapSet.new(["70059"]),
      # -> Revere Beach
      next: MapSet.new(["70057"])
    },
    %{
      name: "Bowdoin",
      id: {:terminal, "place-bomnl"},
      tags: MapSet.new([:blue, :heavy_rail]),
      stop_ids: MapSet.new(["70038"]),
      # -> Government Center
      next: MapSet.new(["70040"])
    }
  ]

  # %{stop_id => MapSet.t(stop_id)}
  @first_to_next_stop @terminals
                      |> Enum.flat_map(fn terminal ->
                        Enum.map(terminal.stop_ids, &{&1, terminal.next})
                      end)
                      |> Map.new()

  # %{stop_id => MapSet.t(stop_id)}
  # (@first_to_next_stop, but inverted)
  @next_to_first_stop @first_to_next_stop
                      |> Enum.flat_map(fn {k, sets} -> Enum.map(sets, &{k, &1}) end)
                      |> Enum.group_by(fn {_k, v} -> v end, fn {k, _v} -> k end)
                      |> Map.new(fn {k, vs} -> {k, MapSet.new(vs)} end)

  @stop_id_to_terminal_id @terminals
                          |> Enum.flat_map(fn terminal ->
                            Enum.concat(terminal.next, terminal.stop_ids)
                            |> Enum.map(&{&1, terminal.id})
                          end)
                          |> Map.new()

  def first_to_next_stop, do: @first_to_next_stop

  def next_to_first_stop, do: @next_to_first_stop

  def all_labeled_terminals_and_groups do
    {labeled_terminals(), labeled_terminal_groups()}
  end

  def labeled_terminal_groups do
    [
      {[], "All"},
      {[:glides], "GLIDES"},
      {[:light_rail], "Light rail"},
      {[:heavy_rail], "Heavy rail"},
      {[:green], "Green Line"},
      {[:mattapan], "Mattapan Trolley"},
      {[:red], "Red Line"},
      {[:orange], "Orange Line"},
      {[:blue], "Blue Line"}
    ]
    |> Enum.with_index(fn {tags, label}, i ->
      {"group#{i}", label, by_tags(tags)}
    end)
  end

  def labeled_terminals do
    Enum.map(terminals(), &{&1.id, &1.name})
  end

  def all_first_stops do
    first_to_next_stop()
    |> Map.keys()
    |> MapSet.new()
  end

  def all_next_stops do
    next_to_first_stop()
    |> Map.keys()
    |> MapSet.new()
  end

  def all_stops do
    MapSet.union(all_first_stops(), all_next_stops())
  end

  def by_tags(tags) when is_list(tags) do
    by_tags(MapSet.new(tags))
  end

  def by_tags(tags) do
    terminals()
    |> Enum.filter(&MapSet.subset?(tags, &1.tags))
    |> MapSet.new(& &1.id)
  end

  def by_name(name) do
    Enum.find_value(terminals(), &if(&1.name == name, do: MapSet.new([&1.id])))
  end

  @doc """
  Consolidates a child stop ID related to a terminal, to the ID of that terminal.

  This includes IDs of the terminal's platforms as well as IDs of the inbound platform of the next stop.

  Useful for simplifying the matching of trip updates with vehicle positions.
  """
  def normalize_stop_id(stop_id) do
    Map.fetch!(stop_id_to_terminal_id(), stop_id)
  end

  def to_parent_stop_id({:terminal, "place-asmnl" <> _}), do: "place-asmnl"
  def to_parent_stop_id({:terminal, terminal_id}), do: terminal_id

  defp terminals, do: @terminals

  defp stop_id_to_terminal_id, do: @stop_id_to_terminal_id
end
