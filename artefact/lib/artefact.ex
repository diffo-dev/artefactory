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

  Records `:struct` provenance with the calling module.
  """
  defmacro new(attrs \\ []) do
    caller = __CALLER__.module
    caller_name = caller && (caller |> Module.split() |> List.last())
    default_base_label = caller_name && String.replace(caller_name, ~r/[^A-Za-z0-9]/, "")
    quote do
      attrs      = unquote(attrs)
      metadata   = %{provenance: %{source: :struct, module: unquote(caller)}}
      title      = Keyword.get(attrs, :title, unquote(caller_name))
      base_label = Keyword.get(attrs, :base_label, unquote(default_base_label))
      Artefact.build([{:title, title}, {:base_label, base_label}, {:metadata, metadata} | Keyword.drop(attrs, [:title, :base_label, :metadata])])
    end
  end

  @doc """
  Compose two artefacts into one. Graphs are concatenated without merging.
  Nodes remain disjoint; label-based relationships are implicit.

  `base_label` defaults to the portmanteau of both artefacts' base_labels.
  Override with `base_label:` or `title:` in opts.

  Records `:composed` provenance with the calling module and the metadata
  of both source artefacts.
  """
  defmacro compose(a1, a2, opts \\ []) do
    caller = __CALLER__.module
    quote do
      Artefact.do_compose(unquote(a1), unquote(a2), unquote(opts), unquote(caller))
    end
  end

  @doc false
  def do_compose(%__MODULE__{} = a1, %__MODULE__{} = a2, opts, caller) do
    base_label = Keyword.get(opts, :base_label, portmanteau(a1.base_label, a2.base_label))
    title      = Keyword.get(opts, :title, base_label)
    graph      = merge_graphs(a1.graph, a2.graph)
    metadata   = %{provenance: %{source: :composed, module: caller,
                                left:  %{title: a1.title, base_label: a1.base_label, uuid: a1.uuid, provenance: Map.get(a1.metadata, :provenance)},
                                right: %{title: a2.title, base_label: a2.base_label, uuid: a2.uuid, provenance: Map.get(a2.metadata, :provenance)}}}
    build([{:title, title}, {:base_label, base_label}, {:graph, graph}, {:metadata, metadata}])
  end

  @doc """
  Harmonise two artefacts using declared bindings.

  Bound nodes are merged: lower uuid wins for identity and properties,
  labels are unioned. All relationships are preserved and remapped.
  Returns a new artefact with a portmanteau base_label unless overridden.

  Records `:harmonised` provenance with the calling module and the metadata
  of both source artefacts.
  """
  defmacro harmonise(a1, a2, bindings, opts \\ []) do
    caller = __CALLER__.module
    quote do
      Artefact.do_harmonise(unquote(a1), unquote(a2), unquote(bindings), unquote(opts), unquote(caller))
    end
  end

  @doc false
  def do_harmonise(%__MODULE__{} = a1, %__MODULE__{} = a2, bindings, opts, caller) do
    if a1.uuid == a2.uuid do
      raise ArgumentError, "cannot harmonise an artefact with itself (uuid: #{a1.uuid})"
    end

    if a1.base_label != nil and a1.base_label == a2.base_label do
      raise ArgumentError, "cannot harmonise artefacts with the same base_label (#{a1.base_label})"
    end

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

    metadata = %{provenance: %{source: :harmonised, module: caller,
                               left:  %{title: a1.title, base_label: a1.base_label, uuid: a1.uuid, provenance: Map.get(a1.metadata, :provenance)},
                               right: %{title: a2.title, base_label: a2.base_label, uuid: a2.uuid, provenance: Map.get(a2.metadata, :provenance)}}}
    build([{:title, title}, {:base_label, base_label}, {:graph, graph}, {:metadata, metadata}])
  end

  @doc false
  def build(attrs) do
    {node_specs, attrs} = Keyword.pop(attrs, :nodes, [])
    {rel_specs,  attrs} = Keyword.pop(attrs, :relationships, [])

    attrs =
      if node_specs != [] or rel_specs != [] do
        Keyword.put(attrs, :graph, build_graph(node_specs, rel_specs))
      else
        attrs
      end

    struct!(__MODULE__, [{:id, Artefact.UUID.generate_v7()}, {:uuid, Artefact.UUID.generate_v7()} | attrs])
  end

  defp build_graph(node_specs, rel_specs) do
    {nodes, key_map} =
      node_specs
      |> Enum.with_index()
      |> Enum.map_reduce(%{}, fn {{key, opts}, i}, acc ->
        id   = "n#{i}"
        node = %Artefact.Node{
          id:         id,
          uuid:       Keyword.get(opts, :uuid, Artefact.UUID.generate_v7()),
          labels:     Keyword.get(opts, :labels, []),
          properties: Keyword.get(opts, :properties, %{}),
          position:   Keyword.get(opts, :position)
        }
        {node, Map.put(acc, key, id)}
      end)

    relationships =
      rel_specs
      |> Enum.with_index()
      |> Enum.map(fn {spec, i} ->
        %Artefact.Relationship{
          id:         "r#{i}",
          from_id:    Map.fetch!(key_map, Keyword.fetch!(spec, :from)),
          to_id:      Map.fetch!(key_map, Keyword.fetch!(spec, :to)),
          type:       Keyword.fetch!(spec, :type),
          properties: Keyword.get(spec, :properties, %{})
        }
      end)

    %Artefact.Graph{nodes: nodes, relationships: relationships}
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
