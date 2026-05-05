# SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Artefact do
  @moduledoc """
  A knowledge graph fragment — a small, self-contained piece of knowledge
  expressed as a property graph.

  The canonical form is the `%Artefact{}` struct. Arrows JSON and Cypher are
  derived representations: JSON for interchange and visual editing, Cypher
  for persistence.

  ## Operations

    * `new/1` — build an artefact, inline (`:nodes` + `:relationships`) or
      from a pre-built `%Artefact.Graph{}`.
    * `compose/3` — concatenate two artefacts; nodes remain disjoint.
    * `combine/3` — pipeline-friendly union; bindings auto-found via shared
      uuid; delegates to `harmonise/4`.
    * `harmonise/4` — union via declared bindings; lower uuid wins identity,
      labels are unioned, left wins on property conflict.
    * `graft/3` — pipeline-friendly extension; integrates inline `args`
      (same shape as `new`'s inline form, but every node MUST carry `:uuid`)
      into an existing artefact.

  Every operation records its lineage in the result's `metadata.provenance`.

  ## Exporting

    * `Artefact.Arrows` — round-trip with [arrows.app](https://arrows.app)
      via `from_json/2`, `from_json!/2`, `to_json/1`.
    * `Artefact.Cypher` — derive Cypher (CREATE or MERGE) for Neo4j
      persistence, with parameterised variants for driver use.
  """

  defstruct [
    :id,
    :uuid,
    :title,
    :description,
    :base_label,
    :style,
    metadata: %{},
    graph: %Artefact.Graph{}
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          uuid: String.t(),
          title: String.t() | nil,
          description: String.t() | nil,
          base_label: String.t() | nil,
          style: atom() | nil,
          graph: Artefact.Graph.t(),
          metadata: map()
        }

  @doc """
  Create a new Artefact. Defaults `base_label` and `title` to the short name
  of the calling module. Override with `title:` or `base_label:` in attrs.

  Optional `description:` is a longer human-readable note about the artefact —
  surfaced as Mermaid `accDescr` and in the `ArtefactKino` inspector. Defaults
  to `nil`; pass it explicitly when you have something to say.

  Records `:struct` provenance with the calling module.
  """
  defmacro new(attrs \\ []) do
    caller = __CALLER__.module
    caller_name = caller && caller |> Module.split() |> List.last()
    default_base_label = caller_name && String.replace(caller_name, ~r/[^A-Za-z0-9]/, "")

    quote do
      attrs = unquote(attrs)
      metadata = %{provenance: %{source: :struct, module: unquote(caller)}}
      title = Keyword.get(attrs, :title, unquote(caller_name))
      base_label = Keyword.get(attrs, :base_label, unquote(default_base_label))

      Artefact.build([
        {:title, title},
        {:base_label, base_label},
        {:metadata, metadata} | Keyword.drop(attrs, [:title, :base_label, :metadata])
      ])
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
    title = Keyword.get(opts, :title, base_label)
    graph = merge_graphs(a1.graph, a2.graph)

    metadata = %{
      provenance: %{
        source: :composed,
        module: caller,
        left: %{
          title: a1.title,
          base_label: a1.base_label,
          uuid: a1.uuid,
          provenance: Map.get(a1.metadata, :provenance)
        },
        right: %{
          title: a2.title,
          base_label: a2.base_label,
          uuid: a2.uuid,
          provenance: Map.get(a2.metadata, :provenance)
        }
      }
    }

    build([{:title, title}, {:base_label, base_label}, {:graph, graph}, {:metadata, metadata}])
  end

  @doc """
  Combine `other` into `heart` using bindings auto-found between them.

  Designed for pipelines — `heart` flows through the pipe as the first argument,
  so a chain of combines accumulates a single heart from many others:

      me_knowing
      |> Artefact.combine(me_valuing)
      |> Artefact.combine(me_being)
      |> Artefact.combine(me_doing, title: "MeMind", description: "Mind of Me.")

  Bindings are found via `Artefact.Binding.find/2` — every node sharing a uuid
  between `heart` and `other` becomes a binding. Raises `MatchError` if no
  bindings are found.

  Internally delegates to `harmonise/4`, so `:title` and `:base_label` overrides
  in `opts` are honoured. `:description` is also accepted and applied to the
  result.

  Records `:harmonised` provenance with the calling module.
  """
  defmacro combine(heart, other, opts \\ []) do
    caller = __CALLER__.module

    quote do
      Artefact.do_combine(unquote(heart), unquote(other), unquote(opts), unquote(caller))
    end
  end

  @doc false
  def do_combine(%__MODULE__{} = heart, %__MODULE__{} = other, opts, caller) do
    {:ok, bindings} = Artefact.Binding.find(heart, other)
    result = do_harmonise(heart, other, bindings, opts, caller)

    case Keyword.fetch(opts, :description) do
      {:ok, description} -> %{result | description: description}
      :error -> result
    end
  end

  @doc """
  Graft `args` onto `left`, integrating new nodes and relationships
  declared inline (same shape as `Artefact.new` accepts) without creating
  a second artefact.

  Designed for pipelines after a series of `combine`s — `args` flows in as
  the second argument, with the result's `:title` and `:description` named
  in `opts`:

      our_shells_artefact
      |> Artefact.combine(our_manifesto_artefact)
      |> Artefact.graft(args, title: "Our Shells and Manifesto",
           description: "Our Shells and Manifesto shape our Association Knowing.")

  ## args

  A keyword list with `:nodes` and `:relationships`, identical in shape to
  what `Artefact.new` accepts inline — except that **every node entry must
  carry an explicit `:uuid`**. There is no auto-find: the uuid is the
  binding.

  Each args node either:

    * **Binds** to an existing left node (uuid present in `left.graph.nodes`).
      Labels are unioned, properties merged with **left winning** on key
      conflicts. Position is untouched.

    * **Adds** a new node (uuid not in left). Receives a fresh sequential id
      continuing left's offset.

  Args relationships use args-local atom keys, just like `Artefact.new`.
  Every key referenced by a relationship must be declared in `args.nodes`.

  ## opts

  Honours `:title` and `:description` only — both name the result. If
  omitted, `left`'s title and description carry forward. `:base_label` is
  **not** honoured; the result keeps `left.base_label`.

  ## Raises

    * `ArgumentError` — any args node missing `:uuid`
    * `ArgumentError` — duplicate keys in `args.nodes`
    * `ArgumentError` — a relationship references a key not in `args.nodes`

  ## Provenance

  Records `:grafted` with the calling module, a summary of `left`, and
  `right: %{title: <opts.title>, description: <opts.description>}` — the
  result's name as provided.
  """
  defmacro graft(left, args, opts \\ []) do
    caller = __CALLER__.module

    quote do
      Artefact.do_graft(unquote(left), unquote(args), unquote(opts), unquote(caller))
    end
  end

  @doc false
  def do_graft(%__MODULE__{} = left, args, opts, caller) do
    node_specs = Keyword.get(args, :nodes, [])
    rel_specs = Keyword.get(args, :relationships, [])

    validate_graft_node_uuids!(node_specs)
    validate_graft_unique_keys!(node_specs)

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

    validate_graft_rel_keys!(rel_specs, key_map)

    bind_updates =
      Map.new(bind_specs, fn {_key, node_opts} ->
        uuid = Keyword.fetch!(node_opts, :uuid)
        existing = Map.fetch!(left_by_uuid, uuid)

        merged = %{
          existing
          | labels: Enum.uniq(existing.labels ++ Keyword.get(node_opts, :labels, [])),
            properties: Map.merge(Keyword.get(node_opts, :properties, %{}), existing.properties)
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
        left: %{
          title: left.title,
          base_label: left.base_label,
          uuid: left.uuid,
          provenance: Map.get(left.metadata, :provenance)
        },
        right: %{title: Keyword.get(opts, :title), description: Keyword.get(opts, :description)}
      }
    }

    build([
      {:title, title},
      {:description, description},
      {:base_label, left.base_label},
      {:graph, graph},
      {:metadata, metadata}
    ])
  end

  defp validate_graft_node_uuids!(node_specs) do
    Enum.each(node_specs, fn {key, node_opts} ->
      case Keyword.fetch(node_opts, :uuid) do
        {:ok, _} -> :ok
        :error -> raise ArgumentError, "graft: node #{inspect(key)} is missing required :uuid"
      end
    end)
  end

  defp validate_graft_unique_keys!(node_specs) do
    keys = Enum.map(node_specs, fn {k, _} -> k end)
    dupes = keys -- Enum.uniq(keys)

    if dupes != [] do
      raise ArgumentError, "graft: duplicate node keys: #{inspect(Enum.uniq(dupes))}"
    end
  end

  defp validate_graft_rel_keys!(rel_specs, key_map) do
    Enum.each(rel_specs, fn spec ->
      from = Keyword.fetch!(spec, :from)
      to = Keyword.fetch!(spec, :to)

      unless Map.has_key?(key_map, from) do
        raise ArgumentError,
              "graft: relationship references unknown node key #{inspect(from)} (not in args.nodes)"
      end

      unless Map.has_key?(key_map, to) do
        raise ArgumentError,
              "graft: relationship references unknown node key #{inspect(to)} (not in args.nodes)"
      end
    end)
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
      Artefact.do_harmonise(
        unquote(a1),
        unquote(a2),
        unquote(bindings),
        unquote(opts),
        unquote(caller)
      )
    end
  end

  @doc false
  def do_harmonise(%__MODULE__{} = a1, %__MODULE__{} = a2, bindings, opts, caller) do
    if a1.uuid == a2.uuid do
      raise ArgumentError, "cannot harmonise an artefact with itself (uuid: #{a1.uuid})"
    end

    if a1.base_label != nil and a1.base_label == a2.base_label do
      raise ArgumentError,
            "cannot harmonise artefacts with the same base_label (#{a1.base_label})"
    end

    base_label = Keyword.get(opts, :base_label, portmanteau(a1.base_label, a2.base_label))
    title = Keyword.get(opts, :title, base_label)

    nodes_a = Map.new(a1.graph.nodes, &{&1.uuid, &1})
    nodes_b = Map.new(a2.graph.nodes, &{&1.uuid, &1})

    # Resolve each binding: primary (lower uuid) absorbs secondary
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

    # Reindex a2 non-bound nodes to avoid id collision
    {b_nodes_reindexed, b_id_remap} =
      a2.graph.nodes
      |> Enum.reject(&MapSet.member?(bound_uuids_b, &1.uuid))
      |> Enum.with_index(offset)
      |> Enum.reduce({[], b_id_remap}, fn {node, i}, {acc, remap} ->
        new_id = "n#{i}"
        {acc ++ [%{node | id: new_id}], Map.put(remap, node.id, new_id)}
      end)

    nodes_from_a =
      Enum.map(a1.graph.nodes, fn n ->
        Map.get(primary_updates, n.uuid, n)
      end)

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
        left: %{
          title: a1.title,
          base_label: a1.base_label,
          uuid: a1.uuid,
          provenance: Map.get(a1.metadata, :provenance)
        },
        right: %{
          title: a2.title,
          base_label: a2.base_label,
          uuid: a2.uuid,
          provenance: Map.get(a2.metadata, :provenance)
        }
      }
    }

    build([{:title, title}, {:base_label, base_label}, {:graph, graph}, {:metadata, metadata}])
  end

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

    struct!(__MODULE__, [
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
end
