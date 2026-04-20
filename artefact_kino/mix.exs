# SPDX-FileCopyrightText: 2026 diffo-dev
# SPDX-License-Identifier: MIT

defmodule ArtefactKino.MixProject do
  @moduledoc false
  use Mix.Project

  @version "0.1.0"
  @github_url "https://github.com/diffo-dev/artefactory"

  def project do
    [
      app: :artefact_kino,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      name: "ArtefactKino",
      description: "Livebook Kino widget for rendering Artefactory knowledge graphs via vis-network",
      source_url: @github_url,
      docs: docs()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:artefact, "~> 0.1", path: Path.expand("../artefact", __DIR__)},
      {:kino, "~> 0.14"},
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
      main: "ArtefactKino",
      source_url: @github_url,
      source_ref: "v#{@version}"
    ]
  end
end
