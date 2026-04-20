# SPDX-FileCopyrightText: 2026 diffo-dev
# SPDX-License-Identifier: MIT

defmodule ArtefactTest do
  use ExUnit.Case, async: true

  @fixtures Path.join(__DIR__, "data")

  describe "Artefact.Arrows.from_json!/2 — us_two" do
    setup do
      json = File.read!(Path.join([@fixtures, "us_two", "arrows.json"]))
      artefact = Artefact.Arrows.from_json!(json, id: "us-two-test")
      %{artefact: artefact}
    end

    test "returns an Artefact struct", %{artefact: a} do
      assert %Artefact{} = a
      assert a.id == "us-two-test"
    end

    test "graph has 2 nodes", %{artefact: a} do
      assert length(a.graph.nodes) == 2
    end

    test "graph has 1 relationship", %{artefact: a} do
      assert length(a.graph.relationships) == 1
    end

    test "nodes have correct labels", %{artefact: a} do
      by_id = Map.new(a.graph.nodes, &{&1.id, &1})
      assert by_id["n0"].labels == ["Agent", "Me"]
      assert by_id["n1"].labels == ["Agent", "You"]
    end

    test "nodes have correct properties", %{artefact: a} do
      by_id = Map.new(a.graph.nodes, &{&1.id, &1})
      assert by_id["n0"].properties == %{"name" => "Matt"}
      assert by_id["n1"].properties == %{"name" => "Claude"}
    end

    test "nodes have a uuid", %{artefact: a} do
      Enum.each(a.graph.nodes, fn node ->
        assert is_binary(node.uuid)
        assert String.length(node.uuid) == 36
      end)
    end

    test "uuid is not in properties", %{artefact: a} do
      Enum.each(a.graph.nodes, fn node ->
        refute Map.has_key?(node.properties, "uuid")
      end)
    end

    test "nodes preserve position", %{artefact: a} do
      by_id = Map.new(a.graph.nodes, &{&1.id, &1})
      assert %{x: _, y: _} = by_id["n0"].position
    end

    test "caption is dropped", %{artefact: a} do
      Enum.each(a.graph.nodes, fn node ->
        refute Map.has_key?(node, :caption)
      end)
    end

    test "style is dropped from nodes", %{artefact: a} do
      Enum.each(a.graph.nodes, fn node ->
        refute Map.has_key?(node, :style)
      end)
    end

    test "relationship has correct type and direction", %{artefact: a} do
      [rel] = a.graph.relationships
      assert rel.type == "US_TWO"
      assert rel.from_id == "n0"
      assert rel.to_id == "n1"
    end
  end

  describe "Artefact.Arrows round-trip" do
    test "to_json/from_json! preserves nodes and relationships" do
      json = File.read!(Path.join([@fixtures, "us_two", "arrows.json"]))
      original = Artefact.Arrows.from_json!(json, id: "rt-test")
      round_tripped = original |> Artefact.Arrows.to_json() |> Artefact.Arrows.from_json!(id: "rt-test")

      assert length(round_tripped.graph.nodes) == length(original.graph.nodes)
      assert length(round_tripped.graph.relationships) == length(original.graph.relationships)

      orig_by_id = Map.new(original.graph.nodes, &{&1.id, &1})
      rt_by_id = Map.new(round_tripped.graph.nodes, &{&1.id, &1})

      Enum.each(orig_by_id, fn {id, orig_node} ->
        rt_node = rt_by_id[id]
        assert rt_node.labels == orig_node.labels
        assert rt_node.properties == orig_node.properties
        assert rt_node.position == orig_node.position
        assert rt_node.uuid == orig_node.uuid
      end)
    end
  end

  describe "Artefact.UUID" do
    test "generate_v7 produces version 7" do
      assert String.at(Artefact.UUID.generate_v7(), 14) == "7"
    end

    test "harmonise returns the lower of two uuids" do
      a = "018f0000-0000-7000-8000-000000000000"
      b = "018f0000-0000-7000-8000-000000000001"
      assert Artefact.UUID.harmonise(a, b) == a
      assert Artefact.UUID.harmonise(b, a) == a
    end

    test "harmonise is idempotent" do
      a = "018f0000-0000-7000-8000-000000000000"
      assert Artefact.UUID.harmonise(a, a) == a
    end
  end

  describe "Artefact.Cypher.create/1 — us_two" do
    test "matches fixture" do
      json = File.read!(Path.join([@fixtures, "us_two", "arrows.json"]))
      expected = File.read!(Path.join([@fixtures, "us_two", "create_cypher.txt"])) |> String.trim()

      artefact = Artefact.Arrows.from_json!(json)
      assert Artefact.Cypher.create(artefact) == expected
    end
  end

  describe "Artefact.Cypher.merge/1 — us_two" do
    setup do
      json = File.read!(Path.join([@fixtures, "us_two", "arrows.json"]))
      artefact = Artefact.Arrows.from_json!(json)
      %{artefact: artefact, cypher: Artefact.Cypher.merge(artefact)}
    end

    test "returns a string", %{cypher: cypher} do
      assert is_binary(cypher)
    end

    test "produces MERGE not CREATE", %{cypher: cypher} do
      assert String.contains?(cypher, "MERGE")
      refute String.contains?(cypher, "CREATE")
    end

    test "merges each node on its uuid inline", %{artefact: a, cypher: cypher} do
      Enum.each(a.graph.nodes, fn node ->
        assert String.contains?(cypher, "uuid: '#{node.uuid}'")
      end)
    end

    test "sets labels separately", %{cypher: cypher} do
      assert String.contains?(cypher, "SET")
      assert String.contains?(cypher, ":Agent")
    end
  end

  describe "Artefact.Cypher.merge_params/1 — us_two" do
    setup do
      json = File.read!(Path.join([@fixtures, "us_two", "arrows.json"]))
      artefact = Artefact.Arrows.from_json!(json)
      {cypher, params} = Artefact.Cypher.merge_params(artefact)
      %{artefact: artefact, cypher: cypher, params: params}
    end

    test "returns cypher and params tuple", %{cypher: cypher, params: params} do
      assert is_binary(cypher)
      assert is_map(params)
    end

    test "produces MERGE not CREATE", %{cypher: cypher} do
      assert String.contains?(cypher, "MERGE")
      refute String.contains?(cypher, "CREATE")
    end

    test "merges each node on a uuid param", %{artefact: a, cypher: cypher, params: params} do
      Enum.each(a.graph.nodes, fn node ->
        assert String.contains?(cypher, "uuid: $#{node.id}_uuid")
        assert params["#{node.id}_uuid"] == node.uuid
      end)
    end

    test "node properties are in params not inline", %{artefact: a, cypher: cypher, params: params} do
      Enum.each(a.graph.nodes, fn node ->
        assert String.contains?(cypher, "$#{node.id}_props")
        assert params["#{node.id}_props"] == node.properties
      end)
    end
  end

  describe "Artefact.Cypher.create_params/1 — us_two" do
    setup do
      json = File.read!(Path.join([@fixtures, "us_two", "arrows.json"]))
      artefact = Artefact.Arrows.from_json!(json)
      {cypher, params} = Artefact.Cypher.create_params(artefact)
      %{artefact: artefact, cypher: cypher, params: params}
    end

    test "returns cypher and params tuple", %{cypher: cypher, params: params} do
      assert is_binary(cypher)
      assert is_map(params)
    end

    test "produces CREATE not MERGE", %{cypher: cypher} do
      assert String.contains?(cypher, "CREATE")
      refute String.contains?(cypher, "MERGE")
    end

    test "node properties are in params not inline", %{artefact: a, cypher: cypher, params: params} do
      Enum.each(a.graph.nodes, fn node ->
        Enum.each(node.properties, fn {k, v} ->
          assert String.contains?(cypher, "$#{node.id}_#{k}")
          assert params["#{node.id}_#{k}"] == v
        end)
      end)
    end
  end

  describe "artefact self-description" do
    setup do
      json = File.read!(Path.join([@fixtures, "artefact", "arrows.json"]))
      %{artefact: Artefact.Arrows.from_json!(json, id: "artefact-self")}
    end

    test "three nodes — the forms", %{artefact: a} do
      assert length(a.graph.nodes) == 3
      labels = Enum.map(a.graph.nodes, & &1.labels) |> MapSet.new()
      assert MapSet.member?(labels, ["Format", "Canonical"])
      assert MapSet.member?(labels, ["Struct"])
      assert MapSet.member?(labels, ["Format", "Derived"])
    end

    test "three relationships — the journeys", %{artefact: a} do
      types = Enum.map(a.graph.relationships, & &1.type) |> MapSet.new()
      assert types == MapSet.new(["FROM_JSON", "TO_JSON", "EXPORT"])
    end

    test "Cypher export matches fixture", %{artefact: a} do
      expected = File.read!(Path.join([@fixtures, "artefact", "create_cypher.txt"])) |> String.trim()
      assert Artefact.Cypher.create(a) == expected
    end
  end
end
