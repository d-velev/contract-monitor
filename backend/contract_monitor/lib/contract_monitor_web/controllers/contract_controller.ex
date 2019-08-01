defmodule ContractMonitorWeb.ContractController do
  use ContractMonitorWeb, :controller

  alias ContractMonitor.ContractEventHandler

  def edit(conn, %{"contract_address" => contract_address}) do
    ContractEventHandler.subscribe_to_contract(contract_address)
    json(conn, :ok)
  end
end
