require ChatExampleElixir.Rabbit, as: Rabbit
require AMQP.Channel, as: Channel
require AMQP.Basic, as: Basic
require AMQP.Exchange, as: Exchange
require AMQP.Confirm, as: Confirm
require Logger

defmodule ChatExampleElixir.Writer do
  use GenServer

  ## Missing Client API - will add this later

  ## Defining GenServer Callbacks

  @impl true
  def init(:ok) do
    # TODO: 1. Implement `Rabbit.connect`
    {:ok, connection} = Rabbit.connect()

    {:ok, %{
      connection: connection,
      channel: init_channel(connection)
    }}
  end

  def init_channel(connection) do
    # TODO: 2. Open a channel
    {:ok, channel} = Channel.open(connection)

    #  We need to monitor the channel
    Process.monitor(channel.pid)

    # TODO: Declare the "common-room", use `Rabbit.common_exchange` as a name
    # It should be a :fanout type exchange
    Exchange.fanout(channel, Rabbit.common_exchange())
    Exchange.direct(channel, Rabbit.private_exchange())

    # TODO: Turn on publish confirms for this channel
    Confirm.register_handler(channel, self())
    Confirm.select(channel)

    channel
  end

  def write_common(message) do
    GenServer.call(ChatExampleElixir.Writer, {:write_common, message})
  end

  def write_private(user, message) do
    GenServer.call(__MODULE__, {:write_private, user, message})
  end

  @impl true
  def handle_call({:write_common, message}, _from, %{
    channel: channel
  } = state) do
    # We put chat-username as a header for all messages
    headers = [
      "chat-username": Rabbit.my_name
    ]

    # TODO Publish a message to `Rabbit.common_exchange`
    # Dont forget to include the headers
    Basic.publish(channel, Rabbit.common_exchange(), "", message, headers: headers)

    # TODO: Wait for publish confirms
    Confirm.wait_for_confirms(channel)

    {:reply, :ok, state}
  end

  def handle_call({:write_private, user, message}, _from, %{channel: channel} = state) do
    Basic.publish(channel, Rabbit.private_exchange(), user, message, headers: Rabbit.chat_headers(), mandatory: true)

    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:create, name}, names) do
    if Map.has_key?(names, name) do
      {:noreply, names}
    else
      {:ok, bucket} = KV.Bucket.start_link([])
      {:noreply, Map.put(names, name, bucket)}
    end
  end

  @impl true
  def handle_info({:basic_ack, tag, _multiple}, state) do
    Logger.debug("Received basic ACK delivery_tag #{tag}")
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, message}, state) do
    Logger.error("Channel #{inspect(state.channel.pid)} closed: #{inspect(message)}")
    channel = init_channel(state.connection)

    Logger.debug("Open a new channel: #{inspect(channel.pid)}")
    {:noreply, Map.put(state, :channel, channel)}
  end

  def handle_info(message, state) do
    # We'd need to handle reconnects here for example
    Logger.error("Received unhandled message")
    IO.inspect(message)
#     14:14:02.733 [error] Received unhandled message
#     {:DOWN, #Reference<0.2454447442.4097572867.259601>, :process, #PID<0.296.0>,
#     {:shutdown,
#       {:server_initiated_close, 404,
#       "NOT_FOUND - no exchange 'common-room' in vhost '/'"}}}
# nil
    {:noreply, state}
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end
end
