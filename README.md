# æternity contract monitor

An application which provides statistics for the usage of smart contracts on the æternity test network. It was built with the intention of showcasing the usage of the [Elixir SDK](https://github.com/aeternity/aepp-sdk-elixir/) event listener and is in no way polished enough. The [æternity middleware](https://github.com/aeternity/aepp-middleware) is used to retrieve historical data for contract transactions.

## Prerequisites
Ensure that you have [Elixir](https://elixir-lang.org/) and [Node.js](https://nodejs.org/en/) installed.

## How to run
- #### Backend
    `cd backend/contract_monitor/`
    
    `mix deps.get`
    
    `iex -S mix phx.server`
- #### Frontend
    `cd frontend/contract_monitor/`
    
    `npm i`
    
    `npm run serve`

## Usage
The application is hosted at http://localhost:8080. Inputting a contract address e.g. `ct_2imewm9yJyrqisYESfFgMWk7N1PeCeuj1T5Ej6cU1ebAzkFE7W` and pressing the `monitor` button will display the contract's data.
