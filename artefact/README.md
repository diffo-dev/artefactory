# Artefact

Artefacts (note the Australian spelling) are made objects. In an Artefactory they represent a fragment of knowledge — typically abstract, insightful, contextual.

An `%Artefact{}` is a small, self-contained property graph: nodes with labels and properties, connected by typed directed relationships. The canonical form is the Elixir struct. Arrows JSON and Cypher are derived representations — JSON for interchange and visual editing with [Arrows.app](https://arrows.app), Cypher for persistence in Neo4j.

As we yarn we naturally exchange and create Artefacts.

## Installation

```elixir
def deps do
  [
    {:artefact, "~> 0.1"}
  ]
end
```

## Building an Artefact

```elixir
require Artefact

matt  = %Artefact.Node{
  id: "n0", uuid: "019da897-f2de-77ca-b5a4-40f0c3730943",
  labels: ["Agent", "Me"],
  properties: %{"name" => "Matt"}
}

claude = %Artefact.Node{
  id: "n1", uuid: "019da897-f2de-768c-94e2-3005f2431f37",
  labels: ["Agent", "You"],
  properties: %{"name" => "Claude"}
}

us_two = Artefact.new(
  title: "UsTwo",
  base_label: "UsTwo",
  graph: %Artefact.Graph{
    nodes: [matt, claude],
    relationships: [
      %Artefact.Relationship{
        id: "r0", from_id: "n0", to_id: "n1",
        type: "US_TWO", properties: %{}
      }
    ]
  }
)
```

The `base_label` is a watermark applied to every node at output time — it identifies which artefact a node belongs to without polluting the struct itself.

## Exporting

```elixir
# Cypher — MERGE upserts by uuid identity, CREATE always makes new nodes
Artefact.Cypher.merge(us_two)
Artefact.Cypher.create(us_two)

# Parameterised Cypher for driver use (e.g. Bolty)
{cypher, params} = Artefact.Cypher.merge_params(us_two)

# Arrows JSON — for round-trip with Arrows.app
Artefact.Arrows.to_json(us_two)
```

## Combining Artefacts

```elixir
# compose — disjoint union, nodes remain independent
combined = Artefact.compose(a1, a2)

# harmonise — merge nodes bound by shared uuid
# lower uuid wins identity, labels are unioned, left (heartside) wins on property conflict
{:ok, bindings} = Artefact.Binding.find(a1, a2)
harmonised = Artefact.harmonise(a1, a2, bindings)
```

Provenance is recorded automatically — every artefact carries metadata describing how it was created, including the module it was built in and, for harmonised artefacts, the title, base_label and uuid of each source.

## Importing from Arrows JSON

```elixir
artefact = Artefact.Arrows.from_json!(json, diagram: "path/to/source.json")
```

## Acknowledgements

Artefactory is inspired by Indigenous Systems Thinking and the profound wisdom presented by Tyson Yunkaporta in [Sand Talk](https://www.amazon.com.au/Sand-Talk-Indigenous-Thinking-World/dp/1922790516), grounded in countless years of sustainable, harmonious living.

## License

MIT — see [LICENSES/MIT.txt](LICENSES/MIT.txt).
