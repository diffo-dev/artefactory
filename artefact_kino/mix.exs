# SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule ArtefactKino.MixProject do
  @moduledoc false
  use Mix.Project

  @version "0.1.4"
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
      description:
        "Livebook Kino widget for rendering Artefactory knowledge graph fragments (Artefacts)",
      source_url: @github_url,
      docs: docs()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      artefact_dep(),
      {:kino, "~> 0.14"},
      {:ex_doc, "~> 0.37", only: [:dev, :test], runtime: false}
    ]
  end

  # Local path dep when running inside the monorepo, hex dep otherwise.
  # `mix hex.publish` rejects path deps, so set HEX_PUBLISH=1 (or run from
  # outside the repo) to force the hex form when shipping.
  defp artefact_dep do
    cond do
      System.get_env("HEX_PUBLISH") == "1" ->
        {:artefact, "~> 0.1.4"}

      File.exists?(Path.join(__DIR__, "../artefact/mix.exs")) ->
        {:artefact, path: "../artefact"}

      true ->
        {:artefact, "~> 0.1.4"}
    end
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
      main: "ArtefactKino",
      source_url: @github_url,
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "CHANGELOG.md",
        {"artefact_kino.livemd", title: "Livebook"},
        {"LICENSES/MIT.txt", title: "License (MIT)"}
      ]
    ]
  end
end
