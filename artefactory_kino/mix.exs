# SPDX-FileCopyrightText: 2026 diffo-dev
# SPDX-License-Identifier: MIT

defmodule ArtefactoryKino.MixProject do
  @moduledoc false
  use Mix.Project

  @version "0.1.0"
  @github_url "https://github.com/diffo-dev/artefactory"

  def project do
    [
      app: :artefactory_kino,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      name: "ArtefactoryKino",
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
      {:artefactory, "~> 0.1", path: "../artefactory"},
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
      main: "ArtefactoryKino",
      source_url: @github_url,
      source_ref: "v#{@version}"
    ]
  end
end
