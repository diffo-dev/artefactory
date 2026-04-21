# SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule ArtefactoryNeo4j.MixProject do
  @moduledoc false
  use Mix.Project

  @version "0.1.0"
  @github_url "https://github.com/diffo-dev/artefactory"

  def project do
    [
      app: :artefactory_neo4j,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      name: "ArtefactoryNeo4j",
      description:
        "Neo4j persistence for Artefacts — read, write, and database lifecycle via Bolty and DozerDB",
      source_url: @github_url,
      docs: docs()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:artefact, "~> 0.1"},
      {:bolty, "~> 0.0.9"},
      {:ex_doc, "~> 0.37", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      files: ~w(lib .formatter.exs mix.exs README* CHANGELOG* LICENSES),
      links: %{"GitHub" => @github_url}
    ]
  end

  defp docs do
    [
      main: "ArtefactoryNeo4j",
      source_url: @github_url,
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end
end
