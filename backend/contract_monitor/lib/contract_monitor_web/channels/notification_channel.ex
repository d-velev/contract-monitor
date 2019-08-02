defmodule ContractMonitorWeb.NotificationChannel do
  use Phoenix.Channel

  alias ContractMonitorWeb.Endpoint

  def notify_new_call(call_transaction) do
    Endpoint.broadcast!("room:notifications", "new_call", call_transaction)
  end

  def notify_new_event(event) do
    Endpoint.broadcast!("room:notifications", "new_event", event)
  end

  def join("room:notifications", _message, socket) do
    {:ok, socket}
  end

  def join("room:" <> _private_subtopic, _message, _socket) do
    {:error, %{reason: "unauthorized"}}
  end
end
