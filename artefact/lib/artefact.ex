# SPDX-FileCopyrightText: 2026 diffo-dev
# SPDX-License-Identifier: MIT

defmodule Artefact do
  @moduledoc """
  A knowledge graph fragment — a small, self-contained piece of knowledge
  expressed as a property graph.

  The canonical form is the `%Artefact{}` struct. Arrows JSON and Cypher are
  derived representations: JSON for interchange and visual editing, Cypher for
  persistence.
  """

  defstruct [:id, :uuid, :title, :base_label, :style, metadata: %{}, graph: %Artefact.Graph{}]

  @type t :: %__MODULE__{
          id: String.t(),
          uuid: String.t(),
          title: String.t() | nil,
          base_label: String.t() | nil,
          style: atom() | nil,
          graph: Artefact.Graph.t(),
          metadata: map()
        }

  @doc """
  Create a new Artefact. Defaults `base_label` and `title` to the short name
  of the calling module. Override with `title:` or `base_label:` in attrs.
  """
  defmacro new(attrs \\ []) do
    caller_name = __CALLER__.module |> Module.split() |> List.last()
    quote do
      attrs  = unquote(attrs)
      name   = unquote(caller_name)
      title  = Keyword.get(attrs, :title, name)
      base_label = Keyword.get(attrs, :base_label, name |> String.replace(~r/[^A-Za-z0-9]/, ""))
      Artefact.build([{:title, title}, {:base_label, base_label} | Keyword.drop(attrs, [:title, :base_label])])
    end
  end

  @doc """
  Compose two artefacts into one. Graphs are concatenated without merging.
  Nodes remain disjoint; label-based relationships are implicit.

  `base_label` defaults to the portmanteau of both artefacts' base_labels.
  Override with `base_label:` or `title:` in opts.
  """
  def compose(%__MODULE__{} = a1, %__MODULE__{} = a2, opts \\ []) do
    base_label = Keyword.get(opts, :base_label, portmanteau(a1.base_label, a2.base_label))
    title      = Keyword.get(opts, :title, base_label)
    graph = merge_graphs(a1.graph, a2.graph)
    build([{:title, title}, {:base_label, base_label}, {:graph, graph}])
  end

  @doc """
  Harmonise two artefacts using declared bindings.

  Bound nodes are merged: lower uuid wins for identity and properties,
  labels are unioned. All relationships are preserved and remapped.
  Returns a new artefact with a portmanteau base_label unless overridden.
  """
  def harmonise(%__MODULE__{} = a1, %__MODULE__{} = a2, bindings, opts \\ []) do
    base_label = Keyword.get(opts, :base_label, portmanteau(a1.base_label, a2.base_label))
    title      = Keyword.get(opts, :title, base_label)

    nodes_a = Map.new(a1.graph.nodes, &{&1.uuid, &1})
    nodes_b = Map.new(a2.graph.nodes, &{&1.uuid, &1})

    # Resolve each binding: primary (lower uuid) absorbs secondary
    {primary_updates, b_id_remap} =
      Enum.reduce(bindings, {%{}, %{}}, fn %Artefact.Binding{uuid_a: ua, uuid_b: ub}, {updates, remap} ->
        node_a = nodes_a[ua]
        node_b = nodes_b[ub]
        surviving = Artefact.UUID.harmonise(ua, ub)

        {primary, secondary} =
          if surviving == ua, do: {node_a, node_b}, else: {node_b, node_a}

        merged = %{primary |
          labels:     Enum.uniq(node_a.labels ++ node_b.labels),
          properties: Map.merge(node_b.properties, node_a.properties)
        }

        {Map.put(updates, primary.uuid, merged), Map.put(remap, secondary.id, primary.id)}
      end)

    bound_uuids_b = MapSet.new(bindings, & &1.uuid_b)
    offset        = length(a1.graph.nodes)

    # Reindex a2 non-bound nodes to avoid id collision
    {b_nodes_reindexed, b_id_remap} =
      a2.graph.nodes
      |> Enum.reject(&MapSet.member?(bound_uuids_b, &1.uuid))
      |> Enum.with_index(offset)
      |> Enum.reduce({[], b_id_remap}, fn {node, i}, {acc, remap} ->
        new_id = "n#{i}"
        {acc ++ [%{node | id: new_id}], Map.put(remap, node.id, new_id)}
      end)

    nodes_from_a = Enum.map(a1.graph.nodes, fn n ->
      Map.get(primary_updates, n.uuid, n)
    end)

    rels_from_b = Enum.map(a2.graph.relationships, fn rel ->
      %{rel | from_id: Map.get(b_id_remap, rel.from_id, rel.from_id),
              to_id:   Map.get(b_id_remap, rel.to_id,   rel.to_id)}
    end)

    relationships = deduplicate_rels(a1.graph.relationships, rels_from_b)

    graph = %Artefact.Graph{
      nodes:         nodes_from_a ++ b_nodes_reindexed,
      relationships: relationships
    }

    build([{:title, title}, {:base_label, base_label}, {:graph, graph}])
  end

  @doc false
  def build(attrs) do
    struct!(__MODULE__, [{:id, Artefact.UUID.generate_v7()}, {:uuid, Artefact.UUID.generate_v7()} | attrs])
  end

  defp deduplicate_rels(rels_a, rels_b) do
    index = Map.new(rels_a, fn rel -> {{rel.from_id, rel.type, rel.to_id}, rel} end)

    merged_index =
      Enum.reduce(rels_b, index, fn rel, acc ->
        key = {rel.from_id, rel.type, rel.to_id}
        case Map.fetch(acc, key) do
          {:ok, existing} ->
            Map.put(acc, key, %{existing | properties: Map.merge(rel.properties, existing.properties)})
          :error ->
            Map.put(acc, key, rel)
        end
      end)

    Map.values(merged_index)
  end

  defp merge_graphs(g1, g2) do
    offset = length(g1.nodes)

    id_map = g2.nodes
      |> Enum.with_index(offset)
      |> Map.new(fn {node, i} -> {node.id, "n#{i}"} end)

    nodes =
      g1.nodes ++
      Enum.map(g2.nodes, fn node -> %{node | id: id_map[node.id]} end)

    rels =
      g1.relationships ++
      Enum.map(g2.relationships, fn rel ->
        %{rel | from_id: id_map[rel.from_id], to_id: id_map[rel.to_id]}
      end)

    %Artefact.Graph{nodes: nodes, relationships: rels}
  end

  defp portmanteau(nil, nil), do: nil
  defp portmanteau(a, nil),   do: a
  defp portmanteau(nil, b),   do: b
  defp portmanteau(a, b),     do: a <> b
end
