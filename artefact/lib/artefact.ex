# SPDX-FileCopyrightText: 2026 diffo-dev
# SPDX-License-Identifier: MIT

defmodule Artefact do
  @moduledoc """
  A knowledge graph fragment — a small, self-contained piece of knowledge
  expressed as a property graph.

  The canonical form is Arrows JSON. Everything else is derived from it.
  """

  defstruct [:id, :title, :style, metadata: %{}, graph: %Artefact.Graph{}]

  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t() | nil,
          style: atom() | nil,
          graph: Artefact.Graph.t(),
          metadata: map()
        }

  @doc "Create a new Artefact with a generated UUID."
  def new(attrs \\ []) do
    struct!(__MODULE__, [{:id, generate_id()} | attrs])
  end

  defp generate_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
    |> then(fn hex ->
      <<a::binary-size(8), b::binary-size(4), c::binary-size(4), d::binary-size(4), e::binary-size(12)>> = hex
      "#{a}-#{b}-#{c}-#{d}-#{e}"
    end)
  end
end
