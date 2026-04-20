# SPDX-FileCopyrightText: 2026 diffo-dev
# SPDX-License-Identifier: MIT

defmodule Artefact do
  @moduledoc """
  A knowledge graph fragment — a small, self-contained piece of knowledge
  expressed as a property graph.

  The canonical form is Arrows JSON. Everything else is derived from it.
  """

  defstruct [:id, :uuid, :title, :style, metadata: %{}, graph: %Artefact.Graph{}]

  @type t :: %__MODULE__{
          id: String.t(),
          uuid: String.t(),
          title: String.t() | nil,
          style: atom() | nil,
          graph: Artefact.Graph.t(),
          metadata: map()
        }

  @doc "Create a new Artefact with a generated UUIDv7."
  def new(attrs \\ []) do
    struct!(__MODULE__, [{:id, Artefact.UUID.generate_v7()}, {:uuid, Artefact.UUID.generate_v7()} | attrs])
  end
end
