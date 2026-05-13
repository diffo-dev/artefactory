<!--
SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
SPDX-License-Identifier: MIT
-->

# Changelog

## 0.3.0 — 2026-05-13

### Side-by-side layout options

- `description_lines:` option — reserves a fixed-height description area of exactly N lines. Content is clipped if longer; space is held empty if there is no description. Ensures two side-by-side panels share the same header height regardless of description length. Closes [#39](https://github.com/diffo-dev/artefactory/issues/39).
- `panel_height_px:` option — fixes the total widget height. The header takes what it needs; the graph row fills the rest. Prevents page reflow as artefacts grow across panels in a progressive-reveal livebook.

### Bug fix

- Node colours are now derived from a deterministic string hash of the label name rather than the label's position in the sorted list. The same label string always produces the same colour regardless of how many other labels exist in the artefact — a node can be followed by colour across panels without thinking about it. Closes [#39](https://github.com/diffo-dev/artefactory/issues/39).

### Dependencies

- Bumps `artefact` requirement to `~> 0.3.0`.

## 0.2.0 — 2026-05-05

- Bumps `artefact` requirement to `~> 0.2.0`. `ArtefactKino.new/1,2` continues to validate its input via `Artefact.validate!/1`, which now raises `Artefact.Error.Invalid` instead of `ArgumentError` when an invalid artefact is passed in. Behaviour is otherwise unchanged.

## 0.1.5 — 2026-05-05

- `ArtefactKino.new/1,2` now calls `Artefact.validate!/1` on its input — a hand-built `%Artefact{}` with malformed fields (non-list labels, missing uuid, dangling relationship endpoint, etc.) raises `ArgumentError` with structured reasons instead of a cryptic render-time error. Closes [#28]. Bumps `artefact` requirement to `~> 0.1.5` for the new validation API.

[#28]: https://github.com/diffo-dev/artefactory/issues/28

## 0.1.4 — 2026-05-05

- Inspector panel collapsible (matching the Export panel); both default collapsed to give the graph more room on bigger artefacts; selecting a node or relationship in the graph auto-expands the Inspector. Bumps `artefact` requirement to `~> 0.1.4` for convenience.

## 0.1.3 — 2026-04-30

- Compatible with `artefact ~> 0.1.3`
- MERMAID button on the export panel — pasteable Mermaid `graph` source alongside CREATE / MERGE / JSON
- Header bar renders `artefact.description` under `artefact.title` when set; multi-line descriptions preserve their newlines (`white-space: pre-line`)
- `description` row added to the Artefact tab in the Elixir inspector, alongside `title`, `base_label` and `metadata`

## 0.1.2 — 2026-04-21

- Compatible with `artefact ~> 0.1.2`
- No functional changes

## 0.1.1 — 2026-04-01

- `ArtefactKino.new/1`, `ArtefactKino.new/2` — Livebook Kino widget for `%Artefact{}`
- Interactive vis-network graph (left panel) with Arrows coordinates preserved
- Cypher fragment display with copy button (right panel)
- Sand Talk aesthetic — dark sand background, ochre nodes and edges
- `:merge` view option showing the harmonised graph
