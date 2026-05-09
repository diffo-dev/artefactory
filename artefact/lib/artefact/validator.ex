# SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Artefact.Validator do
  @moduledoc """
  Validates `%Artefact{}` structs against the structural rules
  documented in `Artefact`.

  Public predicates and validators are surfaced through `Artefact`
  itself via `defdelegate`; this module is the implementation home.

  An artefact is *valid* when:

    * its uuid is a valid UUIDv7
    * `:title`, `:description`, `:base_label` are each `nil` or a string
    * `:graph` is `%Artefact.Graph{}` with list `:nodes` and `:relationships`
    * every node has a non-empty string `:id`, a UUIDv7 `:uuid`, a list
      of string `:labels`, and a map `:properties`
    * every relationship has a non-empty string `:id`, a non-empty
      string `:type`, `:from_id` and `:to_id` referring to extant
      nodes, and a map `:properties`
    * node uuids, node ids and relationship ids are unique within the
      graph
  """

  alias Artefact.Error.Invalid

  @doc "Returns `true` when `value` is an `%Artefact{}` struct."
  def is_artefact?(%Artefact{}), do: true
  def is_artefact?(_), do: false

  @doc "Returns `true` when `value` is a valid artefact."
  def is_valid?(value) do
    case validate(value) do
      :ok -> true
      {:error, _} -> false
    end
  end

  @doc """
  Validate an artefact. Returns `:ok` or `{:error, %Artefact.Error.Invalid{reasons: [...]}}`.

  `:reasons` is a list of human-readable strings, one per rule
  violation, in source order.
  """
  def validate(%Artefact{} = a) do
    reasons =
      []
      |> check(Artefact.UUID.valid?(a.uuid), "uuid is not a valid UUIDv7")
      |> check_string_or_nil(a.title, :title)
      |> check_string_or_nil(a.description, :description)
      |> check_string_or_nil(a.base_label, :base_label)
      |> check_graph(a.graph)

    case reasons do
      [] -> :ok
      _ -> {:error, %Invalid{reasons: Enum.reverse(reasons)}}
    end
  end

  def validate(_), do: {:error, %Invalid{reasons: ["not an %Artefact{} struct"]}}

  @doc """
  Validate an artefact. Returns `:ok` or raises `Artefact.Error.Invalid`
  with the collected reasons.
  """
  def validate!(value) do
    case validate(value) do
      :ok -> :ok
      {:error, %Invalid{} = e} -> raise e
    end
  end

  # ---- helpers -------------------------------------------------------

  defp check(reasons, true, _msg), do: reasons
  defp check(reasons, false, msg), do: [msg | reasons]

  defp check_string_or_nil(reasons, nil, _field), do: reasons
  defp check_string_or_nil(reasons, value, _field) when is_binary(value), do: reasons

  defp check_string_or_nil(reasons, _value, field),
    do: ["#{field} is not a string or nil" | reasons]

  defp check_graph(reasons, %Artefact.Graph{nodes: nodes, relationships: rels})
       when is_list(nodes) and is_list(rels) do
    reasons
    |> check_nodes(nodes)
    |> check_relationships(rels, nodes)
  end

  defp check_graph(reasons, _),
    do: ["graph is not %Artefact.Graph{} with list nodes/relationships" | reasons]

  defp check_nodes(reasons, nodes) do
    reasons
    |> then(fn r ->
      nodes
      |> Enum.with_index()
      |> Enum.reduce(r, fn {n, i}, acc -> check_node(acc, n, i) end)
    end)
    |> check_unique(Enum.map(nodes, &node_uuid/1), "node uuid")
    |> check_unique(Enum.map(nodes, &node_id/1), "node id")
  end

  defp node_uuid(%Artefact.Node{uuid: u}), do: u
  defp node_uuid(_), do: nil
  defp node_id(%Artefact.Node{id: id}), do: id
  defp node_id(_), do: nil

  defp check_node(reasons, %Artefact.Node{} = n, idx) do
    p = "node[#{idx}]"

    reasons
    |> check(is_binary(n.id) and n.id != "", "#{p} id is not a non-empty string")
    |> check(Artefact.UUID.valid?(n.uuid), "#{p} uuid is not a valid UUIDv7")
    |> check(
      is_list(n.labels) and Enum.all?(n.labels, &is_binary/1),
      "#{p} labels is not a list of strings"
    )
    |> check(is_map(n.properties), "#{p} properties is not a map")
  end

  defp check_node(reasons, _, idx), do: ["node[#{idx}] is not %Artefact.Node{}" | reasons]

  defp check_relationships(reasons, rels, nodes) do
    node_ids =
      MapSet.new(nodes, fn
        %Artefact.Node{id: id} -> id
        _ -> nil
      end)

    reasons =
      rels
      |> Enum.with_index()
      |> Enum.reduce(reasons, fn {r, i}, acc -> check_relationship(acc, r, i, node_ids) end)

    check_unique(
      reasons,
      Enum.map(rels, fn
        %Artefact.Relationship{id: id} -> id
        _ -> nil
      end),
      "relationship id"
    )
  end

  defp check_relationship(reasons, %Artefact.Relationship{} = r, idx, node_ids) do
    p = "relationship[#{idx}]"

    reasons
    |> check(is_binary(r.id) and r.id != "", "#{p} id is not a non-empty string")
    |> check(is_binary(r.type) and r.type != "", "#{p} type is not a non-empty string")
    |> check(
      MapSet.member?(node_ids, r.from_id),
      "#{p} from_id #{inspect(r.from_id)} not in graph"
    )
    |> check(MapSet.member?(node_ids, r.to_id), "#{p} to_id #{inspect(r.to_id)} not in graph")
    |> check(is_map(r.properties), "#{p} properties is not a map")
  end

  defp check_relationship(reasons, _, idx, _),
    do: ["relationship[#{idx}] is not %Artefact.Relationship{}" | reasons]

  defp check_unique(reasons, list, label) do
    duplicates = (list -- Enum.uniq(list)) |> Enum.uniq() |> Enum.reject(&is_nil/1)

    case duplicates do
      [] -> reasons
      dupes -> ["duplicate #{label}s: #{inspect(dupes)}" | reasons]
    end
  end
end
