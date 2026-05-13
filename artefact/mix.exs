# SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Artefact.MixProject do
  @moduledoc false
  use Mix.Project

  @version "0.2.0"
  @github_url "https://github.com/diffo-dev/artefactory"

  def project do
    [
      app: :artefact,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      package: package(),
      name: "Artefact",
      description: "Arrows JSON ↔ Cypher — knowledge graph fragments made in relationship",
      source_url: @github_url,
      docs: docs()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:splode, "~> 0.3"},
      {:igniter, ">= 0.6.29 and < 1.0.0-0", optional: true},
      {:ex_doc, "~> 0.37", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      files: ~w(lib .formatter.exs mix.exs README* CHANGELOG* MIGRATION* LICENSES usage-rules.md),
      links: %{"GitHub" => @github_url}
    ]
  end

  defp docs do
    [
      main: "Artefact",
      source_url: @github_url,
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "MIGRATION.md",
        {"LICENSES/MIT.txt", title: "License (MIT)"}
      ]
    ]
  end
end
