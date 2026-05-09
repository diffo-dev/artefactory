<!--
SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
SPDX-License-Identifier: MIT
-->

# Changelog

## 0.2.0 — 2026-05-05 *(breaking)*

### API shape

- All public ops now have **two variants**:
  - `new/1`, `compose/3`, `combine/3`, `harmonise/4`, `graft/3` return `{:ok, %Artefact{}} | {:error, error}`.
  - `new!/1`, `compose!/3`, `combine!/3`, `harmonise!/4`, `graft!/3` return `%Artefact{}` directly or raise the error struct. Behaviour matches 0.1.5's raise-everywhere — the `!` variants are the gentle migration path.
- `validate/1` shape: `:ok | {:error, %Artefact.Error.Invalid{reasons: [...]}}` (was `{:error, [reason_strings]}`).
- `validate!/1` raises `Artefact.Error.Invalid` (was `ArgumentError`).
- Closes [#23], [#25].

### Errors as structured values

- New `:splode` runtime dependency (`{:splode, "~> 0.3"}`).
- `Artefact.Error` — Splode root with two error classes (`:invalid`, `:operation`).
- `Artefact.Error.Invalid` — validation rule violations; `:reasons` field carries the list of human-readable strings.
- `Artefact.Error.Operation` — op-specific outcomes; `:op`, `:tag`, `:details` fields. See `MIGRATION.md` for the full per-op tag table.
- Errors are real Elixir exceptions — raisable by the `!` variants, pattern-matchable as struct values from the non-`!` variants, and aggregatable by Splode-using callers (e.g. UsTwo libraries).

### Module reorg (internal)

- `Artefact.Op` — implementation home for the operations.
- `Artefact.Validator` — implementation home for validation rules; surfaced via `defdelegate` from `Artefact`.
- The `Artefact` module is now a thin macro facade plus the `%Artefact{}` struct definition. Future internal refactors won't churn the consumer-visible surface.

### Migration

See [`MIGRATION.md`](MIGRATION.md) for the migration guide. TL;DR — append `!` to every op call and you're done; use the non-`!` variant + `with`/`case` if you want explicit error handling.

[#23]: https://github.com/diffo-dev/artefactory/issues/23
[#25]: https://github.com/diffo-dev/artefactory/issues/25

## 0.1.5 — 2026-05-05

- `Artefact.is_artefact?/1`, `Artefact.is_valid?/1`, `Artefact.validate/1`, `Artefact.validate!/1` — public validation API. Closes [#26], [#27]
- `Artefact.UUID.valid?/1` — UUIDv7 format predicate; used internally by validation and exposed for callers
- All public ops (`new/1`, `compose/3`, `combine/3`, `harmonise/4`, `graft/3`) now validate their input artefacts and validate the produced artefact before returning — corruption fails at the call site rather than several steps downstream. Closes [#30] (empty/invalid uuid rejected at op input), [#24] (non-list `:labels` rejected at op input)
- `Artefact.graft/3` enforces the no-new-islands rule — every new node in `args` must reach a bind-only key via `args.relationships`; raises `ArgumentError` listing orphan keys otherwise. Closes [#29]
- Validation rule-set: artefact uuid is UUIDv7; node uuid is UUIDv7; node `:labels` is a list of strings; node `:properties` is a map; relationship `:type` is a non-empty string; relationship `:from_id`/`:to_id` reference an extant node; node uuids, node ids and relationship ids are unique within the graph

[#24]: https://github.com/diffo-dev/artefactory/issues/24
[#26]: https://github.com/diffo-dev/artefactory/issues/26
[#27]: https://github.com/diffo-dev/artefactory/issues/27
[#29]: https://github.com/diffo-dev/artefactory/issues/29
[#30]: https://github.com/diffo-dev/artefactory/issues/30

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
