require Logger

defmodule ChatExampleElixir do
  use Application

  @impl true
  def start(_type, _args) do
    IO.puts("hello\n")
    Logger.info("hello")
    ChatExampleElixir.Sup.start_link(name: ChatExampleElixir.Sup)
  end
end
