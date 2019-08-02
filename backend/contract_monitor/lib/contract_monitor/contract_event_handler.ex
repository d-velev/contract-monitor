defmodule ContractMonitor.ContractEventHandler do
  use GenServer

  alias Core.Listener
  alias Core.Client
  alias Utils.Encoding
  alias ContractMonitorWeb.NotificationChannel

  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_) do
    Listener.start("ae_uat")
    {:ok, %{}}
  end

  def subscribe_to_contract(contract_address),
    do: GenServer.call(__MODULE__, {:subscribe_to_contract, contract_address})

  def handle_call({:subscribe_to_contract, contract_address}, _from, state) do
    Listener.subscribe(
      :contract_calls,
      self(),
      contract_address
    )

    client =
      Client.new(
        %{
          public: "ak_6A2vcm1Sz6aqJezkLCssUXcyZTX7X8D5UwbuS2fRJr9KkYpRU",
          secret:
            "a7a695f999b1872acb13d5b63a830a8ee060ba688a478a08c6e65dfad8a01cd70bb4ed7927f97b51e1bcb5e1340d12335b2a2b12c8bc5221d63c4bcb39d41e61"
        },
        "ae_uat",
        "https://sdk-testnet.aepps.com/v2",
        "https://sdk-testnet.aepps.com/v2"
      )

    Listener.subscribe_for_contract_events(client, self(), contract_address)

    {:reply, :ok, state}
  end

  def handle_info(
        {:contract_calls, call_transaction},
        state
      ) do
    Logger.info(fn -> "Received new call transaction: #{inspect(call_transaction)}" end)
    NotificationChannel.notify_new_call(call_transaction)
    {:noreply, state}
  end

  def handle_info(
        {:contract_events, contract_event},
        state
      ) do
    Logger.info(fn -> "Received new contract event: #{inspect(contract_event)}" end)
    events = Enum.map(contract_event, fn event -> Encoding.prefix_decode_base64(event.data) end)
    NotificationChannel.notify_new_event(%{"events" => events})
    {:noreply, state}
  end
end
