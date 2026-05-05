# SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule ArtefactTest do
  use ExUnit.Case, async: true
  require Artefact

  @fixtures Path.join(__DIR__, "data")

  defp shared_node,
    do: %Artefact.Node{
      id: "n0",
      uuid: "019d0000-0000-7000-8000-000000000000",
      labels: ["Shared"],
      properties: %{}
    }

  defp other_node(uuid),
    do: %Artefact.Node{id: "n1", uuid: uuid, labels: ["Other"], properties: %{}}

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

      assert %{
               provenance: %{
                 source: :composed,
                 module: ArtefactTest,
                 left: %{
                   title: left_title,
                   base_label: left_bl,
                   uuid: left_uuid,
                   provenance: left_prov
                 },
                 right: %{
                   title: right_title,
                   base_label: right_bl,
                   uuid: right_uuid,
                   provenance: right_prov
                 }
               }
             } = composed.metadata

      assert left_title == a1.title
      assert left_bl == a1.base_label
      assert left_uuid == a1.uuid
      assert right_title == a2.title
      assert right_bl == a2.base_label
      assert right_uuid == a2.uuid
      assert left_prov == a1.metadata.provenance
      assert right_prov == a2.metadata.provenance
    end

    test "harmonise records :harmonised provenance with left and right title, base_label, uuid and provenance" do
      a1 =
        Artefact.new(
          base_label: "LeftArtefact",
          graph: %Artefact.Graph{nodes: [shared_node()], relationships: []}
        )

      a2 =
        Artefact.new(
          base_label: "RightArtefact",
          graph: %Artefact.Graph{nodes: [shared_node()], relationships: []}
        )

      {:ok, bindings} = Artefact.Binding.find(a1, a2)
      result = Artefact.harmonise(a1, a2, bindings)

      assert %{
               provenance: %{
                 source: :harmonised,
                 module: ArtefactTest,
                 left: %{
                   title: left_title,
                   base_label: left_bl,
                   uuid: left_uuid,
                   provenance: left_prov
                 },
                 right: %{
                   title: right_title,
                   base_label: right_bl,
                   uuid: right_uuid,
                   provenance: right_prov
                 }
               }
             } = result.metadata

      assert left_title == a1.title
      assert left_bl == a1.base_label
      assert left_uuid == a1.uuid
      assert right_title == a2.title
      assert right_bl == a2.base_label
      assert right_uuid == a2.uuid
      assert left_prov == a1.metadata.provenance
      assert right_prov == a2.metadata.provenance
    end
  end

  describe "Artefact.new/1 — inline nodes and relationships" do
    test "builds nodes with sequential ids" do
      a =
        Artefact.new(
          nodes: [
            matt: [labels: ["Agent", "Me"], properties: %{"name" => "Matt"}],
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
      a =
        Artefact.new(
          nodes: [
            matt: [labels: ["Agent", "Me"], properties: %{"name" => "Matt"}],
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
      a =
        Artefact.new(
          nodes: [
            matt: [labels: ["Agent"]],
            claude: [labels: ["Agent"]]
          ],
          relationships: [
            [from: :matt, type: "US_TWO", to: :claude]
          ]
        )

      [rel] = a.graph.relationships
      assert rel.from_id == "n0"
      assert rel.to_id == "n1"
      assert rel.type == "US_TWO"
    end

    test "relationship properties default to empty map" do
      a =
        Artefact.new(
          nodes: [a: [labels: []], b: [labels: []]],
          relationships: [[from: :a, type: "KNOWS", to: :b]]
        )

      [rel] = a.graph.relationships
      assert rel.properties == %{}
    end

    test "relationship properties are set when provided" do
      a =
        Artefact.new(
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
      a =
        Artefact.new(
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

      from_struct =
        Artefact.new(
          title: "UsTwo",
          base_label: "UsTwo",
          nodes: [
            matt: [
              labels: ["Agent", "Me"],
              properties: %{"name" => "Matt"},
              uuid: "019da897-f2de-77ca-b5a4-40f0c3730943"
            ],
            claude: [
              labels: ["Agent", "You"],
              properties: %{"name" => "Claude"},
              uuid: "019da897-f2de-768c-94e2-3005f2431f37"
            ]
          ],
          relationships: [
            [from: :matt, type: "US_TWO", to: :claude]
          ]
        )

      %{from_json: from_json, from_struct: from_struct}
    end

    test "same title and base_label", %{from_json: j, from_struct: s} do
      assert s.title == j.title
      assert s.base_label == j.base_label
    end

    test "same number of nodes and relationships", %{from_json: j, from_struct: s} do
      assert length(s.graph.nodes) == length(j.graph.nodes)
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
      assert from_uuid.(s, sr.to_id) == from_uuid.(j, jr.to_id)
    end

    test "inline build has :struct provenance", %{from_struct: s} do
      assert %{provenance: %{source: :struct, module: ArtefactTest}} = s.metadata
    end

    test "json build has :arrows_json provenance", %{from_json: j} do
      assert %{provenance: %{source: :arrows_json}} = j.metadata
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

      round_tripped =
        original |> Artefact.Arrows.to_json() |> Artefact.Arrows.from_json!(id: "rt-test")

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

      assert {:ok, [%Artefact.Binding{uuid_a: uuid, uuid_b: uuid}]} =
               Artefact.Binding.find(a1, a2)

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
        id: Artefact.UUID.generate_v7(),
        uuid: Artefact.UUID.generate_v7(),
        title: nil,
        base_label: nil,
        style: nil,
        metadata: %{},
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
      n_a = %Artefact.Node{
        id: "n0",
        uuid: @uuid_shared,
        labels: ["Shared", "OnlyA"],
        properties: %{}
      }

      n_b = %Artefact.Node{
        id: "n0",
        uuid: @uuid_shared,
        labels: ["Shared", "OnlyB"],
        properties: %{}
      }

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
        id: Artefact.UUID.generate_v7(),
        uuid: Artefact.UUID.generate_v7(),
        title: nil,
        base_label: nil,
        style: nil,
        metadata: %{},
        graph: %Artefact.Graph{nodes: nodes, relationships: rels}
      }
    end

    test "identical relationship appears once after harmonise" do
      a1 =
        two_node_artefact(@uuid_a, @uuid_b, "n0", "n1", [
          %Artefact.Relationship{
            id: "r0",
            from_id: "n0",
            to_id: "n1",
            type: "KNOWS",
            properties: %{}
          }
        ])

      a2 =
        two_node_artefact(@uuid_a, @uuid_b, "n0", "n1", [
          %Artefact.Relationship{
            id: "r0",
            from_id: "n0",
            to_id: "n1",
            type: "KNOWS",
            properties: %{}
          }
        ])

      {:ok, bindings} = Artefact.Binding.find(a1, a2)
      result = Artefact.harmonise(a1, a2, bindings)
      assert length(result.graph.relationships) == 1
    end

    test "different type relationships both survive" do
      a1 =
        two_node_artefact(@uuid_a, @uuid_b, "n0", "n1", [
          %Artefact.Relationship{
            id: "r0",
            from_id: "n0",
            to_id: "n1",
            type: "KNOWS",
            properties: %{}
          }
        ])

      a2 =
        two_node_artefact(@uuid_a, @uuid_b, "n0", "n1", [
          %Artefact.Relationship{
            id: "r1",
            from_id: "n0",
            to_id: "n1",
            type: "TRUSTS",
            properties: %{}
          }
        ])

      {:ok, bindings} = Artefact.Binding.find(a1, a2)
      result = Artefact.harmonise(a1, a2, bindings)
      assert length(result.graph.relationships) == 2
    end

    test "opposite direction relationships both survive" do
      a1 =
        two_node_artefact(@uuid_a, @uuid_b, "n0", "n1", [
          %Artefact.Relationship{
            id: "r0",
            from_id: "n0",
            to_id: "n1",
            type: "KNOWS",
            properties: %{}
          }
        ])

      a2 =
        two_node_artefact(@uuid_a, @uuid_b, "n0", "n1", [
          %Artefact.Relationship{
            id: "r1",
            from_id: "n1",
            to_id: "n0",
            type: "KNOWS",
            properties: %{}
          }
        ])

      {:ok, bindings} = Artefact.Binding.find(a1, a2)
      result = Artefact.harmonise(a1, a2, bindings)
      assert length(result.graph.relationships) == 2
    end

    test "duplicate relationship properties merged left-wins" do
      a1 =
        two_node_artefact(@uuid_a, @uuid_b, "n0", "n1", [
          %Artefact.Relationship{
            id: "r0",
            from_id: "n0",
            to_id: "n1",
            type: "KNOWS",
            properties: %{"since" => "2020", "trust" => "high"}
          }
        ])

      a2 =
        two_node_artefact(@uuid_a, @uuid_b, "n0", "n1", [
          %Artefact.Relationship{
            id: "r1",
            from_id: "n0",
            to_id: "n1",
            type: "KNOWS",
            properties: %{"since" => "2019", "source" => "intro"}
          }
        ])

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

      expected =
        File.read!(Path.join([@fixtures, "us_two", "create_cypher.txt"])) |> String.trim()

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

    test "node properties are in params not inline", %{
      artefact: a,
      cypher: cypher,
      params: params
    } do
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

    test "node properties are in params not inline", %{
      artefact: a,
      cypher: cypher,
      params: params
    } do
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
      expected =
        File.read!(Path.join([@fixtures, "artefact", "create_cypher.txt"])) |> String.trim()

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

    test "base_label is Artefact Harmonise", %{artefact: a} do
      assert a.base_label == "Artefact Harmonise"
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
      expected =
        File.read!(Path.join([@fixtures, "artefact_harmonise", "create_cypher.txt"]))
        |> String.trim()

      assert Artefact.Cypher.create(a) == expected
    end

    test "merge Cypher matches fixture", %{artefact: a} do
      expected =
        File.read!(Path.join([@fixtures, "artefact_harmonise", "merge_cypher.txt"]))
        |> String.trim()

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
      expected =
        File.read!(Path.join([@fixtures, "artefact_combine", "create_cypher.txt"]))
        |> String.trim()

      assert Artefact.Cypher.create(a) == expected
    end

    test "merge Cypher matches fixture", %{artefact: a} do
      expected =
        File.read!(Path.join([@fixtures, "artefact_combine", "merge_cypher.txt"]))
        |> String.trim()

      assert Artefact.Cypher.merge(a) == expected
    end
  end

  describe "Artefact.Mermaid.export/2 — us_two" do
    setup do
      json = File.read!(Path.join([@fixtures, "us_two", "arrows.json"]))
      %{artefact: Artefact.Arrows.from_json!(json)}
    end

    test "matches fixture", %{artefact: a} do
      expected = File.read!(Path.join([@fixtures, "us_two", "mermaid.mmd"])) |> String.trim()
      assert Artefact.Mermaid.export(a) == expected
    end

    test "uses `graph LR` by default", %{artefact: a} do
      assert String.contains?(Artefact.Mermaid.export(a), "\ngraph LR\n")
    end

    test "respects :direction option", %{artefact: a} do
      assert String.contains?(Artefact.Mermaid.export(a, direction: :TB), "\ngraph TB\n")
    end

    test "emits front-matter title from artefact.title", %{artefact: a} do
      assert String.starts_with?(Artefact.Mermaid.export(a), "---\ntitle: UsTwo\n---\n")
    end

    test "emits accTitle mirroring the title", %{artefact: a} do
      assert String.contains?(Artefact.Mermaid.export(a), "  accTitle: UsTwo\n")
    end

    test "raises on unknown direction", %{artefact: a} do
      assert_raise ArgumentError, ~r/invalid :direction/, fn ->
        Artefact.Mermaid.export(a, direction: :sideways)
      end
    end

    test "renders node label as name + semantic labels in circle nodes", %{artefact: a} do
      mmd = Artefact.Mermaid.export(a)
      assert String.contains?(mmd, ~s|n0(("Matt<br/>Agent Me"))|)
      assert String.contains?(mmd, ~s|n1(("Claude<br/>Agent You"))|)
    end

    test "drops base_label from per-node labels", %{artefact: a} do
      mmd = Artefact.Mermaid.export(a)
      refute String.contains?(mmd, "UsTwo<br")
      refute String.contains?(mmd, " UsTwo\"")
    end

    test "renders relationship type between pipes", %{artefact: a} do
      assert String.contains?(Artefact.Mermaid.export(a), "n0 -->|US_TWO| n1")
    end
  end

  describe "Artefact.Mermaid.export/2 — escapes and edge cases" do
    test "falls back to node id when no name property is present" do
      a =
        Artefact.new(
          base_label: "Bare",
          nodes: [n: [labels: ["X"]]],
          relationships: []
        )

      assert String.contains?(Artefact.Mermaid.export(a), ~s|n0(("n0<br/>X"))|)
    end

    test "uses name only when no semantic labels remain" do
      a =
        Artefact.new(
          base_label: "Solo",
          nodes: [n: [labels: ["Solo"], properties: %{"name" => "alone"}]],
          relationships: []
        )

      mmd = Artefact.Mermaid.export(a)
      assert String.contains?(mmd, ~s|n0(("alone"))|)
      refute String.contains?(mmd, "<br/>")
    end

    test "escapes double quotes in node names" do
      a =
        Artefact.new(
          nodes: [q: [labels: [], properties: %{"name" => ~s|she said "hi"|}]],
          relationships: []
        )

      assert String.contains?(Artefact.Mermaid.export(a), ~s|n0(("she said &quot;hi&quot;"))|)
    end

    test "escapes pipes in relationship type" do
      a =
        Artefact.new(
          nodes: [a: [labels: []], b: [labels: []]],
          relationships: [[from: :a, type: "HAS|PIPE", to: :b]]
        )

      assert String.contains?(Artefact.Mermaid.export(a), "-->|HAS&#124;PIPE|")
    end

    test "empty untitled graph still emits a header" do
      a = Artefact.new(title: nil, nodes: [], relationships: [])
      assert Artefact.Mermaid.export(a) == "graph LR"
    end

    test "untitled artefact omits front-matter and accTitle" do
      a =
        Artefact.new(
          title: nil,
          nodes: [n: [labels: ["X"]]],
          relationships: []
        )

      mmd = Artefact.Mermaid.export(a)
      refute String.contains?(mmd, "---")
      refute String.contains?(mmd, "accTitle")
      assert String.starts_with?(mmd, "graph LR\n")
    end

    test "YAML-quotes a title containing a colon" do
      a = Artefact.new(title: "Sand Talk: a yarn", nodes: [], relationships: [])
      assert String.contains?(Artefact.Mermaid.export(a), ~s|title: "Sand Talk: a yarn"|)
    end

    test "YAML-quotes and escapes a title with a double quote" do
      a = Artefact.new(title: ~s|she said "hi"|, nodes: [], relationships: [])
      assert String.contains?(Artefact.Mermaid.export(a), ~s|title: "she said \\"hi\\""|)
    end

    test "accTitle escaping is independent of YAML quoting" do
      a = Artefact.new(title: "Sand Talk: a yarn", nodes: [], relationships: [])
      assert String.contains?(Artefact.Mermaid.export(a), "  accTitle: Sand Talk: a yarn")
    end
  end

  describe "Artefact.new/1 — :description option" do
    test "defaults to nil when not provided" do
      a = Artefact.new()
      assert a.description == nil
    end

    test "stores the description when provided" do
      a = Artefact.new(description: "the simplest true thing about us_two")
      assert a.description == "the simplest true thing about us_two"
    end

    test "description is independent of title" do
      a = Artefact.new(title: "UsTwo", description: "Me toward You")
      assert a.title == "UsTwo"
      assert a.description == "Me toward You"
    end
  end

  describe "Artefact.Arrows round-trip — description" do
    test "preserves a set description" do
      original =
        Artefact.new(
          title: "UsTwo",
          description: "the simplest true thing",
          base_label: "UsTwo",
          nodes: [a: [labels: ["Agent"]]],
          relationships: []
        )

      round_tripped = original |> Artefact.Arrows.to_json() |> Artefact.Arrows.from_json!()
      assert round_tripped.description == "the simplest true thing"
    end

    test "preserves a nil description" do
      original = Artefact.new(title: "Bare", nodes: [], relationships: [])
      assert original.description == nil

      round_tripped = original |> Artefact.Arrows.to_json() |> Artefact.Arrows.from_json!()
      assert round_tripped.description == nil
    end
  end

  describe "Artefact.Mermaid.export/2 — description" do
    test "emits accDescr inline when description is single-line" do
      a =
        Artefact.new(
          title: "UsTwo",
          description: "Me toward You",
          nodes: [],
          relationships: []
        )

      assert String.contains?(Artefact.Mermaid.export(a), "  accDescr: Me toward You")
    end

    test "uses block form when description contains newlines" do
      a =
        Artefact.new(
          title: "UsTwo",
          description: "first line\nsecond line",
          nodes: [],
          relationships: []
        )

      mmd = Artefact.Mermaid.export(a)
      assert String.contains?(mmd, "  accDescr {\n    first line\n    second line\n  }")
      refute String.contains?(mmd, "accDescr:")
    end

    test "omits accDescr when description is nil" do
      a = Artefact.new(title: "Titled but undescribed", nodes: [], relationships: [])
      mmd = Artefact.Mermaid.export(a)
      refute String.contains?(mmd, "accDescr")
    end

    test "accDescr appears after accTitle and before nodes" do
      a =
        Artefact.new(
          title: "Order",
          description: "matters",
          nodes: [n: [labels: ["X"]]],
          relationships: []
        )

      mmd = Artefact.Mermaid.export(a)
      title_idx = :binary.match(mmd, "accTitle:") |> elem(0)
      descr_idx = :binary.match(mmd, "accDescr:") |> elem(0)
      node_idx = :binary.match(mmd, "n0((") |> elem(0)
      assert title_idx < descr_idx
      assert descr_idx < node_idx
    end
  end

  describe "Artefact.combine/3" do
    @uuid_shared "019d0000-0000-7000-8000-000000000000"

    defp combine_artefact(base_label, uuid) do
      %Artefact{
        id: Artefact.UUID.generate_v7(),
        uuid: Artefact.UUID.generate_v7(),
        title: base_label,
        base_label: base_label,
        style: nil,
        metadata: %{},
        graph: %Artefact.Graph{
          nodes: [%Artefact.Node{id: "n0", uuid: uuid, labels: [], properties: %{}}],
          relationships: []
        }
      }
    end

    test "combines two artefacts via auto-found bindings" do
      heart = combine_artefact("Knowing", @uuid_shared)
      other = combine_artefact("Valuing", @uuid_shared)

      result = Artefact.combine(heart, other)
      assert length(result.graph.nodes) == 1
    end

    test "default base_label is portmanteau of heart + other" do
      heart = combine_artefact("Knowing", @uuid_shared)
      other = combine_artefact("Valuing", @uuid_shared)

      result = Artefact.combine(heart, other)
      assert result.base_label == "KnowingValuing"
    end

    test "title defaults to base_label when not given" do
      heart = combine_artefact("Knowing", @uuid_shared)
      other = combine_artefact("Valuing", @uuid_shared)

      result = Artefact.combine(heart, other)
      assert result.title == "KnowingValuing"
    end

    test "description defaults to nil when not given" do
      heart = combine_artefact("Knowing", @uuid_shared)
      other = combine_artefact("Valuing", @uuid_shared)

      result = Artefact.combine(heart, other)
      assert result.description == nil
    end

    test "applies title override from opts" do
      heart = combine_artefact("Knowing", @uuid_shared)
      other = combine_artefact("Valuing", @uuid_shared)

      result = Artefact.combine(heart, other, title: "Custom")
      assert result.title == "Custom"
    end

    test "applies description override from opts" do
      heart = combine_artefact("Knowing", @uuid_shared)
      other = combine_artefact("Valuing", @uuid_shared)

      result = Artefact.combine(heart, other, description: "yarned")
      assert result.description == "yarned"
    end

    test "applies title and description together" do
      heart = combine_artefact("Knowing", @uuid_shared)
      other = combine_artefact("Valuing", @uuid_shared)

      result = Artefact.combine(heart, other, title: "MeMind", description: "Mind of Me")
      assert result.title == "MeMind"
      assert result.description == "Mind of Me"
    end

    test "chains in a pipeline" do
      a = combine_artefact("Knowing", @uuid_shared)
      b = combine_artefact("Valuing", @uuid_shared)
      c = combine_artefact("Being", @uuid_shared)

      result = a |> Artefact.combine(b) |> Artefact.combine(c)
      assert result.base_label == "KnowingValuingBeing"
      assert length(result.graph.nodes) == 1
    end

    test "pipeline applies title and description on the final step" do
      a = combine_artefact("Knowing", @uuid_shared)
      b = combine_artefact("Valuing", @uuid_shared)
      c = combine_artefact("Being", @uuid_shared)

      result =
        a
        |> Artefact.combine(b)
        |> Artefact.combine(c, title: "MeMind", description: "Mind of Me")

      assert result.title == "MeMind"
      assert result.description == "Mind of Me"
    end

    test "records :harmonised provenance with calling module" do
      heart = combine_artefact("Knowing", @uuid_shared)
      other = combine_artefact("Valuing", @uuid_shared)

      result = Artefact.combine(heart, other)
      assert %{provenance: %{source: :harmonised, module: ArtefactTest}} = result.metadata
    end

    test "raises when artefacts have no shared nodes" do
      heart = combine_artefact("Knowing", "019d0000-0000-7000-8000-000000000010")
      other = combine_artefact("Valuing", "019d0000-0000-7000-8000-000000000020")

      assert_raise MatchError, fn -> Artefact.combine(heart, other) end
    end
  end

  describe "Artefact.graft/3 — happy path with OurShells fixture" do
    alias Artefact.Test.Fixtures.OurShells

    setup do
      left = OurShells.our_shells()

      result =
        Artefact.graft(left, OurShells.manifesto_args(),
          title: "Our Shells and Manifesto",
          description: "Our Shells and Manifesto shape our Association Knowing."
        )

      %{left: left, result: result}
    end

    test "result has opts title and description", %{result: r} do
      assert r.title == "Our Shells and Manifesto"
      assert r.description == "Our Shells and Manifesto shape our Association Knowing."
    end

    test "result keeps left base_label", %{left: left, result: r} do
      assert r.base_label == left.base_label
    end

    test "result is a fresh artefact (new uuid)", %{left: left, result: r} do
      assert r.uuid != left.uuid
    end

    test "new args nodes are appended to left graph", %{left: left, result: r} do
      assert length(r.graph.nodes) == length(left.graph.nodes) + 3

      uuids = Enum.map(r.graph.nodes, & &1.uuid)
      assert OurShells.ethics_uuid() in uuids
      assert OurShells.stewardship_uuid() in uuids
      assert OurShells.intent_uuid() in uuids
    end

    test "new node ids continue left's offset", %{left: left, result: r} do
      offset = length(left.graph.nodes)

      new_uuids =
        MapSet.new([
          OurShells.ethics_uuid(),
          OurShells.stewardship_uuid(),
          OurShells.intent_uuid()
        ])

      new_nodes = Enum.filter(r.graph.nodes, &MapSet.member?(new_uuids, &1.uuid))
      ids = new_nodes |> Enum.map(& &1.id) |> Enum.sort()
      expected = for i <- offset..(offset + 2), do: "n#{i}"
      assert ids == Enum.sort(expected)
    end

    test "bind-only nodes preserve their existing id", %{left: left, result: r} do
      left_by_uuid = Map.new(left.graph.nodes, &{&1.uuid, &1})
      result_by_uuid = Map.new(r.graph.nodes, &{&1.uuid, &1})

      for uuid <- [
            OurShells.me_uuid(),
            OurShells.council_uuid(),
            OurShells.core_uuid(),
            OurShells.association_uuid()
          ] do
        assert result_by_uuid[uuid].id == left_by_uuid[uuid].id
      end
    end

    test "new relationships from args are added", %{left: left, result: r} do
      assert length(r.graph.relationships) == length(left.graph.relationships) + 4
    end

    test "the four new KNOWING relationships are present", %{result: r} do
      result_by_uuid = Map.new(r.graph.nodes, &{&1.uuid, &1})

      pair = fn from_uuid, to_uuid ->
        from_id = result_by_uuid[from_uuid].id
        to_id = result_by_uuid[to_uuid].id

        Enum.any?(r.graph.relationships, fn rel ->
          rel.from_id == from_id and rel.to_id == to_id and rel.type == "KNOWING"
        end)
      end

      assert pair.(OurShells.me_uuid(), OurShells.stewardship_uuid())
      assert pair.(OurShells.council_uuid(), OurShells.ethics_uuid())
      assert pair.(OurShells.core_uuid(), OurShells.intent_uuid())
      assert pair.(OurShells.association_uuid(), OurShells.stewardship_uuid())
    end

    test "new relationships connect the right node ids", %{result: r} do
      result_by_uuid = Map.new(r.graph.nodes, &{&1.uuid, &1})
      me_id = result_by_uuid[OurShells.me_uuid()].id
      stewardship_id = result_by_uuid[OurShells.stewardship_uuid()].id

      assert Enum.any?(r.graph.relationships, fn rel ->
               rel.from_id == me_id and rel.to_id == stewardship_id and rel.type == "KNOWING"
             end)
    end

    test "records :grafted provenance with right title and description", %{left: left, result: r} do
      assert %{
               provenance: %{
                 source: :grafted,
                 module: ArtefactTest,
                 left: %{
                   title: left_title,
                   base_label: left_bl,
                   uuid: left_uuid,
                   provenance: left_prov
                 },
                 right: %{title: right_title, description: right_desc}
               }
             } = r.metadata

      assert left_title == left.title
      assert left_bl == left.base_label
      assert left_uuid == left.uuid
      assert left_prov == left.metadata.provenance

      assert right_title == "Our Shells and Manifesto"
      assert right_desc == "Our Shells and Manifesto shape our Association Knowing."
    end
  end

  describe "Artefact.graft/3 — opts behaviour" do
    alias Artefact.Test.Fixtures.OurShells

    test "title and description fall back to left when opts omits them" do
      left = OurShells.our_shells()
      result = Artefact.graft(left, OurShells.manifesto_args())

      assert result.title == left.title
      assert result.description == left.description
    end

    test "right provenance carries nil when opts omits title and description" do
      left = OurShells.our_shells()
      result = Artefact.graft(left, OurShells.manifesto_args())

      assert %{provenance: %{right: %{title: nil, description: nil}}} = result.metadata
    end

    test "base_label in opts is ignored — left's base_label always wins" do
      left = OurShells.our_shells()
      result = Artefact.graft(left, OurShells.manifesto_args(), base_label: "ShouldBeIgnored")

      assert result.base_label == left.base_label
    end
  end

  describe "Artefact.graft/3 — bind-only merge semantics" do
    @left_uuid "019d0000-0000-7000-8000-0000000000aa"

    defp single_node_artefact(labels, properties) do
      Artefact.new(
        title: "Left",
        nodes: [n: [labels: labels, properties: properties, uuid: @left_uuid]],
        relationships: []
      )
    end

    test "bind-only with new labels — labels are unioned" do
      left = single_node_artefact(["LeftLabel"], %{})

      result =
        Artefact.graft(left,
          nodes: [n: [labels: ["RightLabel"], uuid: @left_uuid]],
          relationships: []
        )

      [node] = result.graph.nodes
      assert Enum.sort(node.labels) == ["LeftLabel", "RightLabel"]
    end

    test "bind-only with shared label — appears once" do
      left = single_node_artefact(["Shared", "OnlyLeft"], %{})

      result =
        Artefact.graft(left,
          nodes: [n: [labels: ["Shared", "OnlyRight"], uuid: @left_uuid]],
          relationships: []
        )

      [node] = result.graph.nodes
      assert Enum.sort(node.labels) == ["OnlyLeft", "OnlyRight", "Shared"]
    end

    test "bind-only with new property keys — both survive" do
      left = single_node_artefact([], %{"left_key" => "L"})

      result =
        Artefact.graft(left,
          nodes: [n: [properties: %{"right_key" => "R"}, uuid: @left_uuid]],
          relationships: []
        )

      [node] = result.graph.nodes
      assert node.properties == %{"left_key" => "L", "right_key" => "R"}
    end

    test "bind-only with conflicting property — left wins" do
      left = single_node_artefact([], %{"shared_key" => "from_left"})

      result =
        Artefact.graft(left,
          nodes: [n: [properties: %{"shared_key" => "from_right"}, uuid: @left_uuid]],
          relationships: []
        )

      [node] = result.graph.nodes
      assert node.properties["shared_key"] == "from_left"
    end

    test "bind-only does not append a new node" do
      left = single_node_artefact(["X"], %{})

      result =
        Artefact.graft(left,
          nodes: [n: [uuid: @left_uuid]],
          relationships: []
        )

      assert length(result.graph.nodes) == length(left.graph.nodes)
    end
  end

  describe "Artefact.graft/3 — relationship dedupe" do
    @uuid_a "019d0000-0000-7000-8000-0000000000b1"
    @uuid_b "019d0000-0000-7000-8000-0000000000b2"

    test "args relationship matching an existing left relationship is deduped (left properties win)" do
      left =
        Artefact.new(
          title: "Pair",
          nodes: [
            a: [labels: [], properties: %{}, uuid: @uuid_a],
            b: [labels: [], properties: %{}, uuid: @uuid_b]
          ],
          relationships: [[from: :a, type: "KNOWS", to: :b, properties: %{"since" => "2020"}]]
        )

      result =
        Artefact.graft(left,
          nodes: [
            a: [uuid: @uuid_a],
            b: [uuid: @uuid_b]
          ],
          relationships: [
            [
              from: :a,
              type: "KNOWS",
              to: :b,
              properties: %{"since" => "2099", "source" => "graft"}
            ]
          ]
        )

      assert length(result.graph.relationships) == 1
      [rel] = result.graph.relationships
      assert rel.properties["since"] == "2020"
      assert rel.properties["source"] == "graft"
    end
  end

  describe "Artefact.graft/3 — guards" do
    alias Artefact.Test.Fixtures.OurShells

    test "raises when an args node is missing :uuid" do
      left = OurShells.our_shells()

      assert_raise ArgumentError, ~r/graft: node :without_uuid is missing required :uuid/, fn ->
        Artefact.graft(left,
          nodes: [without_uuid: [labels: ["Knowing"]]],
          relationships: []
        )
      end
    end

    test "raises when args has duplicate node keys" do
      left = OurShells.our_shells()

      assert_raise ArgumentError, ~r/graft: duplicate node keys/, fn ->
        Artefact.graft(left,
          nodes: [
            {:dup, [uuid: "019d0000-0000-7000-8000-000000000c01"]},
            {:dup, [uuid: "019d0000-0000-7000-8000-000000000c02"]}
          ],
          relationships: []
        )
      end
    end

    test "raises when a relationship references a key not in args.nodes" do
      left = OurShells.our_shells()

      assert_raise ArgumentError,
                   ~r/graft: relationship references unknown node key :ghost/,
                   fn ->
                     Artefact.graft(left,
                       nodes: [{:me, [uuid: OurShells.me_uuid()]}],
                       relationships: [[from: :me, type: "KNOWING", to: :ghost]]
                     )
                   end
    end
  end
end
