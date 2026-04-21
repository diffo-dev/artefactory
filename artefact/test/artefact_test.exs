# SPDX-FileCopyrightText: 2026 diffo-dev
# SPDX-License-Identifier: MIT

defmodule ArtefactTest do
  use ExUnit.Case, async: true
  require Artefact

  @fixtures Path.join(__DIR__, "data")

  defp shared_node, do: %Artefact.Node{id: "n0", uuid: "019d0000-0000-7000-8000-000000000000", labels: ["Shared"], properties: %{}}
  defp other_node(uuid), do: %Artefact.Node{id: "n1", uuid: uuid, labels: ["Other"], properties: %{}}

  defp artefact_with(nodes) do
    Artefact.new(graph: %Artefact.Graph{nodes: nodes, relationships: []})
  end

  describe "provenance" do
    test "new records :struct provenance with calling module" do
      a = Artefact.new()
      assert %{provenance: %{source: :struct, module: ArtefactTest}} = a.metadata
    end

    test "from_json records :arrows_json provenance" do
      json = File.read!(Path.join([@fixtures, "us_two", "arrows.json"]))
      a = Artefact.Arrows.from_json!(json)
      assert %{provenance: %{source: :arrows_json, diagram: nil}} = a.metadata
    end

    test "from_json records diagram when provided" do
      json = File.read!(Path.join([@fixtures, "us_two", "arrows.json"]))
      a = Artefact.Arrows.from_json!(json, diagram: "us_two/arrows.json")
      assert %{provenance: %{source: :arrows_json, diagram: "us_two/arrows.json"}} = a.metadata
    end

    test "compose records :composed provenance with left and right title, base_label, uuid and provenance" do
      a1 = Artefact.new()
      a2 = Artefact.new()
      composed = Artefact.compose(a1, a2)
      assert %{provenance: %{source: :composed, module: ArtefactTest,
                             left:  %{title: left_title,  base_label: left_bl,  uuid: left_uuid,  provenance: left_prov},
                             right: %{title: right_title, base_label: right_bl, uuid: right_uuid, provenance: right_prov}}} = composed.metadata
      assert left_title  == a1.title
      assert left_bl     == a1.base_label
      assert left_uuid   == a1.uuid
      assert right_title == a2.title
      assert right_bl    == a2.base_label
      assert right_uuid  == a2.uuid
      assert left_prov   == a1.metadata.provenance
      assert right_prov  == a2.metadata.provenance
    end

    test "harmonise records :harmonised provenance with left and right title, base_label, uuid and provenance" do
      a1 = Artefact.new(base_label: "LeftArtefact", graph: %Artefact.Graph{nodes: [shared_node()], relationships: []})
      a2 = Artefact.new(base_label: "RightArtefact", graph: %Artefact.Graph{nodes: [shared_node()], relationships: []})
      {:ok, bindings} = Artefact.Binding.find(a1, a2)
      result = Artefact.harmonise(a1, a2, bindings)
      assert %{provenance: %{source: :harmonised, module: ArtefactTest,
                             left:  %{title: left_title,  base_label: left_bl,  uuid: left_uuid,  provenance: left_prov},
                             right: %{title: right_title, base_label: right_bl, uuid: right_uuid, provenance: right_prov}}} = result.metadata
      assert left_title  == a1.title
      assert left_bl     == a1.base_label
      assert left_uuid   == a1.uuid
      assert right_title == a2.title
      assert right_bl    == a2.base_label
      assert right_uuid  == a2.uuid
      assert left_prov   == a1.metadata.provenance
      assert right_prov  == a2.metadata.provenance
    end
  end

  describe "Artefact.new/1 — inline nodes and relationships" do
    test "builds nodes with sequential ids" do
      a = Artefact.new(
        nodes: [
          matt:   [labels: ["Agent", "Me"],  properties: %{"name" => "Matt"}],
          claude: [labels: ["Agent", "You"], properties: %{"name" => "Claude"}]
        ],
        relationships: []
      )
      by_id = Map.new(a.graph.nodes, &{&1.id, &1})
      assert map_size(by_id) == 2
      assert Map.has_key?(by_id, "n0")
      assert Map.has_key?(by_id, "n1")
    end

    test "nodes have correct labels and properties" do
      a = Artefact.new(
        nodes: [
          matt:   [labels: ["Agent", "Me"],  properties: %{"name" => "Matt"}],
          claude: [labels: ["Agent", "You"], properties: %{"name" => "Claude"}]
        ],
        relationships: []
      )
      by_id = Map.new(a.graph.nodes, &{&1.id, &1})
      assert by_id["n0"].labels == ["Agent", "Me"]
      assert by_id["n0"].properties == %{"name" => "Matt"}
      assert by_id["n1"].labels == ["Agent", "You"]
      assert by_id["n1"].properties == %{"name" => "Claude"}
    end

    test "nodes get auto-generated uuids" do
      a = Artefact.new(nodes: [n: [labels: ["X"]]], relationships: [])
      [node] = a.graph.nodes
      assert is_binary(node.uuid)
      assert String.length(node.uuid) == 36
    end

    test "uuid option is preserved" do
      fixed_uuid = "019da897-f2de-77ca-b5a4-40f0c3730943"
      a = Artefact.new(nodes: [n: [labels: [], uuid: fixed_uuid]], relationships: [])
      [node] = a.graph.nodes
      assert node.uuid == fixed_uuid
    end

    test "builds relationship resolving atom keys to ids" do
      a = Artefact.new(
        nodes: [
          matt:   [labels: ["Agent"]],
          claude: [labels: ["Agent"]]
        ],
        relationships: [
          [from: :matt, type: "US_TWO", to: :claude]
        ]
      )
      [rel] = a.graph.relationships
      assert rel.from_id == "n0"
      assert rel.to_id   == "n1"
      assert rel.type    == "US_TWO"
    end

    test "relationship properties default to empty map" do
      a = Artefact.new(
        nodes: [a: [labels: []], b: [labels: []]],
        relationships: [[from: :a, type: "KNOWS", to: :b]]
      )
      [rel] = a.graph.relationships
      assert rel.properties == %{}
    end

    test "relationship properties are set when provided" do
      a = Artefact.new(
        nodes: [a: [labels: []], b: [labels: []]],
        relationships: [[from: :a, type: "KNOWS", to: :b, properties: %{"since" => "2024"}]]
      )
      [rel] = a.graph.relationships
      assert rel.properties == %{"since" => "2024"}
    end

    test "empty nodes and relationships produces empty graph" do
      a = Artefact.new(title: "Empty", nodes: [], relationships: [])
      assert a.graph.nodes == []
      assert a.graph.relationships == []
    end

    test "no nodes or relationships key leaves graph as default" do
      a = Artefact.new(title: "NoGraph")
      assert a.graph == %Artefact.Graph{}
    end
  end

  describe "Artefact.new/1 — inline nodes and relationships — multiple relationships" do
    setup do
      a = Artefact.new(
        nodes: [x: [labels: ["X"]], y: [labels: ["Y"]], z: [labels: ["Z"]]],
        relationships: [
          [from: :x, type: "NEXT", to: :y],
          [from: :y, type: "NEXT", to: :z]
        ]
      )
      %{artefact: a}
    end

    test "all relationships built", %{artefact: a} do
      assert length(a.graph.relationships) == 2
    end

    test "relationship ids are sequential", %{artefact: a} do
      ids = Enum.map(a.graph.relationships, & &1.id)
      assert ids == ["r0", "r1"]
    end

    test "chain resolves correctly", %{artefact: a} do
      by_id = Map.new(a.graph.nodes, &{&1.id, &1})
      [r0, r1] = a.graph.relationships
      assert r0.from_id == "n0" and r0.to_id == "n1"
      assert r1.from_id == "n1" and r1.to_id == "n2"
      assert by_id["n0"].labels == ["X"]
      assert by_id["n2"].labels == ["Z"]
    end
  end

  describe "Artefact.new/1 — us_two inline vs JSON fixture" do
    setup do
      json = File.read!(Path.join([@fixtures, "us_two", "arrows.json"]))
      from_json = Artefact.Arrows.from_json!(json)

      from_struct = Artefact.new(
        title: "UsTwo",
        base_label: "UsTwo",
        nodes: [
          matt:   [labels: ["Agent", "Me"],  properties: %{"name" => "Matt"},
                   uuid: "019da897-f2de-77ca-b5a4-40f0c3730943"],
          claude: [labels: ["Agent", "You"], properties: %{"name" => "Claude"},
                   uuid: "019da897-f2de-768c-94e2-3005f2431f37"]
        ],
        relationships: [
          [from: :matt, type: "US_TWO", to: :claude]
        ]
      )

      %{from_json: from_json, from_struct: from_struct}
    end

    test "same title and base_label", %{from_json: j, from_struct: s} do
      assert s.title      == j.title
      assert s.base_label == j.base_label
    end

    test "same number of nodes and relationships", %{from_json: j, from_struct: s} do
      assert length(s.graph.nodes)         == length(j.graph.nodes)
      assert length(s.graph.relationships) == length(j.graph.relationships)
    end

    test "node labels match", %{from_json: j, from_struct: s} do
      labels = fn a -> a.graph.nodes |> Enum.map(& &1.labels) |> Enum.sort() end
      assert labels.(s) == labels.(j)
    end

    test "node properties match", %{from_json: j, from_struct: s} do
      props = fn a -> a.graph.nodes |> Enum.map(& &1.properties) |> Enum.sort_by(& &1["name"]) end
      assert props.(s) == props.(j)
    end

    test "node uuids match", %{from_json: j, from_struct: s} do
      uuids = fn a -> a.graph.nodes |> Enum.map(& &1.uuid) |> Enum.sort() end
      assert uuids.(s) == uuids.(j)
    end

    test "relationship type and direction match", %{from_json: j, from_struct: s} do
      [sr] = s.graph.relationships
      [jr] = j.graph.relationships
      assert sr.type == jr.type
      from_uuid = fn a, rel_id -> Enum.find(a.graph.nodes, &(&1.id == rel_id)).uuid end
      assert from_uuid.(s, sr.from_id) == from_uuid.(j, jr.from_id)
      assert from_uuid.(s, sr.to_id)   == from_uuid.(j, jr.to_id)
    end
  end

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

  describe "Artefact.Binding.find/3" do
    test "finds shared uuid automatically" do
      a1 = artefact_with([shared_node(), other_node("019d0000-0000-7000-8000-000000000001")])
      a2 = artefact_with([shared_node(), other_node("019d0000-0000-7000-8000-000000000002")])

      assert {:ok, [%Artefact.Binding{uuid_a: uuid, uuid_b: uuid}]} = Artefact.Binding.find(a1, a2)
      assert uuid == shared_node().uuid
    end

    test "returns no_match when no shared nodes" do
      a1 = artefact_with([other_node("019d0000-0000-7000-8000-000000000001")])
      a2 = artefact_with([other_node("019d0000-0000-7000-8000-000000000002")])

      assert {:error, :no_match} = Artefact.Binding.find(a1, a2)
    end

    test "inject adds explicit bindings between different uuids" do
      uuid_a = "019d0000-0000-7000-8000-000000000001"
      uuid_b = "019d0000-0000-7000-8000-000000000002"
      a1 = artefact_with([other_node(uuid_a)])
      a2 = artefact_with([other_node(uuid_b)])

      assert {:ok, [%Artefact.Binding{uuid_a: ^uuid_a, uuid_b: ^uuid_b}]} =
               Artefact.Binding.find(a1, a2, inject: [{uuid_a, uuid_b}])
    end

    test "inject combines with automatic matches" do
      uuid_a = "019d0000-0000-7000-8000-000000000001"
      uuid_b = "019d0000-0000-7000-8000-000000000002"
      a1 = artefact_with([shared_node(), other_node(uuid_a)])
      a2 = artefact_with([shared_node(), other_node(uuid_b)])

      assert {:ok, bindings} = Artefact.Binding.find(a1, a2, inject: [{uuid_a, uuid_b}])
      assert length(bindings) == 2
    end
  end

  describe "Artefact.harmonise/4 — property merge" do
    @uuid_shared "019d0000-0000-7000-8000-000000000000"

    defp node_with_props(uuid, props) do
      %Artefact.Node{id: "n0", uuid: uuid, labels: [], properties: props}
    end

    defp artefact_nodes(nodes) do
      %Artefact{
        id: Artefact.UUID.generate_v7(), uuid: Artefact.UUID.generate_v7(),
        title: nil, base_label: nil, style: nil, metadata: %{},
        graph: %Artefact.Graph{nodes: nodes, relationships: []}
      }
    end

    test "different keys are merged into bound node" do
      n_a = %{node_with_props(@uuid_shared, %{"key_a" => "from_a"}) | id: "n0"}
      n_b = %{node_with_props(@uuid_shared, %{"key_b" => "from_b"}) | id: "n0"}
      a1 = artefact_nodes([n_a])
      a2 = artefact_nodes([n_b])
      {:ok, bindings} = Artefact.Binding.find(a1, a2)
      result = Artefact.harmonise(a1, a2, bindings)
      [merged] = result.graph.nodes
      assert merged.properties == %{"key_a" => "from_a", "key_b" => "from_b"}
    end

    test "same key same value — one copy survives" do
      n_a = %{node_with_props(@uuid_shared, %{"key" => "same"}) | id: "n0"}
      n_b = %{node_with_props(@uuid_shared, %{"key" => "same"}) | id: "n0"}
      a1 = artefact_nodes([n_a])
      a2 = artefact_nodes([n_b])
      {:ok, bindings} = Artefact.Binding.find(a1, a2)
      result = Artefact.harmonise(a1, a2, bindings)
      [merged] = result.graph.nodes
      assert merged.properties == %{"key" => "same"}
    end

    test "same key different value — left (a1) wins" do
      n_a = %{node_with_props(@uuid_shared, %{"key" => "left"}) | id: "n0"}
      n_b = %{node_with_props(@uuid_shared, %{"key" => "right"}) | id: "n0"}
      a1 = artefact_nodes([n_a])
      a2 = artefact_nodes([n_b])
      {:ok, bindings} = Artefact.Binding.find(a1, a2)
      result = Artefact.harmonise(a1, a2, bindings)
      [merged] = result.graph.nodes
      assert merged.properties["key"] == "left"
    end

    test "labels are unioned" do
      n_a = %Artefact.Node{id: "n0", uuid: @uuid_shared, labels: ["LabelA"], properties: %{}}
      n_b = %Artefact.Node{id: "n0", uuid: @uuid_shared, labels: ["LabelB"], properties: %{}}
      a1 = artefact_nodes([n_a])
      a2 = artefact_nodes([n_b])
      {:ok, bindings} = Artefact.Binding.find(a1, a2)
      result = Artefact.harmonise(a1, a2, bindings)
      [merged] = result.graph.nodes
      assert Enum.sort(merged.labels) == ["LabelA", "LabelB"]
    end

    test "shared label appears once in union" do
      n_a = %Artefact.Node{id: "n0", uuid: @uuid_shared, labels: ["Shared", "OnlyA"], properties: %{}}
      n_b = %Artefact.Node{id: "n0", uuid: @uuid_shared, labels: ["Shared", "OnlyB"], properties: %{}}
      a1 = artefact_nodes([n_a])
      a2 = artefact_nodes([n_b])
      {:ok, bindings} = Artefact.Binding.find(a1, a2)
      result = Artefact.harmonise(a1, a2, bindings)
      [merged] = result.graph.nodes
      assert Enum.sort(merged.labels) == ["OnlyA", "OnlyB", "Shared"]
    end
  end

  describe "Artefact.harmonise/4 — guards" do
    test "raises when harmonising an artefact with itself" do
      a = artefact_with([shared_node()])
      {:ok, bindings} = Artefact.Binding.find(a, a)
      assert_raise ArgumentError, ~r/cannot harmonise an artefact with itself/, fn ->
        Artefact.harmonise(a, a, bindings)
      end
    end

    test "raises when both artefacts have the same base_label" do
      a1 = Artefact.new(base_label: "Same")
      a2 = Artefact.new(base_label: "Same")
      assert_raise ArgumentError, ~r/cannot harmonise artefacts with the same base_label/, fn ->
        Artefact.harmonise(a1, a2, [])
      end
    end
  end

  describe "Artefact.harmonise/4 — relationship deduplication" do
    @uuid_a "019d0000-0000-7000-8000-000000000010"
    @uuid_b "019d0000-0000-7000-8000-000000000020"

    defp two_node_artefact(uuid_x, uuid_y, id_x, id_y, rels) do
      nodes = [
        %Artefact.Node{id: id_x, uuid: uuid_x, labels: [], properties: %{}},
        %Artefact.Node{id: id_y, uuid: uuid_y, labels: [], properties: %{}}
      ]
      %Artefact{
        id: Artefact.UUID.generate_v7(), uuid: Artefact.UUID.generate_v7(),
        title: nil, base_label: nil, style: nil, metadata: %{},
        graph: %Artefact.Graph{nodes: nodes, relationships: rels}
      }
    end

    test "identical relationship appears once after harmonise" do
      a1 = two_node_artefact(@uuid_a, @uuid_b, "n0", "n1",
        [%Artefact.Relationship{id: "r0", from_id: "n0", to_id: "n1", type: "KNOWS", properties: %{}}])
      a2 = two_node_artefact(@uuid_a, @uuid_b, "n0", "n1",
        [%Artefact.Relationship{id: "r0", from_id: "n0", to_id: "n1", type: "KNOWS", properties: %{}}])
      {:ok, bindings} = Artefact.Binding.find(a1, a2)
      result = Artefact.harmonise(a1, a2, bindings)
      assert length(result.graph.relationships) == 1
    end

    test "different type relationships both survive" do
      a1 = two_node_artefact(@uuid_a, @uuid_b, "n0", "n1",
        [%Artefact.Relationship{id: "r0", from_id: "n0", to_id: "n1", type: "KNOWS", properties: %{}}])
      a2 = two_node_artefact(@uuid_a, @uuid_b, "n0", "n1",
        [%Artefact.Relationship{id: "r1", from_id: "n0", to_id: "n1", type: "TRUSTS", properties: %{}}])
      {:ok, bindings} = Artefact.Binding.find(a1, a2)
      result = Artefact.harmonise(a1, a2, bindings)
      assert length(result.graph.relationships) == 2
    end

    test "opposite direction relationships both survive" do
      a1 = two_node_artefact(@uuid_a, @uuid_b, "n0", "n1",
        [%Artefact.Relationship{id: "r0", from_id: "n0", to_id: "n1", type: "KNOWS", properties: %{}}])
      a2 = two_node_artefact(@uuid_a, @uuid_b, "n0", "n1",
        [%Artefact.Relationship{id: "r1", from_id: "n1", to_id: "n0", type: "KNOWS", properties: %{}}])
      {:ok, bindings} = Artefact.Binding.find(a1, a2)
      result = Artefact.harmonise(a1, a2, bindings)
      assert length(result.graph.relationships) == 2
    end

    test "duplicate relationship properties merged left-wins" do
      a1 = two_node_artefact(@uuid_a, @uuid_b, "n0", "n1",
        [%Artefact.Relationship{id: "r0", from_id: "n0", to_id: "n1", type: "KNOWS", properties: %{"since" => "2020", "trust" => "high"}}])
      a2 = two_node_artefact(@uuid_a, @uuid_b, "n0", "n1",
        [%Artefact.Relationship{id: "r1", from_id: "n0", to_id: "n1", type: "KNOWS", properties: %{"since" => "2019", "source" => "intro"}}])
      {:ok, bindings} = Artefact.Binding.find(a1, a2)
      result = Artefact.harmonise(a1, a2, bindings)
      [rel] = result.graph.relationships
      assert rel.properties["since"] == "2020"
      assert rel.properties["trust"] == "high"
      assert rel.properties["source"] == "intro"
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

    test "base_label is Artefact", %{artefact: a} do
      assert a.base_label == "Artefact"
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

  describe "artefact_harmonise self-description" do
    setup do
      json = File.read!(Path.join([@fixtures, "artefact_harmonise", "arrows.json"]))
      %{artefact: Artefact.Arrows.from_json!(json, id: "artefact-harmonise")}
    end

    test "eight nodes", %{artefact: a} do
      assert length(a.graph.nodes) == 8
    end

    test "base_label is ArtefactHarmonise", %{artefact: a} do
      assert a.base_label == "ArtefactHarmonise"
    end

    test "has compose, harmonise, Binding, guards and outcomes", %{artefact: a} do
      names = Enum.map(a.graph.nodes, & &1.properties["name"]) |> MapSet.new()
      assert MapSet.member?(names, "compose")
      assert MapSet.member?(names, "harmonise")
      assert MapSet.member?(names, "Binding")
      assert MapSet.member?(names, "SameUUID")
      assert MapSet.member?(names, "SameBaseLabel")
    end

    test "Artefact struct node has shared uuid", %{artefact: a} do
      artefact_node = Enum.find(a.graph.nodes, &(&1.properties["name"] == "Artefact"))
      assert artefact_node.uuid == "019da897-f2e0-74b2-ab91-4d68115d4f71"
    end

    test "create Cypher matches fixture", %{artefact: a} do
      expected = File.read!(Path.join([@fixtures, "artefact_harmonise", "create_cypher.txt"])) |> String.trim()
      assert Artefact.Cypher.create(a) == expected
    end

    test "merge Cypher matches fixture", %{artefact: a} do
      expected = File.read!(Path.join([@fixtures, "artefact_harmonise", "merge_cypher.txt"])) |> String.trim()
      assert Artefact.Cypher.merge(a) == expected
    end
  end

  describe "artefact_combine self-description" do
    setup do
      json = File.read!(Path.join([@fixtures, "artefact_combine", "arrows.json"]))
      %{artefact: Artefact.Arrows.from_json!(json, id: "artefact-combine")}
    end

    test "seven nodes", %{artefact: a} do
      assert length(a.graph.nodes) == 7
    end

    test "base_label is ArtefactCombine", %{artefact: a} do
      assert a.base_label == "ArtefactCombine"
    end

    test "has compose and harmonise operations", %{artefact: a} do
      names = Enum.map(a.graph.nodes, & &1.properties["name"]) |> MapSet.new()
      assert MapSet.member?(names, "compose")
      assert MapSet.member?(names, "harmonise")
    end

    test "Artefact struct node has shared uuid", %{artefact: a} do
      artefact_node = Enum.find(a.graph.nodes, &(&1.properties["name"] == "Artefact"))
      assert artefact_node.uuid == "019da897-f2e0-74b2-ab91-4d68115d4f71"
    end

    test "create Cypher matches fixture", %{artefact: a} do
      expected = File.read!(Path.join([@fixtures, "artefact_combine", "create_cypher.txt"])) |> String.trim()
      assert Artefact.Cypher.create(a) == expected
    end

    test "merge Cypher matches fixture", %{artefact: a} do
      expected = File.read!(Path.join([@fixtures, "artefact_combine", "merge_cypher.txt"])) |> String.trim()
      assert Artefact.Cypher.merge(a) == expected
    end
  end
end
