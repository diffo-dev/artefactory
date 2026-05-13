<!--
SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
SPDX-License-Identifier: MIT
-->

# Rules for working with Artefact

## What Artefact is

Artefact is an Elixir library for building, combining, and persisting knowledge graph fragments. An `%Artefact{}` is a named, typed property graph — a small, self-contained piece of knowledge. It is not an application data model, a database schema, or a general-purpose graph library.

The intended use is knowledge memorialisation: capturing shared understanding between people, agents, or systems in a form that can be combined, versioned, and persisted.

## require Artefact

`Artefact.new/1`, `Artefact.new!/1`, `Artefact.combine!/2`, and all other operations are **macros**. Always `require Artefact` before calling them:

```elixir
require Artefact

artefact = Artefact.new!(
  title: "Us Two",
  nodes: [
    matt:   [labels: ["Agent"], properties: %{"name" => "Matt"}],
    claude: [labels: ["Agent"], properties: %{"name" => "Claude"}]
  ],
  relationships: [
    [from: :matt, type: "US_TWO", to: :claude]
  ]
)
```

Without `require`, you will get a compile-time error about undefined functions. This is the most common source of confusion when first using Artefact.

## UUID is identity

Every node carries a UUIDv7 `uuid`. This is its identity — the same UUID in two artefacts means the same node. `combine!/2` uses UUID equality to find shared nodes and merge them.

**Never change a UUID once it has been used in a persisted or shared artefact.** If you assign a UUID explicitly at construction time, keep it. If you do not assign one, Artefact generates a time-ordered UUIDv7 automatically.

For importing from external sources — Mermaid diagrams, Cypher files, JSON — derive UUIDs deterministically from a stable identifier using `Artefact.UUID.from_name/1`:

```elixir
uuid = Artefact.UUID.from_name("std_ulogic")
# same name always → same UUID, valid UUIDv7
```

This means the same external id imported twice always produces the same node, and `combine!/2` will bind correctly across imports.

## Operations at a glance

| Operation | What it does | Key constraint |
|---|---|---|
| `new!/1` | Build a fresh artefact | Macro — `require Artefact` |
| `combine!/2` | Union two artefacts via shared UUIDs | Different `base_label` required |
| `harmonise!/3` | Union via explicit bindings | Different `base_label` required |
| `compose!/2` | Concatenate — nodes stay disjoint | No shared UUIDs expected |
| `graft!/2` | Extend an existing artefact inline | Every new node must carry `:uuid` |

Each operation has a `!/n` (raises) and `/n` (returns `{:ok, _} | {:error, _}`) variant.

## combine!/2 requires different base_label values

`combine!/2` finds shared nodes automatically by UUID. It requires the two artefacts to have **different** `base_label` values — this distinguishes "what I know" from "what I am adding":

```elixir
# Raises Artefact.Error.Operation with same_base_label
Artefact.combine!(a, b)  # both default base_label to calling module name

# Correct
a = Artefact.new!(base_label: "Signals", ...)
b = Artefact.new!(base_label: "Values", ...)
combined = Artefact.combine!(a, b)
```

When no `base_label` is set explicitly, it defaults to the short name of the calling module — so two artefacts built in the same module will clash.

## Mermaid import and export

`Artefact.Mermaid.export/2` converts an artefact to a Mermaid `graph` source string. `Artefact.Mermaid.from_mmd!/2` parses it back. The round-trip is lossless for: title, description, node names, labels, and relationship types.

### UUID identity anchors on the Mermaid node id

When importing with `from_mmd!/2`, the UUID of each node is derived from its **Mermaid node id** — the `\w+` identifier (e.g. `val_0`, `std_ulogic`) — not the display label inside the shape. Keep node ids stable across diagram versions; changing an id changes the UUID and breaks bindings.

```mermaid
graph LR
  std_ulogic(("std_ulogic<br/>Signal"))  ← id is std_ulogic, UUID derived from "std_ulogic"
```

### Declare nodes separately from edges for label recovery

When a node's shape is declared inline on an edge line, the label is not captured:

```
val_0["VALUE · 0"] -->|ENUMERATES| value  ← label "VALUE" is lost
```

Use a separate declaration line:

```
graph LR
  val_0["VALUE · 0"]
  val_0 -->|ENUMERATES| value
```

The export format produced by `export/2` always uses separate lines, so this only applies to hand-authored Mermaid.

### Node label conventions in Mermaid

Two formats are recognised inside node shapes:

- `name<br/>Label1 Label2` — our export format
- `LABEL · name` — yarn convention (one label and name separated by ` · `)

### Node descriptions via click tooltips

Node `description` properties are exported as `click id "text"` lines and recovered on import. They are visible as hover tooltips in Mermaid renderers.

## %Artefact{} struct shape

```elixir
%Artefact{
  uuid: "019e...",          # UUIDv7 — the artefact's own identity
  title: "My Artefact",    # optional
  description: "...",      # optional
  base_label: "Concept",   # optional — collapsed into per-node labels at export
  graph: %Artefact.Graph{
    nodes: [
      %Artefact.Node{
        id: "n0",           # internal sequential id — do not rely on this across artefacts
        uuid: "019e...",    # UUIDv7 — stable identity
        labels: ["Concept", "Thing"],
        properties: %{"name" => "Alpha", "description" => "..."}
      }
    ],
    relationships: [
      %Artefact.Relationship{
        id: "r0",           # internal sequential id
        type: "RELATES",    # MACRO_CASE convention
        from_id: "n0",
        to_id: "n1",
        properties: %{}
      }
    ]
  }
}
```

Node `id` values (`n0`, `r0`) are internal and sequential within one artefact. Use `uuid` for stable cross-artefact identity.
