# SPDX-FileCopyrightText: 2026 diffo-dev
# SPDX-License-Identifier: MIT

defmodule Artefact.Cypher do
  @moduledoc """
  Derives Cypher from an `%Artefact{}`.

  Lossy: position and style are not represented in Cypher.
  """

  @doc """
  Emit a Cypher CREATE statement — always creates new nodes.

  Nodes are emitted first with their Arrows id as a Cypher variable,
  ensuring nodes shared across multiple relationships are created once.
  Relationships follow, referencing those variables.
  """
  def create(%Artefact{base_label: base_label, graph: graph}) do
    node_patterns = Enum.map(graph.nodes, &node_pattern(&1, base_label))

    rel_patterns =
      Enum.map(graph.relationships, fn rel ->
        "(#{rel.from_id})-#{rel_pattern(rel)}->(#{rel.to_id})"
      end)

    "CREATE " <> Enum.join(node_patterns ++ rel_patterns, ",\n       ")
  end

  @doc """
  Emit an inline Cypher MERGE string — upserts without twins, pasteable into Neo4j Browser.

  Each node is merged on its uuid; labels and properties are SET afterwards.
  """
  def merge(%Artefact{base_label: base_label, graph: graph}) do
    node_stmts = Enum.map(graph.nodes, &inline_merge_node_stmt(&1, base_label))

    rel_stmts =
      Enum.map(graph.relationships, fn rel ->
        from = Enum.find(graph.nodes, &(&1.id == rel.from_id))
        to   = Enum.find(graph.nodes, &(&1.id == rel.to_id))
        inline_merge_rel_stmt(rel, from, to)
      end)

    Enum.join(node_stmts ++ rel_stmts, "\n")
  end

  @doc """
  Emit a parameterised Cypher CREATE — returns `{cypher, params}` for driver use (e.g. Bolty).
  """
  def create_params(%Artefact{base_label: base_label, graph: graph}) do
    {node_patterns, node_params} =
      graph.nodes
      |> Enum.map(&params_node_pattern(&1, base_label))
      |> Enum.unzip()

    rel_patterns =
      Enum.map(graph.relationships, fn rel ->
        "(#{rel.from_id})-#{rel_pattern(rel)}->(#{rel.to_id})"
      end)

    cypher = "CREATE " <> Enum.join(node_patterns ++ rel_patterns, ",\n       ")
    params = Enum.reduce(node_params, %{}, &Map.merge(&2, &1))

    {cypher, params}
  end

  @doc """
  Emit parameterised Cypher MERGE — returns `{cypher, params}` for driver use (e.g. Bolty).
  """
  def merge_params(%Artefact{base_label: base_label, graph: graph}) do
    {node_stmts, node_params} =
      graph.nodes
      |> Enum.map(&params_merge_node_stmt(&1, base_label))
      |> Enum.unzip()

    {rel_stmts, rel_params} =
      graph.relationships
      |> Enum.with_index()
      |> Enum.map(fn {rel, idx} ->
        from = Enum.find(graph.nodes, &(&1.id == rel.from_id))
        to   = Enum.find(graph.nodes, &(&1.id == rel.to_id))
        params_merge_rel_stmt(rel, from, to, idx)
      end)
      |> Enum.unzip()

    cypher = Enum.join(node_stmts ++ rel_stmts, "\n")
    params = Enum.reduce(node_params ++ rel_params, %{}, &Map.merge(&2, &1))

    {cypher, params}
  end

  # -- inline (browser) merge helpers --

  defp inline_merge_node_stmt(%Artefact.Node{id: id, uuid: uuid, labels: labels, properties: props}, base_label) do
    effective = effective_labels(labels, base_label)
    label_str = Enum.map_join(effective, "", &":#{&1}")
    set_labels = if label_str != "", do: "\nSET #{id}#{label_str}", else: ""
    set_props  = if map_size(props) > 0, do: "\nSET #{id} += #{props_to_cypher(props)}", else: ""
    "MERGE (#{id} {uuid: '#{uuid}'})#{set_labels}#{set_props}"
  end

  defp inline_merge_rel_stmt(%Artefact.Relationship{type: type, properties: props}, from, to) do
    if map_size(props) > 0 do
      "MERGE (#{from.id})-[:#{type} #{props_to_cypher(props)}]->(#{to.id})"
    else
      "MERGE (#{from.id})-[:#{type}]->(#{to.id})"
    end
  end

  # -- parameterised create helpers --

  defp params_node_pattern(%Artefact.Node{id: id, uuid: uuid, labels: labels, properties: props}, base_label) do
    label_str = labels |> effective_labels(base_label) |> Enum.map_join("", &":#{&1}")
    all_props = Map.put(props, "uuid", uuid)

    {inline, params} =
      Enum.sort_by(all_props, &elem(&1, 0))
      |> Enum.reduce({"", %{}}, fn {k, v}, {acc_str, acc_params} ->
        param_key = "#{id}_#{k}"
        sep = if acc_str == "", do: "", else: ", "
        {acc_str <> sep <> "#{k}: $#{param_key}", Map.put(acc_params, param_key, v)}
      end)

    {"(#{id}#{label_str} {#{inline}})", params}
  end

  # -- parameterised merge helpers --

  defp params_merge_node_stmt(%Artefact.Node{id: id, uuid: uuid, labels: labels, properties: props}, base_label) do
    label_str = labels |> effective_labels(base_label) |> Enum.map_join("", &":#{&1}")
    set_labels = if label_str != "", do: "\nSET #{id}#{label_str}", else: ""
    set_props  = if map_size(props) > 0, do: "\nSET #{id} += $#{id}_props", else: ""

    stmt   = "MERGE (#{id} {uuid: $#{id}_uuid})#{set_labels}#{set_props}"
    params = Map.merge(%{"#{id}_uuid" => uuid}, if(map_size(props) > 0, do: %{"#{id}_props" => props}, else: %{}))
    {stmt, params}
  end

  defp params_merge_rel_stmt(%Artefact.Relationship{type: type, properties: props}, from, to, idx) do
    if map_size(props) > 0 do
      rvar   = "r#{idx}"
      stmt   = "MERGE (#{from.id})-[#{rvar}:#{type}]->(#{to.id})\nSET #{rvar} += $#{rvar}_props"
      params = %{"#{rvar}_props" => props}
      {stmt, params}
    else
      {"MERGE (#{from.id})-[:#{type}]->(#{to.id})", %{}}
    end
  end

  defp node_pattern(%Artefact.Node{id: id, uuid: uuid, labels: labels, properties: props}, base_label) do
    label_str = labels |> effective_labels(base_label) |> Enum.map_join("", &":#{&1}")
    prop_str = props_to_cypher(Map.put(props, "uuid", uuid))
    "(#{id}#{label_str} #{prop_str})"
  end

  defp effective_labels(labels, nil), do: labels
  defp effective_labels(labels, base_label), do: Enum.uniq(labels ++ [base_label])

  defp rel_pattern(%Artefact.Relationship{type: type, properties: props}) do
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
