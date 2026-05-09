# SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Artefact.Op do
  @moduledoc """
  Implementation home for Artefact operations.

  Public ops are surfaced through `Artefact` itself via macros (which
  capture `__CALLER__.module` for provenance). This module is the
  function-form home — it takes `caller` as an explicit argument.

  Every function returns `{:ok, %Artefact{}}` or `{:error, _}`. Errors
  are `Artefact.Error.Invalid` (validation rule violations) or
  `Artefact.Error.Operation` (op-specific outcomes — see the latter's
  moduledoc for the per-op tag list).
  """

  alias Artefact.Error.Invalid
  alias Artefact.Error.Operation
  alias Artefact.Validator

  # =====================================================================
  # new
  # =====================================================================

  @doc false
  def new(attrs, caller, caller_name, default_base_label) do
    metadata = %{provenance: %{source: :struct, module: caller}}
    title = Keyword.get(attrs, :title, caller_name)
    base_label = Keyword.get(attrs, :base_label, default_base_label)

    result =
      build([
        {:title, title},
        {:base_label, base_label},
        {:metadata, metadata} | Keyword.drop(attrs, [:title, :base_label, :metadata])
      ])

    finish(result)
  end

  # =====================================================================
  # compose
  # =====================================================================

  @doc false
  def compose(%Artefact{} = a1, %Artefact{} = a2, opts, caller) do
    with :ok <- Validator.validate(a1),
         :ok <- Validator.validate(a2) do
      base_label = Keyword.get(opts, :base_label, portmanteau(a1.base_label, a2.base_label))
      title = Keyword.get(opts, :title, base_label)
      graph = merge_graphs(a1.graph, a2.graph)

      metadata = %{
        provenance: %{
          source: :composed,
          module: caller,
          left: source_summary(a1),
          right: source_summary(a2)
        }
      }

      result =
        build([
          {:title, title},
          {:base_label, base_label},
          {:graph, graph},
          {:metadata, metadata}
        ])

      finish(result)
    end
  end

  # =====================================================================
  # combine
  # =====================================================================

  @doc false
  def combine(%Artefact{} = heart, %Artefact{} = other, opts, caller) do
    with :ok <- Validator.validate(heart),
         :ok <- Validator.validate(other),
         {:ok, bindings} <- find_bindings_for_combine(heart, other),
         {:ok, harmonised} <- harmonise(heart, other, bindings, opts, caller) do
      result =
        case Keyword.fetch(opts, :description) do
          {:ok, description} -> %{harmonised | description: description}
          :error -> harmonised
        end

      finish(result)
    end
  end

  defp find_bindings_for_combine(heart, other) do
    case Artefact.Binding.find(heart, other) do
      {:ok, bindings} ->
        {:ok, bindings}

      {:error, :no_match} ->
        {:error,
         %Operation{
           op: :combine,
           tag: :no_shared_bindings,
           details: %{}
         }}
    end
  end

  # =====================================================================
  # harmonise
  # =====================================================================

  @doc false
  def harmonise(%Artefact{} = a1, %Artefact{} = a2, bindings, opts, caller) do
    with :ok <- Validator.validate(a1),
         :ok <- Validator.validate(a2),
         :ok <- check_not_self(a1, a2),
         :ok <- check_different_base_labels(a1, a2) do
      base_label = Keyword.get(opts, :base_label, portmanteau(a1.base_label, a2.base_label))
      title = Keyword.get(opts, :title, base_label)

      nodes_a = Map.new(a1.graph.nodes, &{&1.uuid, &1})
      nodes_b = Map.new(a2.graph.nodes, &{&1.uuid, &1})

      {primary_updates, b_id_remap} =
        Enum.reduce(bindings, {%{}, %{}}, fn %Artefact.Binding{uuid_a: ua, uuid_b: ub},
                                             {updates, remap} ->
          node_a = nodes_a[ua]
          node_b = nodes_b[ub]
          surviving = Artefact.UUID.harmonise(ua, ub)

          {primary, secondary} =
            if surviving == ua, do: {node_a, node_b}, else: {node_b, node_a}

          merged = %{
            primary
            | labels: Enum.uniq(node_a.labels ++ node_b.labels),
              properties: Map.merge(node_b.properties, node_a.properties)
          }

          {Map.put(updates, primary.uuid, merged), Map.put(remap, secondary.id, primary.id)}
        end)

      bound_uuids_b = MapSet.new(bindings, & &1.uuid_b)
      offset = length(a1.graph.nodes)

      {b_nodes_reindexed, b_id_remap} =
        a2.graph.nodes
        |> Enum.reject(&MapSet.member?(bound_uuids_b, &1.uuid))
        |> Enum.with_index(offset)
        |> Enum.reduce({[], b_id_remap}, fn {node, i}, {acc, remap} ->
          new_id = "n#{i}"
          {acc ++ [%{node | id: new_id}], Map.put(remap, node.id, new_id)}
        end)

      nodes_from_a =
        Enum.map(a1.graph.nodes, fn n -> Map.get(primary_updates, n.uuid, n) end)

      rels_from_b =
        Enum.map(a2.graph.relationships, fn rel ->
          %{
            rel
            | from_id: Map.get(b_id_remap, rel.from_id, rel.from_id),
              to_id: Map.get(b_id_remap, rel.to_id, rel.to_id)
          }
        end)

      relationships = deduplicate_rels(a1.graph.relationships, rels_from_b)

      graph = %Artefact.Graph{
        nodes: nodes_from_a ++ b_nodes_reindexed,
        relationships: relationships
      }

      metadata = %{
        provenance: %{
          source: :harmonised,
          module: caller,
          left: source_summary(a1),
          right: source_summary(a2)
        }
      }

      result =
        build([
          {:title, title},
          {:base_label, base_label},
          {:graph, graph},
          {:metadata, metadata}
        ])

      finish(result)
    end
  end

  defp check_not_self(a1, a2) do
    if a1.uuid == a2.uuid do
      {:error, %Operation{op: :harmonise, tag: :self_harmonise, details: %{uuid: a1.uuid}}}
    else
      :ok
    end
  end

  defp check_different_base_labels(a1, a2) do
    if a1.base_label != nil and a1.base_label == a2.base_label do
      {:error,
       %Operation{
         op: :harmonise,
         tag: :same_base_label,
         details: %{base_label: a1.base_label}
       }}
    else
      :ok
    end
  end

  # =====================================================================
  # graft
  # =====================================================================

  @doc false
  def graft(%Artefact{} = left, args, opts, caller) do
    node_specs = Keyword.get(args, :nodes, [])
    rel_specs = Keyword.get(args, :relationships, [])

    with :ok <- Validator.validate(left),
         :ok <- check_graft_node_specs(node_specs),
         :ok <- check_graft_unique_keys(node_specs) do
      left_by_uuid = Map.new(left.graph.nodes, &{&1.uuid, &1})

      {bind_specs, new_specs} =
        Enum.split_with(node_specs, fn {_key, node_opts} ->
          Map.has_key?(left_by_uuid, Keyword.fetch!(node_opts, :uuid))
        end)

      bind_key_map =
        Map.new(bind_specs, fn {key, node_opts} ->
          existing = Map.fetch!(left_by_uuid, Keyword.fetch!(node_opts, :uuid))
          {key, existing.id}
        end)

      offset = length(left.graph.nodes)

      {new_nodes, new_key_map} =
        new_specs
        |> Enum.with_index(offset)
        |> Enum.map_reduce(%{}, fn {{key, node_opts}, i}, acc ->
          id = "n#{i}"

          node = %Artefact.Node{
            id: id,
            uuid: Keyword.fetch!(node_opts, :uuid),
            labels: Keyword.get(node_opts, :labels, []),
            properties: Keyword.get(node_opts, :properties, %{}),
            position: Keyword.get(node_opts, :position)
          }

          {node, Map.put(acc, key, id)}
        end)

      key_map = Map.merge(bind_key_map, new_key_map)

      with :ok <- check_graft_rel_keys(rel_specs, key_map),
           :ok <- check_graft_no_islands(rel_specs, bind_key_map, new_key_map) do
        bind_updates =
          Map.new(bind_specs, fn {_key, node_opts} ->
            uuid = Keyword.fetch!(node_opts, :uuid)
            existing = Map.fetch!(left_by_uuid, uuid)

            merged = %{
              existing
              | labels: Enum.uniq(existing.labels ++ Keyword.get(node_opts, :labels, [])),
                properties:
                  Map.merge(Keyword.get(node_opts, :properties, %{}), existing.properties)
            }

            {uuid, merged}
          end)

        updated_left_nodes =
          Enum.map(left.graph.nodes, fn n -> Map.get(bind_updates, n.uuid, n) end)

        rel_offset = length(left.graph.relationships)

        new_rels =
          rel_specs
          |> Enum.with_index(rel_offset)
          |> Enum.map(fn {spec, i} ->
            %Artefact.Relationship{
              id: "r#{i}",
              from_id: Map.fetch!(key_map, Keyword.fetch!(spec, :from)),
              to_id: Map.fetch!(key_map, Keyword.fetch!(spec, :to)),
              type: Keyword.fetch!(spec, :type),
              properties: Keyword.get(spec, :properties, %{})
            }
          end)

        relationships = deduplicate_rels(left.graph.relationships, new_rels)

        graph = %Artefact.Graph{
          nodes: updated_left_nodes ++ new_nodes,
          relationships: relationships
        }

        title = Keyword.get(opts, :title, left.title)
        description = Keyword.get(opts, :description, left.description)

        metadata = %{
          provenance: %{
            source: :grafted,
            module: caller,
            left: source_summary(left),
            right: %{
              title: Keyword.get(opts, :title),
              description: Keyword.get(opts, :description)
            }
          }
        }

        result =
          build([
            {:title, title},
            {:description, description},
            {:base_label, left.base_label},
            {:graph, graph},
            {:metadata, metadata}
          ])

        finish(result)
      end
    end
  end

  defp check_graft_node_specs(node_specs) do
    Enum.reduce_while(node_specs, :ok, fn {key, node_opts}, _acc ->
      case check_graft_node_spec(key, node_opts) do
        :ok -> {:cont, :ok}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp check_graft_node_spec(key, node_opts) do
    cond do
      Keyword.fetch(node_opts, :uuid) == :error ->
        {:error, %Operation{op: :graft, tag: :missing_uuid, details: %{key: key}}}

      not Artefact.UUID.valid?(Keyword.fetch!(node_opts, :uuid)) ->
        {:error,
         %Operation{
           op: :graft,
           tag: :invalid_uuid,
           details: %{key: key, uuid: Keyword.fetch!(node_opts, :uuid)}
         }}

      Keyword.has_key?(node_opts, :labels) and
          not valid_labels?(Keyword.fetch!(node_opts, :labels)) ->
        {:error,
         %Operation{
           op: :graft,
           tag: :invalid_labels,
           details: %{key: key, labels: Keyword.fetch!(node_opts, :labels)}
         }}

      Keyword.has_key?(node_opts, :properties) and
          not is_map(Keyword.fetch!(node_opts, :properties)) ->
        {:error,
         %Operation{
           op: :graft,
           tag: :invalid_properties,
           details: %{key: key, properties: Keyword.fetch!(node_opts, :properties)}
         }}

      true ->
        :ok
    end
  end

  defp valid_labels?(labels) do
    is_list(labels) and Enum.all?(labels, &is_binary/1)
  end

  defp check_graft_unique_keys(node_specs) do
    keys = Enum.map(node_specs, fn {k, _} -> k end)
    dupes = (keys -- Enum.uniq(keys)) |> Enum.uniq()

    case dupes do
      [] ->
        :ok

      _ ->
        {:error, %Operation{op: :graft, tag: :duplicate_keys, details: %{keys: dupes}}}
    end
  end

  defp check_graft_rel_keys(rel_specs, key_map) do
    Enum.reduce_while(rel_specs, :ok, fn spec, _acc ->
      from = Keyword.fetch!(spec, :from)
      to = Keyword.fetch!(spec, :to)

      cond do
        not Map.has_key?(key_map, from) ->
          {:halt, {:error, %Operation{op: :graft, tag: :unknown_rel_key, details: %{key: from}}}}

        not Map.has_key?(key_map, to) ->
          {:halt, {:error, %Operation{op: :graft, tag: :unknown_rel_key, details: %{key: to}}}}

        true ->
          {:cont, :ok}
      end
    end)
  end

  defp check_graft_no_islands(rel_specs, bind_key_map, new_key_map) do
    bind_keys = Map.keys(bind_key_map)
    new_keys = Map.keys(new_key_map)

    if new_keys == [] do
      :ok
    else
      adjacency =
        Enum.reduce(rel_specs, %{}, fn spec, acc ->
          f = Keyword.fetch!(spec, :from)
          t = Keyword.fetch!(spec, :to)

          acc
          |> Map.update(f, MapSet.new([t]), &MapSet.put(&1, t))
          |> Map.update(t, MapSet.new([f]), &MapSet.put(&1, f))
        end)

      anchored = reach(adjacency, MapSet.new(bind_keys))
      islands = MapSet.difference(MapSet.new(new_keys), anchored)

      if MapSet.size(islands) == 0 do
        :ok
      else
        {:error,
         %Operation{
           op: :graft,
           tag: :islands,
           details: %{keys: Enum.sort(MapSet.to_list(islands))}
         }}
      end
    end
  end

  defp reach(adjacency, seeds) do
    Enum.reduce(seeds, seeds, fn seed, visited ->
      reach_from(adjacency, seed, visited)
    end)
  end

  defp reach_from(adjacency, node, visited) do
    visited = MapSet.put(visited, node)
    neighbours = Map.get(adjacency, node, MapSet.new())

    Enum.reduce(neighbours, visited, fn n, acc ->
      if MapSet.member?(acc, n), do: acc, else: reach_from(adjacency, n, acc)
    end)
  end

  # =====================================================================
  # Shared helpers — build, validate-and-wrap, source summary, graph helpers
  # =====================================================================

  @doc false
  def build(attrs) do
    {node_specs, attrs} = Keyword.pop(attrs, :nodes, [])
    {rel_specs, attrs} = Keyword.pop(attrs, :relationships, [])

    attrs =
      if node_specs != [] or rel_specs != [] do
        Keyword.put(attrs, :graph, build_graph(node_specs, rel_specs))
      else
        attrs
      end

    struct!(Artefact, [
      {:id, Artefact.UUID.generate_v7()},
      {:uuid, Artefact.UUID.generate_v7()} | attrs
    ])
  end

  defp build_graph(node_specs, rel_specs) do
    {nodes, key_map} =
      node_specs
      |> Enum.with_index()
      |> Enum.map_reduce(%{}, fn {{key, opts}, i}, acc ->
        id = "n#{i}"

        node = %Artefact.Node{
          id: id,
          uuid: Keyword.get(opts, :uuid, Artefact.UUID.generate_v7()),
          labels: Keyword.get(opts, :labels, []),
          properties: Keyword.get(opts, :properties, %{}),
          position: Keyword.get(opts, :position)
        }

        {node, Map.put(acc, key, id)}
      end)

    relationships =
      rel_specs
      |> Enum.with_index()
      |> Enum.map(fn {spec, i} ->
        %Artefact.Relationship{
          id: "r#{i}",
          from_id: Map.fetch!(key_map, Keyword.fetch!(spec, :from)),
          to_id: Map.fetch!(key_map, Keyword.fetch!(spec, :to)),
          type: Keyword.fetch!(spec, :type),
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
            Map.put(acc, key, %{
              existing
              | properties: Map.merge(rel.properties, existing.properties)
            })

          :error ->
            Map.put(acc, key, rel)
        end
      end)

    Map.values(merged_index)
  end

  defp merge_graphs(g1, g2) do
    offset = length(g1.nodes)

    id_map =
      g2.nodes
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
  defp portmanteau(a, nil), do: a
  defp portmanteau(nil, b), do: b
  defp portmanteau(a, b), do: a <> b

  defp source_summary(%Artefact{} = a) do
    %{
      title: a.title,
      base_label: a.base_label,
      uuid: a.uuid,
      provenance: Map.get(a.metadata, :provenance)
    }
  end

  # Validate the produced artefact; wrap in {:ok, _} or pass the
  # {:error, %Invalid{}} through unchanged.
  defp finish(%Artefact{} = result) do
    case Validator.validate(result) do
      :ok -> {:ok, result}
      {:error, %Invalid{}} = err -> err
    end
  end
end
