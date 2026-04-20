# SPDX-FileCopyrightText: 2026 diffo-dev
# SPDX-License-Identifier: MIT

defmodule ArtefactKino do
  @moduledoc """
  Livebook Kino widget for rendering `%Artefact{}` knowledge graphs.

  Renders an interactive vis-network graph (left panel) alongside
  the derived Cypher fragment (right panel).

  ## Usage

      ArtefactKino.new(artefact)
      ArtefactKino.new(artefact, title: "us_two seed")

  ## Styles

  The `:style` field on `%Artefact{}` controls rendering:
  - `:sand_talk`      — dark sand background, ochre nodes and edges
  - `:arrows_default` — faithful to arrows.app colours
  - `nil`             — defaults to `:arrows_default`
  """

  # Not yet implemented — placeholder for artefact_kino package.
end
