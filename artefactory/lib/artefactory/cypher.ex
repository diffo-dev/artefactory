# SPDX-FileCopyrightText: 2026 diffo-dev
# SPDX-License-Identifier: MIT

defmodule Artefactory.Cypher do
  @moduledoc """
  Derives a Cypher CREATE fragment from an `%Artefactory{}`.

  Lossy: position and style are not represented in Cypher.
  """

  @doc """
  Export an artefact as a Cypher CREATE statement.

  Nodes are emitted first with their Arrows id as a Cypher variable,
  ensuring nodes shared across multiple relationships are created once.
  Relationships follow, referencing those variables.
  """
  def export(%Artefactory{graph: graph}) do
    node_patterns = Enum.map(graph.nodes, &node_pattern/1)

    rel_patterns =
      Enum.map(graph.relationships, fn rel ->
        "(#{rel.from_id})-#{rel_pattern(rel)}->(#{rel.to_id})"
      end)

    "CREATE " <> Enum.join(node_patterns ++ rel_patterns, ",\n       ")
  end

  defp node_pattern(%Artefactory.Node{id: id, labels: labels, properties: props}) do
    label_str = Enum.map_join(labels, "", &":#{&1}")
    prop_str = props_to_cypher(props)

    case prop_str do
      "" -> "(#{id}#{label_str})"
      _ -> "(#{id}#{label_str} #{prop_str})"
    end
  end

  defp rel_pattern(%Artefactory.Relationship{type: type, properties: props}) do
    prop_str = props_to_cypher(props)

    case prop_str do
      "" -> "[:#{type}]"
      _ -> "[:#{type} #{prop_str}]"
    end
  end

  defp props_to_cypher(props) when map_size(props) == 0, do: ""

  defp props_to_cypher(props) do
    inner =
      props
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map_join(", ", fn {k, v} -> "#{k}: #{cypher_value(v)}" end)

    "{#{inner}}"
  end

  defp cypher_value(v) when is_binary(v), do: "'#{v}'"
  defp cypher_value(v) when is_integer(v), do: Integer.to_string(v)
  defp cypher_value(v) when is_float(v), do: Float.to_string(v)
  defp cypher_value(true), do: "true"
  defp cypher_value(false), do: "false"
  defp cypher_value(nil), do: "null"

end
