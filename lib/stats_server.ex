defmodule StatsServer do
  use GenServer
  require Logger

  @moduledoc """
  Generic GenServer which collect stats, stores them in the server's state
  and periodically send them to a Grafana metrics server.
  """

  @name              __MODULE__
  @carbon_host       Application.get_env(:carbon, :host)
  @carbon_port       Application.get_env(:carbon, :port)
  @prepend_hostname? Application.get_env(:stats, :prepend_hostname)

  #####
  # Public API

  @doc """
  Start the Stats server
  prefix:   prefix to be displayed in Grafana. For example: "messaging.pushes."
  interval: time between updates, in milliseconds. For example: 60_000
  tags:     map of identifiers and descriptions of the metrics. For example:
            %{sent_pushes: "sent", failed_pushes: "failed"}
  """
  def start_link(prefix, interval, tags) do
    GenServer.start_link(@name, {prefix, interval, tags}, name: @name)
  end

  @doc "Stop the Stats server"
  def stop() do
    GenServer.cast(@name, :stop)
  end

  @doc "Obtain the current counter value for the given metric"
  def get(metric) do
    GenServer.call(@name, {:get, metric})
  end

  @doc "Increment the given metric counter value by one unit"
  def increment(metric) do
    GenServer.cast(@name, {:increment, metric})
  end

  #####
  # Server Callbacks

  @doc """
  Initializes the server's state, launches a timer that periodically
  sends all the metrics it has collected
  """
  def init({prefix, interval, tags}) do
    start_send_timer(interval)
    {:ok, socket} = :gen_tcp.connect(@carbon_host, @carbon_port, [:binary, {:packet, 0}])
    {:ok, {socket, prefix, interval, tags, init_metrics(tags)}}
  end

  @doc "Sends the collected metrics to the Grafana server and resets the timer and the counters"
  def handle_info(:send, {socket, prefix, interval, tags, metrics}) do
    send(socket, prefix, tags, metrics)
    start_send_timer(interval)
    {:noreply, {socket, prefix, interval, tags, init_metrics(tags)}}
  end

  @doc "Handles the :get request and obtains the value of the given metric"
  def handle_call({:get, metric}, _from, {_, _, _, _, metrics}=state) do
    {:reply, metrics[metric], state}
  end

  @doc "Increment by one unit the specified metric counter"
  def handle_cast({:increment, metric}, {socket, prefix, interval, tags, metrics}) do
    if Dict.has_key?(metrics, metric) do
      new_metrics = Dict.update!(metrics, metric, &(&1+1))
    else
      new_metrics = metrics
    end
    {:noreply, {socket, prefix, interval, tags, new_metrics}}
  end
  @doc "Handle the :stop message"
  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end

  @doc "Terminate the server"
  def terminate(reason, {socket, _, _, _, _}) do
    Logger.info("#{inspect @name} terminated with reason: #{inspect reason}")
    :gen_tcp.close(socket)
  end

  @doc "Code change handler"
  def code_change(_from_version, state, _extra) do
    {:ok, state}
  end

  #####
  # Private Helper Functions

  defp start_send_timer(interval) do
    :erlang.send_after(interval, self, :send)
  end

  defp init_metrics(tags) do
    for key <- Dict.keys(tags), into: %{}, do: {key, 0}
  end

  defp send(socket, base_prefix, tags, metrics) do
    ts     = generate_timestamp()
    prefix = generate_prefix(base_prefix)
    Enum.each(metrics, fn({metric, counter}) ->
      m   = prefix <> tags[metric]
      :ok = :gen_tcp.send(socket, "#{m} #{counter} #{ts}\n")
    end)
  end

  defp generate_timestamp() do
    epoch = 719528 * 24 * 3600
    :calendar.datetime_to_gregorian_seconds(:calendar.now_to_universal_time(:erlang.now)) - epoch
  end

  defp generate_prefix(base_prefix) do
    if @prepend_hostname? do
      {:ok, hostname} = :inet.gethostname()
      List.to_string(hostname) <> "." <> base_prefix
    else
      base_prefix
    end
  end

end
