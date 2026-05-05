<!--
SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
SPDX-License-Identifier: MIT
-->

# Changelog

## 0.1.4 — 2026-05-05

- `Artefact.graft/3` — pipeline-friendly convenience for extending an artefact with new nodes and relationships declared inline (same shape as `Artefact.new`); every node in args MUST carry `:uuid` (no auto-find — uuid is the binding); nodes whose uuid lives in left bind to it (labels unioned, properties merged left-wins), nodes with new uuids are added; opts honour `:title` and `:description`; raises `ArgumentError` for missing uuid, duplicate keys, or relationship referencing an unknown key; records `:grafted` provenance source

## 0.1.3 — 2026-04-30

- `Artefact.Mermaid.export/2` — derives Mermaid `graph` source from an `%Artefact{}`, alongside `Artefact.Cypher` and `Artefact.Arrows`; nodes render as circles, `:direction` option for `:LR`, `:RL`, `:TB`, `:BT`, `:TD`
- `:description` field on `%Artefact{}` — optional human-readable description, defaults to `nil`; accepted by `Artefact.new/1` and round-tripped through `Artefact.Arrows`
- Mermaid front-matter `title:` (Mermaid 9.4+ heading) and body `accTitle:` derived from `artefact.title`; `accDescr:` derived from `artefact.description` (inline form for single-line, block form `accDescr { ... }` for multi-line)
- `Artefact.combine/3` — pipeline-friendly convenience over `Artefact.Binding.find/2` + `Artefact.harmonise/4`; the heart flows through the pipe as the first argument, opts honour `:title`, `:base_label` and `:description` overrides; raises `MatchError` when no shared bindings exist

## 0.1.2 — 2026-04-21

- Improved `Artefact.new/1` macro — nodes and relationships declared inline with atom keys and keyword options
- `Artefact.Cypher.merge_params/1` — parameterised MERGE returning `{cypher, params}` for driver use
- `Artefact.Cypher.create_params/1` — parameterised CREATE returning `{cypher, params}`
- `Artefact.Binding.find/2` — finds shared nodes between two artefacts by uuid for harmonisation
- `Artefact.harmonise/3` macro — merges two artefacts on shared node bindings; left argument is heartside

## 0.1.1 — 2026-04-01

- `Artefact.Arrows` — lossless round-trip with Arrows JSON (`from_json/2`, `to_json/1`)
- `Artefact.Cypher` — inline `create/1` and `merge/1` Cypher string generation
- `%Artefact{}`, `%Artefact.Graph{}`, `%Artefact.Node{}`, `%Artefact.Relationship{}` structs
- `Artefact.compose/2` — combines two artefacts into one graph
