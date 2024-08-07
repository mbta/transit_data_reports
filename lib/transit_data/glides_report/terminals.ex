defmodule TransitData.GlidesReport.Terminals do
  @moduledoc "Harcoded data on terminal stops, and fns to query it."

  @terminals [
    %{
      name: "Boston College",
      parent_id: "place-lake",
      tags: MapSet.new([:glides, :green, :b, :western, :light_rail]),
      stop_ids: MapSet.new(["70106"]),
      # -> South Street
      next: MapSet.new(["70110"])
    },
    %{
      name: "Cleveland Circle",
      parent_id: "place-clmnl",
      tags: MapSet.new([:glides, :green, :c, :western, :light_rail]),
      stop_ids: MapSet.new(["70238"]),
      # -> Englewood Avenue
      next: MapSet.new(["70236"])
    },
    %{
      name: "Riverside",
      parent_id: "place-river",
      tags: MapSet.new([:glides, :green, :d, :western, :light_rail]),
      stop_ids: MapSet.new(["70160", "70161"]),
      # -> Woodland
      next: MapSet.new(["70162"])
    },
    # (Not a Glides terminal)
    %{
      name: "Heath Street",
      parent_id: "place-hsmnl",
      tags: MapSet.new([:green, :e, :western, :light_rail]),
      stop_ids: MapSet.new(["70260"]),
      # -> Back of the Hill
      next: MapSet.new(["70258"])
    },
    %{
      name: "Union Square",
      parent_id: "place-unsqu",
      tags: MapSet.new([:glides, :green, :d, :northern, :light_rail]),
      stop_ids: MapSet.new(["70503", "70504"]),
      # -> Lechmere
      next: MapSet.new(["70502"])
    },
    %{
      name: "Medford/Tufts",
      parent_id: "place-mdftf",
      tags: MapSet.new([:glides, :green, :e, :northern, :light_rail]),
      stop_ids: MapSet.new(["70511", "70512"]),
      # -> Ball Square
      next: MapSet.new(["70510"])
    },
    # (Not a Glides terminal)
    %{
      name: "Ashmont",
      parent_id: "place-asmnl",
      tags: MapSet.new([:mattapan, :light_rail]),
      stop_ids: MapSet.new(["70261"]),
      # -> Cedar Grove
      next: MapSet.new(["70263"])
    },
    %{
      name: "Mattapan",
      parent_id: "place-matt",
      tags: MapSet.new([:glides, :mattapan, :light_rail]),
      stop_ids: MapSet.new(["70276"]),
      # -> Capen Street
      next: MapSet.new(["70274"])
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

  @child_id_to_parent_id @terminals
                         |> Enum.flat_map(fn terminal ->
                           Enum.concat(terminal.next, terminal.stop_ids)
                           |> Enum.map(&{&1, terminal.parent_id})
                         end)
                         |> Map.new()

  def first_to_next_stop, do: @first_to_next_stop

  def next_to_first_stop, do: @next_to_first_stop

  def all_labeled_stops_and_groups do
    labeled_stop_groups() ++ labeled_stops()
  end

  def labeled_stop_groups do
    [
      {by_tags([:glides, :light_rail]), "All light rail terminal stops"},
      {by_tags([:glides, :green]), "All Green Line terminal stops"},
      {by_tags([:glides, :green, :western]), "Western Green Line terminal stops"},
      {by_tags([:glides, :green, :northern]), "Northern Green Line terminal stops"}
    ]
  end

  def labeled_stops do
    # (Heath Street and Ashmont are omitted -- not Glides terminals)
    [
      "Boston College",
      "Cleveland Circle",
      "Riverside",
      "Union Square",
      "Medford/Tufts",
      "Mattapan"
    ]
    |> Enum.map(&{by_name(&1), &1})
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
    |> MapSet.new(& &1.parent_id)
  end

  def by_name(name) do
    Enum.find_value(terminals(), &if(&1.name == name, do: MapSet.new([&1.parent_id])))
  end

  @doc """
  Consolidates a child stop ID related to a terminal, to the parent stop ID of that terminal.

  This includes IDs of the terminal's platforms as well as IDs of the inbound platform of the next stop.

  Useful for simplifying the matching of trip updates with vehicle positions.
  """
  def normalize_stop_id(stop_id) do
    Map.fetch!(child_to_parent_id(), stop_id)
  end

  defp terminals, do: @terminals

  defp child_to_parent_id, do: @child_id_to_parent_id
end
