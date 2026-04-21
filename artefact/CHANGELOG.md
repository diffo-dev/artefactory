<!--
SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
SPDX-License-Identifier: MIT
-->

# Changelog

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
