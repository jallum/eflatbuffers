defmodule Eflatbuffers.MixProject do
  use Mix.Project

  def project do
    [
      app: :eflatbuffers,
      version: "0.1.0",
      description: "Elixir/Erlang flatbuffers implementation",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: [:yecc, :leex] ++ Mix.compilers(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:flatbuffer_port,
       git: "https://github.com/reimerei/elixir-flatbuffers",
       branch: "master",
       only: :test,
       override: true},
      {:poison, "~> 6.0"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
