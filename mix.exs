defmodule Eflatbuffers.MixProject do
  use Mix.Project

  def project do
    [
      app: :flatbuffer,
      version: "0.2.0",
      description: "Elixir Flatbuffer implementation",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: [:yecc, :leex] ++ Mix.compilers(),
      elixirc_paths: elixirc_paths(Mix.env()),
      preferred_cli_env: [
        "test.watch": :test
      ],
      source_url: "https://github.com/jallum/flatbuffer",
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/jallum/flatbuffer"
      }
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [extra_applications: [:logger]]
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
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
