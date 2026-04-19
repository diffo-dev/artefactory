# SPDX-FileCopyrightText: 2026 diffo-dev
# SPDX-License-Identifier: MIT

defmodule Artefactory.Node do
  @moduledoc false
  defstruct [:id, :position, labels: [], properties: %{}]

  @type t :: %__MODULE__{
          id: String.t(),
          labels: [String.t()],
          properties: map(),
          position: %{x: number(), y: number()} | nil
        }
end

defmodule Artefactory.Relationship do
  @moduledoc false
  defstruct [:id, :type, :from_id, :to_id, properties: %{}]

  @type t :: %__MODULE__{
          id: String.t(),
          type: String.t(),
          from_id: String.t(),
          to_id: String.t(),
          properties: map()
        }
end

defmodule Artefactory.Graph do
  @moduledoc false
  defstruct nodes: [], relationships: []

  @type t :: %__MODULE__{
          nodes: [Artefactory.Node.t()],
          relationships: [Artefactory.Relationship.t()]
        }
end
