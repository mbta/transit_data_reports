defmodule TransitData.DataLake do
  @moduledoc """
  Functions to work with our mbta-gtfs-s3* data lake buckets.
  """

  #############
  # Callbacks #
  #############

  @doc """
  Returns a stream of keys of objects in the given bucket that match the given prefix.
  """
  @callback stream_object_keys(bucket :: String.t(), prefix :: String.t()) ::
              Enumerable.t(String.t())

  @doc """
  Returns a stream of the contents of a data lake JSON file.

  Returns a tuple containing:
  - a stream of maps, parsed from the JSON's `entity` field
  - the timestamp, parsed from the JSON's `header` field
  - the basename of the object's key
  """
  @callback stream_json(bucket :: String.t(), key :: String.t()) ::
              {data :: Enumerable.t(map()), timestamp :: integer, basename :: String.t()}

  #################################
  # Dispatching to implementation #
  #################################

  # The module adopting this behaviour that we use for the current environment.
  @callback_module Application.compile_env(:transit_data, :data_lake_api, TransitData.S3DataLake)

  defdelegate stream_object_keys(bucket, prefix), to: @callback_module
  defdelegate stream_json(bucket, key), to: @callback_module
end

defmodule TransitData.S3DataLake do
  @moduledoc false

  @behaviour TransitData.DataLake

  @impl true
  def stream_json(bucket, key) do
    stream =
      ExAws.S3.download_file(bucket, key, :memory)
      |> ExAws.stream!()
      |> StreamGzip.gunzip()
      |> Jaxon.Stream.from_enumerable()

    timestamp =
      stream
      |> Jaxon.Stream.query([:root, "header", "timestamp"])
      |> Enum.at(0)

    objects = Jaxon.Stream.query(stream, [:root, "entity", :all])

    {objects, timestamp, Path.basename(key)}
  end

  @impl true
  def stream_object_keys(bucket, prefix) do
    ExAws.S3.list_objects(bucket, prefix: prefix)
    |> ExAws.stream!()
    |> Stream.map(& &1.key)
  end
end
