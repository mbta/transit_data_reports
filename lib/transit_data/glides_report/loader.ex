defmodule TransitData.GlidesReport.Loader do
  @moduledoc "Functions to load Trip Updates and Vehicle Positions into memory."

  alias TransitData.GlidesReport.Util
  alias TransitData.GlidesReport

  # If a breaking change is made to how files are saved or how their data is structured,
  # this value lets us make a clean break to a new directory for downloads.
  defp loader_version, do: "1.2"

  @doc """
  Loads data into ETS tables, and returns counts of files found locally vs downloaded.

  `start_dt` and `end_dt` are NaiveDateTimes assumed to be in UTC.
  """
  @spec load_data(
          NaiveDateTime.t(),
          NaiveDateTime.t(),
          String.t(),
          pos_integer,
          pos_integer | :all
        ) :: %{local: non_neg_integer, downloaded: non_neg_integer}
  def load_data(start_dt, end_dt, env_suffix, sample_rate, sample_count) do
    dir = local_dir(env_suffix)

    IO.puts(
      "Data downloaded for this report will be saved in\n#{IO.ANSI.format([:underline, dir])}.\n"
    )

    File.mkdir_p!(dir)
    File.cd!(dir)

    tr_upd_deletion_task = set_up_table(:TripUpdates)
    ve_pos_deletion_task = set_up_table(:VehiclePositions)

    s3_bucket = "mbta-gtfs-s3#{env_suffix}"

    start_dt_utc = DateTime.from_naive!(start_dt, "Etc/UTC")
    end_dt_utc = DateTime.from_naive!(end_dt, "Etc/UTC")

    total_minutes = DateTime.diff(end_dt_utc, start_dt_utc, :minute)
    total_increments = div(total_minutes, sample_rate)

    # Prefixes used to list S3 objects timestamped within the same minute.
    minute_prefixes =
      Enum.map(0..total_increments, fn increment ->
        start_dt_utc
        |> DateTime.add(increment * sample_rate, :minute)
        |> Calendar.strftime("%Y/%m/%d/%Y-%m-%dT%H:%M")
      end)

    file_counts =
      [:TripUpdates, :VehiclePositions]
      |> Enum.map(&populate_table(&1, minute_prefixes, s3_bucket, sample_count))
      |> Enum.reduce(%{local: 0, downloaded: 0}, fn counts_for_table, acc ->
        Map.merge(acc, counts_for_table, fn _k, count1, count2 -> count1 + count2 end)
      end)

    deletion_tasks = Enum.reject([tr_upd_deletion_task, ve_pos_deletion_task], &is_nil/1)

    if Enum.any?(Task.yield_many(deletion_tasks, timeout: 1), &is_nil/1) do
      IO.puts("Waiting for previous table(s) to finish deleting...")
      Task.await_many(Enum.reject(deletion_tasks, &is_nil/1), :infinity)
      IO.puts("Done.")
    end

    file_counts
  end

  # Loads data into a table.
  # Returns the number of files that were found locally,
  # the number that were newly downloaded,
  # and a list of minutes for which not enough data could be found.
  defp populate_table(table_name, path_prefixes, s3_bucket, sample_count) do
    IO.puts("Loading #{table_name}...")

    {total, insufficients} =
      path_prefixes
      |> Stream.with_index(fn prefix, i ->
        IO.write([
          IO.ANSI.clear_line(),
          "\r",
          moons_of_progress()[rem(i, 8)],
          " Loading data for ",
          prefix_to_local_minute(prefix)
        ])

        prefix
      end)
      |> Task.async_stream(
        &load_minute(&1, s3_bucket, table_name, sample_count),
        ordered: false,
        timeout: 60_000
      )
      |> Stream.map(fn {:ok, result} -> result end)
      |> Enum.reduce({%{}, []}, fn counts, {total, insufficients} ->
        total =
          Map.merge(total, Map.delete(counts, :prefix), fn _k, running_total, count ->
            running_total + count
          end)

        insufficients =
          if is_integer(sample_count) and counts.local + counts.downloaded < sample_count,
            do: [prefix_to_local_minute(counts.prefix) | insufficients],
            else: insufficients

        {total, insufficients}
      end)

    IO.puts("#{IO.ANSI.clear_line()}\r🌝 Done")

    unless Enum.empty?(insufficients) do
      time_ranges =
        insufficients
        |> Enum.sort()
        |> Enum.split_while(&(&1 < "04"))
        |> then(fn {after_midnight_service_day, service_day} ->
          service_day ++ after_midnight_service_day
        end)
        |> Stream.map(&Time.from_iso8601!(&1 <> ":00"))
        # Chunk the individual times into ranges of consecutive times for better human readability.
        |> Stream.chunk_while(nil, &chunk_time_ranges/2, &{:cont, hh_mm_range(&1), nil})
        |> Stream.reject(&is_nil/1)
        |> Enum.join(", ")

      IO.puts("#{table_name}: Insufficient data available for minute(s): #{time_ranges}")
    end

    IO.puts("")
    total
  end

  defp s3_obj_name_pattern do
    ~r"""
    ^                                      # Anchor search to start of string
    (?<timestamp>\d+-\d+-\d+T\d+:\d+:\d+Z) # ISO8601 timestamp, excluding seconds and "Z"
    _.*                                    # Stuff we don't care about: seconds & name of data source
    (?<type>TripUpdates|VehiclePositions)  # Description of the file's contents
    """x
  end

  # 🌝
  defp moons_of_progress do
    %{0 => "🌕", 1 => "🌖", 2 => "🌗", 3 => "🌘", 4 => "🌑", 5 => "🌒", 6 => "🌓", 7 => "🌔"}
  end

  defp chunk_time_ranges(time, nil) do
    # This is the first time in the list.
    {:cont, {time, time}}
  end

  defp chunk_time_ranges(time, {prev_start, prev_end} = acc) do
    diff = Time.diff(time, prev_end, :minute)

    cond do
      diff == 1 ->
        # This time is right after the last. Continue extending the current range.
        {:cont, {prev_start, time}}

      diff > 1 ->
        # There's a gap between this time and the last. Emit the completed range and start a new one.
        {:cont, hh_mm_range(acc), {time, time}}

      # Edge case: crossing over midnight
      diff < 0 ->
        if Time.compare(Time.add(prev_end, 1, :minute), time) == :eq do
          # prev_end is 23:59, time is 00:00 -- treat times as consecutive.
          {:cont, {prev_start, time}}
        else
          # There's a gap. Emit the completed range and start a new one.
          {:cont, hh_mm_range(acc), {time, time}}
        end
    end
  end

  defp hh_mm_range({t1, t2}) do
    case Time.compare(t1, t2) do
      :eq -> hh_mm(t1)
      :lt -> "#{hh_mm(t1)}-#{hh_mm(t2)}"
    end
  end

  defp hh_mm(time), do: Calendar.strftime(time, "%H:%M")

  defp prefix_to_local_minute(prefix) do
    prefix
    |> prefix_to_dt()
    |> DateTime.shift_zone!("America/New_York")
    |> Calendar.strftime("%H:%M")
  end

  defp prefix_to_dt(prefix) do
    {:ok, dt, _} =
      prefix
      |> Path.basename()
      |> Kernel.<>(":00Z")
      |> DateTime.from_iso8601()

    dt
  end

  # Loads data for a specific minute of the service day, either by reading existing local files,
  # by downloading and reading new files from S3, or a mix of both.
  #
  # Returns counts of files loaded locally vs downloaded fresh,
  # tagged with the prefix for this minute.
  defp load_minute(minute_prefix, s3_bucket, table_name, sample_count) do
    case fetch_local_filenames(minute_prefix, table_name, sample_count) do
      {:ok, filenames} ->
        Enum.each(filenames, &load_file_into_table(table_name, &1))
        %{prefix: minute_prefix, local: Enum.count(filenames), downloaded: 0}

      {:download_more, existing_filenames} ->
        remaining_count =
          case sample_count do
            :all -> :all
            n -> n - Enum.count(existing_filenames)
          end

        new_filenames =
          download_files(
            minute_prefix,
            table_name,
            s3_bucket,
            remaining_count,
            existing_filenames
          )

        # (This will always be true when sample_count is :all bc of erlang term ordering.)
        # (Which is desirable, because we know all available data was dwnloaded in that case.)
        sample_count_not_achieved? =
          length(Enum.concat(existing_filenames, new_filenames)) < sample_count

        far_in_past? =
          DateTime.diff(DateTime.utc_now(), prefix_to_dt(minute_prefix), :minute) > 60

        if sample_count_not_achieved? and far_in_past? do
          # All available relevant data has been downloaded for this minute.
          # Write a blank file to act as a sentinel value
          # so we don't have to redo this (very slow) search again.
          File.touch!(all_available_data_downloaded_sentinel_filename(minute_prefix, table_name))
        end

        Enum.concat(existing_filenames, new_filenames)
        |> Enum.each(&load_file_into_table(table_name, &1))

        %{
          prefix: minute_prefix,
          local: Enum.count(existing_filenames),
          downloaded: Enum.count(new_filenames)
        }
    end
  end

  defp local_dir("-" <> env) do
    Path.join([Util.dataset_dir(), "glides_report", loader_version(), env])
  end

  defp local_dir(""), do: local_dir("-prod")

  # Returns names of existing local files that match the prefix and table name.
  # If:
  #   - at least `sample_count` matching files are found, OR
  #   - all relevant files have already been downloaded in a previous run,
  #   returns `{:ok, filenames}`.
  #
  # Otherwise, returns `{:download_more, found_existing_filenames}`.
  defp fetch_local_filenames(path_prefix, table_name, sample_count)
       when is_integer(sample_count) do
    filenames =
      Path.wildcard("#{table_name}_#{Path.basename(path_prefix)}*.etf")
      |> Enum.take(sample_count)

    if File.exists?(all_available_data_downloaded_sentinel_filename(path_prefix, table_name)) do
      # We've already saved all relevant data for this minute in S3.
      # Even if there's not enough, there's no point in trying to download more.
      {:ok, filenames}
    else
      if length(filenames) == sample_count do
        {:ok, filenames}
      else
        {:download_more, MapSet.new(filenames)}
      end
    end
  end

  defp fetch_local_filenames(path_prefix, table_name, :all) do
    filenames = Path.wildcard("#{table_name}_#{Path.basename(path_prefix)}*.etf")

    if File.exists?(all_available_data_downloaded_sentinel_filename(path_prefix, table_name)) do
      # We've already saved all relevant data for this minute in S3.
      {:ok, filenames}
    else
      # Whatever we found, it's not enough! Try and download more.
      # After that happens, the sentinel file will be created and we won't hit this case again.
      {:download_more, MapSet.new(filenames)}
    end
  end

  # Downloads VehiclePosition or TripUpdate files and returns the local filenames they were downloaded to.
  defp download_files(remote_prefix, table_name, s3_bucket, count, existing_filenames) do
    stream =
      ExAws.S3.list_objects(s3_bucket, prefix: remote_prefix)
      |> ExAws.stream!()
      # Find a file matching the prefix and table name.
      |> Stream.filter(&s3_object_match?(&1, table_name, existing_filenames))
      # Download the file to memory and stream the JSON objects under its "entity" key.
      |> Stream.map(&stream_s3_json(&1, s3_bucket))
      # Clean up and filter data.
      |> Stream.map(fn {objects, timestamp, filename} ->
        objects = clean_up(objects, timestamp, table_name)
        {objects, timestamp, filename}
      end)
      # If nothing is left from this file after cleanup, discard it entirely.
      |> Stream.reject(fn {objects, _, _} -> Enum.empty?(objects) end)
      # Now, actually save it to a file.
      |> Stream.map(fn {objects, timestamp, filename} ->
        objects =
          Stream.map(objects, fn obj ->
            AtomicMap.convert(obj, underscore: false)
          end)

        local_filename = s3_filename_to_local_filename(filename)

        write_data(objects, timestamp, local_filename)
        local_filename
      end)

    # Repeat until we have enough files, or exhaust all the matches.
    # Return names of the downloaded files.
    case count do
      :all -> Enum.to_list(stream)
      n -> Enum.take(stream, n)
    end
  end

  defp s3_object_match?(obj, table_name, existing_filenames) do
    s3_filename = Path.basename(obj.key)

    cond do
      not Regex.match?(~r"(realtime|rtr)_#{table_name}_enhanced.json.gz$", s3_filename) -> false
      s3_filename_to_local_filename(s3_filename) in existing_filenames -> false
      :else -> true
    end
  end

  defp stream_s3_json(obj, s3_bucket) do
    stream =
      ExAws.S3.download_file(s3_bucket, obj.key, :memory)
      |> ExAws.stream!()
      |> StreamGzip.gunzip()
      |> Jaxon.Stream.from_enumerable()

    timestamp =
      stream
      |> Jaxon.Stream.query([:root, "header", "timestamp"])
      |> Enum.at(0)

    objects = Jaxon.Stream.query(stream, [:root, "entity", :all])

    {objects, timestamp, Path.basename(obj.key)}
  end

  # Loads a locally-stored Erlang External Term Format file into an ETS table.
  defp load_file_into_table(table_name, local_path) do
    local_path
    |> File.read!()
    |> :erlang.binary_to_term()
    |> then(&:ets.insert(table_name, &1))
  end

  defp clean_up(json_stream, timestamp, :TripUpdates) do
    json_stream
    |> Stream.map(&GlidesReport.TripUpdate.clean_up(&1, timestamp))
    |> Stream.reject(&is_nil/1)
  end

  defp clean_up(json_stream, _timestamp, :VehiclePositions) do
    json_stream
    |> Stream.map(&GlidesReport.VehiclePosition.clean_up/1)
    |> Stream.reject(&is_nil/1)
  end

  # Saves data to a file using Erlang's External Term Format.
  # Data is structured as a list of tuples, which can be directly inserted into
  # an ETS table after reading back into memory.
  defp write_data(data, timestamp, filename) do
    iodata =
      data
      |> Enum.map(fn obj -> {"#{timestamp}_#{obj.id}", obj} end)
      |> :erlang.term_to_iovec([:compressed])

    File.write!(filename, iodata)
  end

  defp all_available_data_downloaded_sentinel_filename(minute_prefix, type) do
    "#{type}_#{Path.basename(minute_prefix)}_ALL_DOWNLOADED"
  end

  defp s3_filename_to_local_filename(filename) do
    %{"timestamp" => filename_timestamp, "type" => type} =
      Regex.named_captures(s3_obj_name_pattern(), filename)

    "#{type}_#{filename_timestamp}.etf"
  end

  # Creates or clears an ETS table.
  # If a previous table existed, returns pid of a background deletion task.
  defp set_up_table(table) do
    deletion_task =
      if :ets.whereis(table) != :undefined do
        IO.puts("Deleting previous #{inspect(table)} table in the background...")
        if table == :VehiclePositions, do: IO.puts("")

        :ets.rename(table, :"#{table}_OLD")
        Task.async(fn -> :ets.delete(:"#{table}_OLD") end)
      end

    :ets.new(table, [
      :named_table,
      :public,
      write_concurrency: :auto
    ])

    deletion_task
  end
end
