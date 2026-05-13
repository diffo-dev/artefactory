<!--
SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
SPDX-License-Identifier: MIT
-->

# Artefact

[![Module Version](https://img.shields.io/hexpm/v/artefact)](https://hex.pm/packages/artefact)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen)](https://hexdocs.pm/artefact/)
[![License](https://img.shields.io/hexpm/l/artefact)](https://github.com/diffo-dev/artefactory/blob/dev/LICENSES/MIT.txt)
[![REUSE status](https://api.reuse.software/badge/github.com/diffo-dev/artefactory)](https://api.reuse.software/info/github.com/diffo-dev/artefactory)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/diffo-dev/artefactory)
[![Run in Livebook](https://livebook.dev/badge/v1/blue.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2Fdiffo-dev%2Fartefactory%2Fblob%2Fdev%2Fartefact_kino%2Fartefact_kino.livemd)

Artefacts (note the Australian spelling) are made objects. In an Artefactory they represent a fragment of knowledge — typically abstract, insightful, contextual.

An `%Artefact{}` is a small, self-contained property graph: nodes with labels and properties, connected by typed directed relationships. The canonical form is the Elixir struct. Arrows JSON and Cypher are derived representations — JSON for interchange and visual editing with [Arrows.app](https://arrows.app), Cypher for persistence in Neo4j.

As we yarn we naturally exchange and create Artefacts.

## Installation

The preferred way to install Artefact is via Igniter:

```bash
mix igniter.install artefact
```

Or add the dependency manually:

```elixir
def deps do
  [
    {:artefact, "~> 0.3"}
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

us_two = Artefact.new!(
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

## Combining and Extending Artefacts

Operations come in two variants: `op/n` returns `{:ok, %Artefact{}} | {:error, error}`; `op!/n` returns the artefact directly or raises the error struct. Use `!` in pipelines or when you'd rather let exceptions propagate; use the non-`!` form when you want to handle errors explicitly.

```elixir
# compose — disjoint union, nodes remain independent
{:ok, combined} = Artefact.compose(a1, a2)

# combine — pipeline-friendly union; bindings auto-found via shared uuid.
# Returns {:error, %Artefact.Error.Operation{tag: :no_shared_bindings}}
# if heart and other share no node uuids.
result =
  my_knowing
  |> Artefact.combine!(my_valuing)
  |> Artefact.combine!(my_being)
  |> Artefact.combine!(my_doing, title: "MeMind", description: "Mind of Me")

# harmonise — union via declared bindings.
# Lower uuid wins identity, labels are unioned, left wins on property conflict.
{:ok, bindings} = Artefact.Binding.find(a1, a2)
{:ok, harmonised} = Artefact.harmonise(a1, a2, bindings)

# graft — extend an existing artefact inline with new nodes and
# relationships. args matches Artefact.new's inline shape, but every
# node MUST carry :uuid (no auto-find — uuid is the binding).
# Nodes whose uuid lives in left bind to it (labels unioned, properties
# merged left-wins). Nodes with new uuids are added.
result =
  me_mind
  |> Artefact.graft!(
       [
         nodes: [
           {:me,          [uuid: "019ddb71-c70b-7b3e-83b1-58f4d0be2852"]},
           {:stewardship, [labels: ["Knowing"],
                           uuid: "019df318-698c-77d6-bc7b-ea041a019a7f"]}
         ],
         relationships: [[from: :me, type: "KNOWING", to: :stewardship]]
       ],
       title: "MeMind + Stewardship",
       description: "Stewardship grafted onto MeMind."
     )
```

Errors are `Splode`-typed structs — pattern-match on `Artefact.Error.Invalid` (validation-rule violations) or `Artefact.Error.Operation` (op-specific outcomes) to handle each case. See [`MIGRATION.md`](MIGRATION.md) for the full error shape table.

Provenance is recorded automatically — every artefact carries metadata describing how it was created, including the calling module and, for derived artefacts, a summary of each source.

## Validation

```elixir
Artefact.is_artefact?(value)         # boolean
Artefact.is_valid?(artefact)         # boolean
Artefact.validate(artefact)          # :ok | {:error, %Artefact.Error.Invalid{reasons: [...]}}
Artefact.validate!(artefact)         # :ok | raises Artefact.Error.Invalid
```

Every operation validates its inputs and the produced artefact, so corruption fails at the call site rather than steps downstream.

## Importing from Arrows JSON

```elixir
artefact = Artefact.Arrows.from_json!(json, diagram: "path/to/source.json")
```

## Acknowledgements

Artefactory is inspired by Indigenous Systems Thinking and the profound wisdom presented by Tyson Yunkaporta in [Sand Talk](https://www.amazon.com.au/Sand-Talk-Indigenous-Thinking-World/dp/1922790516), grounded in countless years of sustainable, harmonious living.

## License

MIT — see [LICENSES/MIT.txt](LICENSES/MIT.txt).
