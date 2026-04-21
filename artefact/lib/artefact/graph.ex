# SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Artefact.Node do
  @moduledoc """
  A node in an `%Artefact{}` graph.

  `id` is the local graph identifier (e.g. `"n0"`), stable within one artefact.
  `uuid` is the global identity — a UUIDv7 that survives compose and harmonise.
  `labels` are semantic type tags (base_label is applied at output time, not stored here).
  `position` is an optional `%{x, y}` hint for visual layout, sourced from Arrows JSON.
  """

  defstruct [:id, :uuid, :position, labels: [], properties: %{}]

  @type t :: %__MODULE__{
          id: String.t(),
          uuid: String.t(),
          labels: [String.t()],
          properties: map(),
          position: %{x: number(), y: number()} | nil
        }
end

defmodule Artefact.Relationship do
  @moduledoc """
  A directed relationship between two nodes in an `%Artefact{}` graph.

  `type` is a single CamelCase or SCREAMING_SNAKE_CASE string (Neo4j has no multi-label
  relationships). `from_id` and `to_id` reference node `id` fields within the same graph.
  """

  defstruct [:id, :type, :from_id, :to_id, properties: %{}]

  @type t :: %__MODULE__{
          id: String.t(),
          type: String.t(),
          from_id: String.t(),
          to_id: String.t(),
          properties: map()
        }
end

defmodule Artefact.Graph do
  @moduledoc """
  The property graph inside an `%Artefact{}` — a list of nodes and relationships.

  Constructed directly when building artefacts from structs:

      %Artefact.Graph{
        nodes: [%Artefact.Node{...}, ...],
        relationships: [%Artefact.Relationship{...}, ...]
      }
  """

  defstruct nodes: [], relationships: []

  @type t :: %__MODULE__{
          nodes: [Artefact.Node.t()],
          relationships: [Artefact.Relationship.t()]
        }
end
