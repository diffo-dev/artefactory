<!--
SPDX-FileCopyrightText: 2026 diffo-dev
SPDX-License-Identifier: MIT
-->

# Artefactory

[![REUSE status](https://api.reuse.software/badge/github.com/diffo-dev/artefactory)](https://api.reuse.software/info/github.com/diffo-dev/artefactory)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/diffo-dev/artefactory)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSES/MIT.txt)

An Artefactory is a universe of knowledge graph fragments — Artefacts.

Artefacts (note the Australian spelling) are made objects. In an Artefactory they represent a fragment of knowledge: typically abstract, insightful, contextual. Artefacts may be generated, exchanged and combined, but our interpretation of them is always our own.

As we yarn we naturally exchange and create Artefacts.

This monorepo contains two Elixir packages:

---

## [Artefact](artefact/README.md)

[![Hex.pm](https://img.shields.io/hexpm/v/artefact.svg)](https://hex.pm/packages/artefact)
[![HexDocs](https://img.shields.io/badge/hexdocs-artefact-purple)](https://hexdocs.pm/artefact)

The core library. An `%Artefact{}` is a small, self-contained property graph — nodes with labels and properties, connected by typed directed relationships. Build artefacts as Elixir structs, combine them with `compose` and `harmonise`, export to Cypher for Neo4j or Arrows JSON for visual editing.

```elixir
{:artefact, "~> 0.1"}
```

---

## [ArtefactKino](artefact_kino/README.md)

[![Hex.pm](https://img.shields.io/hexpm/v/artefact_kino.svg)](https://hex.pm/packages/artefact_kino)
[![HexDocs](https://img.shields.io/badge/hexdocs-artefact__kino-purple)](https://hexdocs.pm/artefact_kino)
[![Run in Livebook](https://livebook.dev/badge/v1/blue.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2Fdiffo-dev%2Fartefactory%2Fblob%2Fdev%2Fartefact_kino%2Fartefact_kino.livemd)

A Livebook Kino widget for viewing Artefacts. Three panels: interactive graph (heartside), tabbed Elixir inspector, and CREATE/MERGE/JSON export with click-to-copy.

```elixir
{:artefact_kino, "~> 0.1"}
```

---

## Acknowledgements

Artefactory is new, but the ideas are not. At [diffo-dev](https://github.com/diffo-dev) we are on a journey inspired by Indigenous Systems Thinking and offer our respect and gratitude for the profound wisdom presented by Tyson Yunkaporta in [Sand Talk](https://www.amazon.com.au/Sand-Talk-Indigenous-Thinking-World/dp/1922790516), grounded in countless years of sustainable, harmonious living.
