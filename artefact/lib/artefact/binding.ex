# SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Artefact.Binding do
  @moduledoc """
  A declared equivalence between nodes across two artefacts.

  Bindings are the basis for union — without at least one binding,
  two artefacts have no commons and cannot be combined.
  """

  defstruct [:uuid_a, :uuid_b]

  @type t :: %__MODULE__{
          uuid_a: String.t(),
          uuid_b: String.t()
        }

  @doc """
  Find bindings between two artefacts.

  By default, nodes with the same uuid are automatically bound.
  Use `inject:` to declare equivalences between nodes with different uuids.

  Returns `{:ok, bindings}` or `{:error, :no_match}` if no bindings found.

  ## Options
    - `inject:` — list of `{uuid_a, uuid_b}` pairs declaring equivalences
  """
  def find(%Artefact{} = a1, %Artefact{} = a2, opts \\ []) do
    uuids_a = MapSet.new(a1.graph.nodes, & &1.uuid)
    uuids_b = MapSet.new(a2.graph.nodes, & &1.uuid)

    auto =
      uuids_a
      |> MapSet.intersection(uuids_b)
      |> Enum.map(&%__MODULE__{uuid_a: &1, uuid_b: &1})

    explicit =
      opts
      |> Keyword.get(:inject, [])
      |> Enum.map(fn {uuid_a, uuid_b} -> %__MODULE__{uuid_a: uuid_a, uuid_b: uuid_b} end)

    case auto ++ explicit do
      [] -> {:error, :no_match}
      bindings -> {:ok, bindings}
    end
  end
end
