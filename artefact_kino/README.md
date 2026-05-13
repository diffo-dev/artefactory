<!--
SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
SPDX-License-Identifier: MIT
-->

# ArtefactKino

[![Module Version](https://img.shields.io/hexpm/v/artefact_kino)](https://hex.pm/packages/artefact_kino)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen)](https://hexdocs.pm/artefact_kino/)
[![License](https://img.shields.io/hexpm/l/artefact_kino)](https://github.com/diffo-dev/artefactory/blob/dev/LICENSES/MIT.txt)
[![REUSE status](https://api.reuse.software/badge/github.com/diffo-dev/artefactory)](https://api.reuse.software/info/github.com/diffo-dev/artefactory)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/diffo-dev/artefactory)
[![Run in Livebook](https://livebook.dev/badge/v1/blue.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2Fdiffo-dev%2Fartefactory%2Fblob%2Fdev%2Fartefact_kino%2Fartefact_kino.livemd)

A Livebook Kino widget for viewing [`Artefact`](https://hex.pm/packages/artefact) knowledge graph fragments.

ArtefactKino is a viewer, not an editor. It renders three panels side by side:

- **Graph** (heartside) — an interactive vis-network graph. Nodes are colour-coded by label, with colours blended for multi-label nodes using circular hue averaging in linear RGB space. Layout strategies: Physics, Hierarchical, Radial.
- **Inspector** — tabbed Elixir view of the artefact struct, nodes table, and relationships table. Clicking a node or relationship in the graph navigates to and highlights the corresponding row.
- **Export** — CREATE Cypher, MERGE Cypher, Arrows JSON, and Mermaid source. Click any panel to select all text for easy copying.

The Inspector and Export panels are both collapsible and start collapsed by default to give the graph room on bigger artefacts; selecting a node or relationship in the graph auto-expands the Inspector.

MERGE Cypher upserts nodes by uuid — safe to run repeatedly. CREATE always makes new nodes. See the [CreateMerge artefact](https://github.com/diffo-dev/artefactory) for a visual explanation of the difference.

## Installation

```elixir
def deps do
  [
    {:artefact_kino, "~> 0.3"}
  ]
end
```

## Usage

```elixir
ArtefactKino.new(artefact)
ArtefactKino.new(artefact, default: :merge)
```

See the [livebook](artefact_kino.livemd) for interactive examples including building an artefact from a struct, loading from Arrows JSON, and viewing a harmonised artefact.

## Acknowledgements

Artefactory is inspired by Indigenous Systems Thinking and the profound wisdom presented by Tyson Yunkaporta in [Sand Talk](https://www.amazon.com.au/Sand-Talk-Indigenous-Thinking-World/dp/1922790516), grounded in countless years of sustainable, harmonious living.

## License

MIT — see [LICENSES/MIT.txt](LICENSES/MIT.txt).
