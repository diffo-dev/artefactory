# SPDX-FileCopyrightText: 2026 diffo-dev
# SPDX-License-Identifier: MIT

defmodule Artefact.MixProject do
  @moduledoc false
  use Mix.Project

  @version "0.1.0"
  @github_url "https://github.com/diffo-dev/artefactory"

  def project do
    [
      app: :artefact,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      name: "Artefact",
      description: "Arrows JSON ↔ Cypher — knowledge graph fragments made in relationship",
      source_url: @github_url,
      docs: docs()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.37", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      files: ~w(lib .formatter.exs mix.exs README* LICENSES),
      links: %{"GitHub" => @github_url}
    ]
  end

  defp docs do
    [
      main: "Artefact",
      source_url: @github_url,
      source_ref: "v#{@version}"
    ]
  end
end
