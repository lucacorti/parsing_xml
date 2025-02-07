defmodule ParsingXML.MixProject do
  use Mix.Project

  def project do
    [
      app: :parsing_xml,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.0", only: [:dev], runtime: false},
      {:ecto, "~> 3.0"},
      {:recase, "~> 0.7"},
      {:saxy, "~> 1.0"}
    ]
  end
end
