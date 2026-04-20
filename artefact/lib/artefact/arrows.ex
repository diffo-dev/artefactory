# SPDX-FileCopyrightText: 2026 diffo-dev
# SPDX-License-Identifier: MIT

defmodule Artefact.Arrows do
  @moduledoc """
  Lossless round-trip between `%Artefact{}` and Arrows JSON.

  Fields dropped on import (render concerns only):
  - `caption` on nodes — no Cypher equivalent
  - `style` at all levels — renderer's responsibility
  """

  @doc "Parse Arrows JSON string into an `%Artefact{}`. Returns `{:ok, artefact}` or `{:error, reason}`."
  def from_json(json, opts \\ []) do
    with {:ok, raw} <- Jason.decode(json) do
      {:ok, decode(raw, opts)}
    end
  end

  @doc "Parse Arrows JSON string, raising on error."
  def from_json!(json, opts \\ []) do
    json |> Jason.decode!() |> decode(opts)
  end

  @doc "Encode an `%Artefact{}` to Arrows JSON string."
  def to_json(%Artefact{} = artefact) do
    artefact |> encode() |> Jason.encode!()
  end

  # -- decode --

  defp decode(raw, opts) do
    nodes = raw |> Map.get("nodes", []) |> Enum.map(&decode_node/1)
    relationships = raw |> Map.get("relationships", []) |> Enum.map(&decode_relationship/1)

    graph = %Artefact.Graph{nodes: nodes, relationships: relationships}

    %Artefact{
      id: Keyword.get(opts, :id, Artefact.UUID.generate_v7()),
      uuid: Keyword.get(opts, :uuid, Map.get(raw, "uuid", Artefact.UUID.generate_v7())),
      title: Keyword.get(opts, :title),
      style: Keyword.get(opts, :style),
      graph: graph,
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  defp decode_node(raw) do
    props = Map.get(raw, "properties", %{})
    {uuid, props} = Map.pop(props, "uuid", Artefact.UUID.generate_v7())

    %Artefact.Node{
      id: raw["id"],
      uuid: uuid,
      labels: Map.get(raw, "labels", []),
      properties: props,
      position: decode_position(raw["position"])
    }
  end

  defp decode_position(nil), do: nil
  defp decode_position(%{"x" => x, "y" => y}), do: %{x: x, y: y}

  defp decode_relationship(raw) do
    %Artefact.Relationship{
      id: raw["id"],
      type: raw["type"],
      from_id: raw["fromId"],
      to_id: raw["toId"],
      properties: Map.get(raw, "properties", %{})
    }
  end

  # -- encode --

  defp encode(%Artefact{uuid: uuid, graph: graph}) do
    %{
      "uuid" => uuid,
      "style" => %{},
      "nodes" => Enum.map(graph.nodes, &encode_node/1),
      "relationships" => Enum.map(graph.relationships, &encode_relationship/1)
    }
  end

  defp encode_node(%Artefact.Node{} = node) do
    props = Map.put(node.properties, "uuid", node.uuid)

    base = %{
      "id" => node.id,
      "labels" => node.labels,
      "properties" => props,
      "caption" => "",
      "style" => %{}
    }

    case node.position do
      nil -> base
      pos -> Map.put(base, "position", %{"x" => pos.x, "y" => pos.y})
    end
  end

  defp encode_relationship(%Artefact.Relationship{} = rel) do
    %{
      "id" => rel.id,
      "type" => rel.type,
      "fromId" => rel.from_id,
      "toId" => rel.to_id,
      "properties" => rel.properties,
      "style" => %{}
    }
  end

end
