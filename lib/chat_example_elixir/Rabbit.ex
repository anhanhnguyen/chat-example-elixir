require AMQP.Connection, as: Connection

defmodule ChatExampleElixir.Rabbit do
  def connect do
    # TODO
    # Implement a connection method to RabbitMQ
    # This is to make it easier to share the connection credentials
    your_name = my_name()
    host = "localhost"
    user = "guest"
    password = "guest"
    Connection.open(host: host,
                    port: 5672,
                    heartbeat: 60,
                    name: your_name,
                    username: user,
                    password: password
                    )
  end

  # Please fill in your data
  def my_name do
    "lajos"
  end

  # Use these methods to retrieve the names
  def common_exchange do
    "common-room"
  end

  def private_exchange do
    "private-messages"
  end

  def my_common_queue do
    "#{my_name}-common-queue"
  end

  def my_private_queue do
    "#{my_name}-private-queue"
  end

  def private_queue(user) do
    "#{user}-private-queue"
  end

  def chat_headers do
    [
      "chat-username": my_name()
    ]
  end

  def extract_header(headers, key, default) do
    case :lists.keyfind(key, 1, headers) do
      {key,longstr,value} -> value
      _ -> default
    end
  end

end
