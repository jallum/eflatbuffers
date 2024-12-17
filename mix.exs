defmodule Eflatbuffers.Mixfile do
  use Mix.Project

  def project do
    [
      app: :eflatbuffers,
      version: "0.1.0",
      description: "Elixir/Erlang flatbuffers implementation",
      package: package(),
      elixir: "~> 1.15",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: [:yecc, :leex] ++ Mix.compilers(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  defp package() do
    [
      name: "eflatbuffers",
      files: ["config", "lib", "src", "test", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Florian Odronitz"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/wooga/eflatbuffers"}
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
      {:poison, ">= 0.0.0"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
