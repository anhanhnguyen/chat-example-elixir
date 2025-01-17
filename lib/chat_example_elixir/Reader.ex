require ChatExampleElixir.Rabbit, as: Rabbit
require AMQP.Channel, as: Channel
require AMQP.Basic, as: Basic
require AMQP.Exchange, as: Exchange
require AMQP.Queue, as: Queue
require AMQP.Confirm, as: Confirm
require Logger

defmodule ChatExampleElixir.Reader do
  use GenServer
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

    # TODO: Set prefetch count
    #  NOTE: It should be not "global" acknowledgments
    Basic.qos(channel, prefetch_count: 1)

    # TODO: Declare queues
    # Use the `Rabbit.my_common_queue` method to get the queuename
    # Declare your queue with a queue expiry, either with policies or queue arguments
    Queue.declare(channel, Rabbit.my_common_queue(), exclusive: true)
    Queue.declare(channel, Rabbit.my_private_queue(), exclusive: true)


    # TODO: Bind the common exchange and your queue
    # Remember the common exchange is a fanout type
    Queue.bind(channel, Rabbit.my_common_queue(), Rabbit.common_exchange())
    Queue.bind(channel, Rabbit.my_private_queue(), Rabbit.private_exchange(), routing_key: Rabbit.my_name)

    # TODO: Consume from the queue
    Basic.consume(channel, Rabbit.my_common_queue())
    Basic.consume(channel, Rabbit.my_private_queue())

    channel
  end

  def handle_info({:basic_deliver, payload, meta}, state) do
    # IO.inspect(meta)
    delivery_tag = meta.delivery_tag
    exchange = meta.exchange
    sender = Rabbit.extract_header(meta.headers, "chat-username", "UNDEFINED")
    Logger.info("[#{exchange}][#{sender}] #{payload}")
    # TODO Acknowledge the message
    Basic.ack(state.channel, delivery_tag)

    {:noreply, state}
  end

  def handle_info({:basic_consume_ok, %{consumer_tag: tag}}, state) do
    Logger.debug("Received basic consume OK: #{tag}")
    {:noreply, state}
  end

  @impl true
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
