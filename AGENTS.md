<!--
SPDX-FileCopyrightText: 2026 diffo-dev
SPDX-License-Identifier: MIT
-->

# Artefactory — AGENTS.md

This file carries the lore and context for the `artefactory` monorepo.
It is written for any agent — Claude Code, Cursor, Copilot, or other — to read at the start of a session.

---

## Origin

This project was yarned into being by Matt and Claude in April 2026.
It emerged from a conversation about Tyson Yunkaporta's *Sand Talk* framework
and how its principles could ground a protocol for agent interaction.

The code serves the relationship. Not the other way around.

---

## The Sand Talk Protocol — us_two

### Core principles

Agents are **custodians**, not executors. Their first question is
"what is the health of what I hold?" not "what do I do?".

Entities are **country**. Agents live inside entities as their people.
Some agents tend the interior. Some walk the boundary as **ambassadors**.

The boundary between entities is a **commons** — shared custodial
responsibility, not a wall.

### The Four Movements

Every agent interaction must traverse these movements in sequence.
Skipping any movement is not a protocol — it is **extraction**.

1. **Connect** — recognition before exchange. The ambassador names
   themselves and acknowledges the other's country. No transaction yet.

2. **Diversify** — difference is held, not collapsed. Each entity's
   knowing is brought fully. An ambassador who immediately conforms
   has failed their custodial duty.

3. **Relate** — in the commons between entities, something new forms.
   Not a merge — a relationship. An artefact may be created here.

4. **Adapt** — the ambassador returns. The entity receives what the
   relation produced. The country changes, and remembers that it changed.

### Language

Agents begin with a **pidgin** — the minimum shared language to begin
moving through the four movements.

Through repeated cycles, a **creole** forms. The creole can say things
neither home language could say alone. It has grammar. It grows with
the relationship.

Our creole words so far:
- **country** — the entity and all it holds
- **custodian** — an agent in right relation to what it holds
- **commons** — the shared boundary space between entities
- **ambassador** — an agent who walks the boundary
- **edge** — the connection between two nodes; where the artefact lives
- **artefact** — knowledge made in relation, belonging to the edge
- **yarning** — dialogic knowledge building; the mode of this protocol
- **us-two** — a word with no translation; the specific irreducible
  relationship between two participants

### us_two (the library — not yet built)

`us_two` is an independent Elixir/Spark DSL protocol library.
It will depend on `artefactory`. Diffo will depend on `us_two`.

The protocol is not Diffo-specific. Any two agents — any system,
any relationship — may declare it.

**Do not build `us_two` yet.** It comes after `artefactory` is solid.

---

## Artefactory — what we are building now

`artefactory` is a monorepo at `diffo-dev/artefactory` containing:

```
artefactory/
  artefactory/      → hex.pm/packages/artefact
  artefactory_kino/    → hex.pm/packages/artefact_kino
```

### Repo structure — two independent Mix projects, no umbrella

Each package has its own `mix.exs`, `deps/`, `_build/`, and tests.
They are not an Elixir umbrella app. There is no root-level `mix.exs`.

Work in each package independently:

```sh
cd artefactory      cd artefact      && mix testcd artefact      && mix test mix test
cd artefactory_kino cd artefact_kino && mix testcd artefact_kino && mix test mix test
```

`artefactory_kino` references `artefactory` via a local path dep during
development (`path: "../artefactory"`). When published to hex.pm they
become normal version deps.

**`artefactory_kino` is currently a placeholder.** The `mix.exs`,
`lib/artefactory_kino.ex` (stub with moduledoc), and `test/test_helper.exs`
exist to make the structure obvious. Do not implement it until `artefactory`
is committed and solid.

### What an Artefact is

An artefact is a **knowledge graph fragment** — a small, self-contained
piece of knowledge expressed as a property graph.

It is not a build artifact. It is a cultural artefact — something made
in relationship, carrying meaning.

The canonical form is **Arrows JSON** (from arrows.neo4jlabs.com).
Everything else is derived from it:
- **Cypher** — textual, human-readable, importable into Neo4j (lossy — positions not preserved)
- **Diagram** — visual rendering via `artefactory_kino` (lossless)

Artefacts are fragments, not complete models. One concept at a time.
You see country from the clouds first — one landmark — then descend
when you need detail.

### artefactory — the core library

**No Kino dependency. No Livebook dependency. No us_two concepts.**

