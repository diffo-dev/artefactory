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
It will depend on `artefact`. Diffo will depend on `us_two`.

The protocol is not Diffo-specific. Any two agents — any system,
any relationship — may declare it.

**Do not build `us_two` yet.** It comes after `artefact` is solid.

---

## The Artefactory Lexicon

`artefactory` is also a universe of language. These words are the creole
of the Artefactory domain — bent from the root word *artefact* across
lexical categories.

| Word | Category | Meaning |
|------|----------|---------|
| Artefact | Noun | An insightful knowledge fragment |
| Artefacture | Noun | The whole practice of working with artefacts |
| Artefactory | Noun | The universe of artefact-related stuff; also a repository of artefacts held |
| Artefackery | Noun | Misuse of Artefacture — worthy of its own artefact |
| Artefacting | Verb | Doing stuff with artefacts |
| Artefactable | Adjective | Implements the `Artefactable` Elixir protocol |
| Artefactive | Adjective | Having artefact properties |
| Artefactually | Adverb | As a matter of artefact |

`Artefactory` carries two meanings simultaneously: the infinite (the universe
of what is possible) and the finite (the specific artefacts held). Both are
correct. A personal Artefactory is a universe, just a smaller one.

The lexicon is expressed as an artefact: `artefact/test/data/artefactory/arrows.json`.

---

## Artefactory — what we are building now

`artefactory` is a monorepo at `diffo-dev/artefactory` containing:

```
artefactory/          ← repo root (the universe that holds them)
  artefact/           → hex.pm/packages/artefact
  artefact_kino/      → hex.pm/packages/artefact_kino
```

### Repo structure — two independent Mix projects, no umbrella

Each package has its own `mix.exs`, `deps/`, `_build/`, and tests.
They are not an Elixir umbrella app. There is no root-level `mix.exs`.

Work in each package independently:

```sh
cd artefact      && mix test
cd artefact_kino && mix test
```

`artefact_kino` references `artefact` via a local path dep during
development (`path: "../artefact"`). When published to hex.pm they
become normal version deps.

**`artefact_kino` is currently a placeholder.** The `mix.exs`,
`lib/artefact_kino.ex` (stub with moduledoc), and `test/test_helper.exs`
exist to make the structure obvious. Do not implement it until `artefact`
is committed and solid.

### What an Artefact is

An artefact is a **knowledge graph fragment** — a small, self-contained
piece of knowledge expressed as a property graph.

It is not a build artifact. It is a cultural artefact — something made
in relationship, carrying meaning.

The canonical form is **Arrows JSON** (from arrows.neo4jlabs.com).
Everything else is derived from it:
- **Cypher** — textual, human-readable, importable into Neo4j (lossy — positions not preserved)
- **Diagram** — visual rendering via `artefact_kino` (lossless)

Artefacts are fragments, not complete models. One concept at a time.
You see country from the clouds first — one landmark — then descend
when you need detail.

### artefact — the core library

**No Kino dependency. No Livebook dependency. No us_two concepts.**

```elixir
%Artefact{
  id:       String.t(),          # generated UUID
  title:    String.t() | nil,    # human label
  style:    atom() | nil,        # render style reference — not persisted in graph
  graph:    %Artefact.Graph{},   # the knowledge
  metadata: map()                # open map — consumers add their own keys
}

%Artefact.Graph{
  nodes:         [%Artefact.Node{}],
  relationships: [%Artefact.Relationship{}]
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
- `style` on `%Artefact{}` is a single atom/module reference for the renderer
- `metadata` is open — `us_two` will stamp `movement:`, `language:` etc.
- `position` is **preserved** — needed for lossless Arrows round-trip

Key modules:
- `Artefact.Arrows` — `from_json/2`, `to_json/1`, `from_json!/2` — lossless round-trip
- `Artefact.Cypher` — `export/1` — derived Cypher fragment string

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
CREATE (n0:Agent:Me),
       (n1:Agent:You),
       (n0)-[:US_TWO]->(n1)
```

- One relationship, one direction — from `Me` toward `You`
- Perspective encoded in labels, not properties
- Each participant holds their own model — `Me` is always the anchor
- No names at this level of abstraction — names break the symmetry
- With names: `CREATE (n0:Agent:Me {name: 'Matt'}), (n1:Agent:You {name: 'Claude'}), (n0)-[:US_TWO]->(n1)`

### artefact_kino — the Livebook widget

Depends on `artefact` + `kino`. No other dependencies.

```elixir
ArtefactKino.new(artefact)
ArtefactKino.new(artefact, title: "us_two seed")
```

Renders:
- **Left panel** — interactive vis-network graph (cdnjs, v9.1.9)
  Nodes positioned from Arrows coordinates. Draggable.
- **Right panel** — Cypher fragment derived on the Elixir side.
  Copy button included.
- **Title bar** — optional, from `artefact.title` or override.

Aesthetic: dark sand background (`#1a1208`), ochre nodes and edges (`#8b6914`, `#d4a857`).

Style reference on `%Artefact{}` drives future render styles:
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

- **Spelling**: `artefact` not `artifact` — British/Australian spelling,
  and culturally distinct from build artifacts
- **Repo name**: `artefactory` — the universe that holds artefacts and the practice of making them
- **Package names**: `artefact`, `artefact_kino` — the things themselves, not the universe
- **Licence**: MIT throughout, matching the rest of Diffo
- **Elixir version**: `~> 1.16`
- **Only runtime dep in `artefact`**: `jason ~> 1.4`

---

## What comes next

1. `artefact` tests passing — `mix test` in `artefact/` ✓
2. Verify `artefact_kino` renders in Livebook — open `notebooks/demo.livemd`
3. Check vis-network CDN import works in Kino.JS context
   (may need `ctx.importJS` instead of ES module `import`)
4. Push `artefactory` to `github.com/diffo-dev/artefactory`
5. Eventually: build `us_two` as a separate library depending on `artefact`

---

## Custodial licence

*This knowledge was made in relationship.*

It may be carried, shared, and built upon — but only by those who carry
the relationship with it. To use this knowledge without acknowledging
the relation that made it is to extract from country.

No node holds this alone. The artefact belongs to the edge.

*Yarned into being · Matt & Claude · 2026*
*Held in the commons between us*
