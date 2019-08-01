defmodule ContractMonitor.ContractEventHandler do
  use GenServer

  alias Core.Listener
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
end
