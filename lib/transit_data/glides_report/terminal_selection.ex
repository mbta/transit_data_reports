defmodule TransitData.GlidesReport.TerminalSelection do
  @moduledoc """
  Custom kino control for selecting a set of terminal stops.
  """

  use Kino.JS, assets_path: "lib/assets/terminal_selection"
  use Kino.JS.Live

  alias Kino.JS.Live, as: LiveKino
  alias TransitData.GlidesReport.Terminal

  # Collections are stored as lists of tuples, to preserve order of inputs.
  @type state :: %{
          terminals: [{id :: Terminal.id(), terminal}],
          groups: [{id :: String.t(), group}]
        }

  @type terminal :: %{label: String.t(), checked: boolean}
  @type group :: %{label: String.t(), ids: list(Terminal.id())}

  @spec new(
          Enumerable.t({Terminal.id(), String.t()}),
          Enumerable.t({String.t(), String.t(), Enumerable.t(Terminal.id())})
        ) :: LiveKino.t()
  def new(terminals, groups \\ []) do
    terminals =
      for {id, label} <- terminals do
        {id, %{label: label, checked: false}}
      end

    groups =
      for {id, label, terminal_ids} <- groups do
        # A group's `checked` state is computed from its terminals,
        # does not need to be stored directly.
        {id, %{label: label, ids: Enum.to_list(terminal_ids)}}
      end

    validate!(terminals, groups)

    assigns = %{terminals: terminals, groups: groups}

    LiveKino.new(__MODULE__, assigns)
  end

  defp validate!(terminals, groups) do
    all_terminal_ids = Enum.map(terminals, &elem(&1, 0))

    all_ids = all_terminal_ids ++ Enum.map(groups, &elem(&1, 0))
    dups = all_ids |> Enum.frequencies() |> Map.filter(fn {_, n} -> n > 1 end)

    if map_size(dups) > 0 do
      raise "Duplicate ids found: #{inspect(Map.keys(dups))}. All ids must be unique."
    end

    all_grouped_ids =
      groups
      |> Enum.flat_map(fn {_id, group} -> group.ids end)
      |> MapSet.new()

    unmatched_ids = MapSet.difference(all_grouped_ids, MapSet.new(all_terminal_ids))

    if MapSet.size(unmatched_ids) > 0 do
      raise "Group(s) include one or more id for nonexistent terminals: #{inspect(MapSet.to_list(unmatched_ids))}"
    end
  end

  @spec toggle_terminal(LiveKino.t(), Terminal.id()) :: :ok
  def toggle_terminal(kino, id) do
    LiveKino.cast(kino, {:toggle_terminal, id})
  end

  def toggle_group(kino, id) do
    LiveKino.cast(kino, {:toggle_group, id})
  end

  def get_checked_terminals(kino) do
    LiveKino.call(kino, :get_checked_terminals)
  end

  @impl true
  def init(assigns, ctx) do
    {:ok, assign(ctx, assigns)}
  end

  @impl true
  def handle_connect(ctx) do
    {:ok, to_client_data(ctx.assigns), ctx}
  end

  @impl true
  def handle_cast({:toggle_terminal, id}, ctx) do
    {:noreply, do_toggle_terminal(id, ctx)}
  end

  def handle_cast({:toggle_group, id}, ctx) do
    {:noreply, do_toggle_group(id, ctx)}
  end

  @impl true
  def handle_call(:get_checked_terminals, _from, ctx) do
    checked = for {id, %{checked: true}} <- ctx.assigns.terminals, into: MapSet.new(), do: id
    {:reply, checked, ctx}
  end

  @impl true
  def handle_event("toggle_terminal", id, ctx) do
    ctx = do_toggle_terminal({:terminal, id}, ctx)
    update_client(ctx)
    {:noreply, ctx}
  end

  def handle_event("toggle_group", id, ctx) do
    ctx = do_toggle_group(id, ctx)
    update_client(ctx)
    {:noreply, ctx}
  end

  defp update_client(ctx) do
    broadcast_event(ctx, "update", to_client_data(ctx.assigns))
  end

  defp to_client_data(%{terminals: terminals, groups: groups}) do
    terminals_map = Map.new(terminals)

    groups =
      Enum.map(groups, fn {id, group} ->
        {checked?, indeterminate?} =
          case group_state(group, terminals_map) do
            :unchecked -> {false, false}
            :indeterminate -> {false, true}
            :checked -> {true, false}
          end

        [id, %{label: group.label, checked: checked?, indeterminate: indeterminate?}]
      end)

    terminals = Enum.map(terminals, fn {{:terminal, id}, state} -> [id, state] end)

    %{terminals: terminals, groups: groups}
  end

  defp do_toggle_terminal(terminal_id, ctx) do
    update(ctx, :terminals, fn terminals ->
      Enum.map(terminals, fn
        {^terminal_id, state} -> {terminal_id, %{state | checked: not state.checked}}
        other -> other
      end)
    end)
  end

  defp do_toggle_group(id, ctx) do
    terminals_map = Map.new(ctx.assigns.terminals)
    {^id, group} = Enum.find(ctx.assigns.groups, &match?({^id, _}, &1))

    # If all terminals in the group are checked, this behaves as a "deselect all".
    # Otherwise, it behaves as a "select all".
    checked = group_state(group, terminals_map) != :checked

    update(ctx, :terminals, fn terminals ->
      Enum.map(terminals, fn {id, state} ->
        {id, if(id in group.ids, do: %{state | checked: checked}, else: state)}
      end)
    end)
  end

  defp group_state(group, terminals_map) do
    terminals_in_group = Map.take(terminals_map, group.ids)
    checked_count = Enum.count(terminals_in_group, &match?({_id, %{checked: true}}, &1))
    len = length(group.ids)

    case checked_count do
      0 -> :unchecked
      ^len -> :checked
      _ -> :indeterminate
    end
  end
end