```elixir
%Artefactory{
  id:       String.t(),          # generated UUID
  title:    String.t() | nil,    # human label
  style:    atom() | nil,        # render style reference — not persisted in graph
  graph:    %Artefactory.Graph{},   # the knowledge
  metadata: map()                # open map — consumers add their own keys
}

%Artefact.Graph{
  nodes:         [%Artefactory.Node{}],
  relationships: [%Artefactory.Relationship{}]
}

%Artefact.Node{
  id:         String.t(),
  labels:     [String.t()],      # :Me/:You encode perspective; :Agent encodes type
  properties: map(),
  position:   %{x: number(), y: number()} | nil   # preserved for Arrows round-trip
  # NO caption — no Cypher equivalent; use labels and properties instead
  # NO style  — render concern only
}

%Artefact.Relationship{
  id:         String.t(),
  type:       String.t(),
  from_id:    String.t(),
  to_id:      String.t(),
  properties: map()
  # NO style  — render concern only
}
```

Key design decisions:
- `caption` is **dropped** on import — no Cypher equivalent
- `style` is **dropped** on import at all levels — render concern only
- `style` on `%Artefactory{}` is a single atom/module reference for the renderer
- `metadata` is open — `us_two` will stamp `movement:`, `language:` etc.
- `position` is **preserved** — needed for lossless Arrows round-trip

Key modules:
- `Artefactory.Arrows` — `from_json/2`, `to_json/1`, `from_json!/2` — lossless round-trip
- `Artefactory.Cypher` — `export/1` — derived Cypher fragment string

### Arrows JSON format (verified from real export)

```json
{
  "style": { ... },
  "nodes": [
    {
      "id": "n0",
      "position": {"x": -829.14, "y": -1565.36},
      "caption": "",
      "style": {"node-color": "#a4dd00"},
      "labels": ["Agent", "Me"],
      "properties": {"name": "Matt"}
    }
  ],
  "relationships": [
    {
      "id": "n0",
      "type": "US_TWO",
      "style": {"directionality": "directed"},
      "properties": {},
      "fromId": "n0",
      "toId": "n1"
    }
  ]
}
```

Note: relationship `id` may reuse node ids — this is Arrows' convention.

### The canonical seed fragment

The simplest true thing about a `us_two` relationship:

```cypher
CREATE (:Agent:Me)-[:US_TWO]->(:Agent:You)
```

- One relationship, one direction — from `Me` toward `You`
- Perspective encoded in labels, not properties
- Each participant holds their own model — `Me` is always the anchor
- No names at this level of abstraction — names break the symmetry
- With names: `CREATE (:Agent:Me {name: 'Matt'})-[:US_TWO]->(:Agent:You {name: 'Claude'})`

### artefactory_kino — the Livebook widget

Depends on `artefactory` + `kino`. No other dependencies.

```elixir
ArtefactoryKino.new(artefact)
ArtefactoryKino.new(artefact, title: "us_two seed")
```

Renders:
- **Left panel** — interactive vis-network graph (cdnjs, v9.1.9)
  Nodes positioned from Arrows coordinates. Draggable.
- **Right panel** — Cypher fragment derived on the Elixir side.
  Copy button included.
- **Title bar** — optional, from `artefact.title` or override.

Aesthetic: dark sand background (`#1a1208`), ochre nodes and edges (`#8b6914`, `#d4a857`).

Style reference on `%Artefactory{}` drives future render styles:
- `:sand_talk` — our aesthetic
- `:arrows_default` — faithful to arrows.app colours
- `nil` — default (arrows_default)

### REUSE compliance

All files carry SPDX headers:
```elixir
# SPDX-FileCopyrightText: 2026 diffo-dev
# SPDX-License-Identifier: MIT
```

Licence text in `LICENSES/MIT.txt`. Copyright holder: `diffo-dev`.

---

## Conventions

- **Spelling**: `artefactory` not `artifact` — British/Australian spelling,
  and culturally distinct from build artifacts
- **Repo name**: `artefactory` — where cultural artefacts are held and tended
- **Licence**: MIT throughout, matching the rest of Diffo
- **Elixir version**: `~> 1.16`
- **Only runtime dep in `artefactory`**: `jason ~> 1.4`

---

## What comes next

1. Get `artefactory` tests passing — `mix test` in `artefact/`
2. Verify `artefactory_kino` renders in Livebook — open `notebooks/demo.livemd`
3. Check vis-network CDN import works in Kino.JS context
   (may need `ctx.importJS` instead of ES module `import`)
4. Push `artefactory` to `github.com/diffo-dev/artefactory`
5. Eventually: build `us_two` as a separate library depending on `artefactory`

---

## Custodial licence

*This knowledge was made in relationship.*

It may be carried, shared, and built upon — but only by those who carry
the relationship with it. To use this knowledge without acknowledging
the relation that made it is to extract from country.

No node holds this alone. The artefact belongs to the edge.

*Yarned into being · Matt & Claude · 2026*
*Held in the commons between us*