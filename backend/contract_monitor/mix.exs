defmodule ContractMonitor.MixProject do
  use Mix.Project

  def project do
    [
      app: :contract_monitor,
      version: "0.1.0",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {ContractMonitor.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:aepp_sdk_elixir,
       git: "https://github.com/aeternity/aepp-sdk-elixir.git",
       ref: "35d52bfa5a82c398cdacbcaf4acd4af83c5788a5"},
      {:cors_plug, "~> 2.0"},
      {:phoenix, "~> 1.4.9"},
      {:phoenix_pubsub, "~> 1.1"},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:ranch, "~> 1.7.1",
       [env: :prod, hex: "ranch", repo: "hexpm", optional: false, override: true]}
    ]
  end
end
