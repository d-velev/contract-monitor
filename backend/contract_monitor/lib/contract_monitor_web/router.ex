defmodule ContractMonitorWeb.Router do
  use ContractMonitorWeb, :router

  pipeline :api do
    plug(CORSPlug, origin: "*")
    plug(:accepts, ["json"])
  end

  scope "/", ContractMonitorWeb do
    pipe_through(:api)
    resources("/set-contract", ContractController, param: "contract_address", only: [:edit])
  end
end
