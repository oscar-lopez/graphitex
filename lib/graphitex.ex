defmodule Graphitex do
  use GenServer

  @name __MODULE__

  @moduledoc """

  """

  defmodule Sample do
    defstruct metric: nil,
              value: nil,
              timestamp: nil
  end

  @carbon_port Application.get_env(:carbon, :port)
  @carbon_host Application.get_env(:carbon, :host)

  #####
  # Public API

  def start_link do
    {:ok, socket} = :gen_tcp.connect(@carbon_host, @carbon_port, [:binary, {:packet, 0}])
    GenServer.start_link(@name, socket, name: @name)
  end

  def write(bucket) do
    GenServer.cast @name, {:send, bucket}
  end

  #####
  # Private API

  def handle_cast({:send, bucket}, socket) do
    %Graphitex.Sample{metric: m, value: v, timestamp: ts} = bucket
    :ok = :gen_tcp.send(socket, "#{m} #{v} #{ts}\n")
    {:noreply, socket}
  end

  def terminate(_reason, state) do
    case state do
      nil    -> :ok
      socket -> :gen_tcp.close(socket)
    end
  end

  def code_change(_from_version, state, _extra) do
    {:ok, state}
  end

end
