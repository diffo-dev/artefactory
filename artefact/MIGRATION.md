<!--
SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
SPDX-License-Identifier: MIT
-->

# Migration: artefact 0.1.x → 0.2.0

0.2.0 reshapes the public API to be idiomatic Elixir. Operations now
return `{:ok, _}` / `{:error, _}` tuples and have `!` variants that
raise. Errors are `Splode`-typed structs that pattern-match cleanly.

## TL;DR

If you were using 0.1.x and you're happy with raise-on-error
semantics, append `!` to every op call and you're done:

```diff
- artefact = Artefact.new(title: "x", nodes: [...])
+ artefact = Artefact.new!(title: "x", nodes: [...])

- result = a |> Artefact.combine(b) |> Artefact.combine(c)
+ result = a |> Artefact.combine!(b) |> Artefact.combine!(c)
```

That's the whole migration if you don't want to use the new return
shape.

## Per-op changes

### `new/1` — now returns `{:ok, _}`

```elixir
# 0.1.x
artefact = Artefact.new(title: "x", nodes: [...])

# 0.2.0
{:ok, artefact} = Artefact.new(title: "x", nodes: [...])
# or
artefact = Artefact.new!(title: "x", nodes: [...])
```

### `compose/3`, `combine/3`, `harmonise/4`, `graft/3`

All shifted to `{:ok, _}` / `{:error, _}` returns. The `!` variants
match the old 0.1.x raise behaviour exactly.

```elixir
# 0.1.x
result =
  me_knowing
  |> Artefact.combine(me_valuing)
  |> Artefact.combine(me_being)

# 0.2.0 — pipeline-friendly with `!`
result =
  me_knowing
  |> Artefact.combine!(me_valuing)
  |> Artefact.combine!(me_being)

# 0.2.0 — explicit `with` for error handling
with {:ok, knowing} <- Artefact.combine(me_knowing, me_valuing),
     {:ok, being} <- Artefact.combine(knowing, me_being) do
  {:ok, being}
end
```

## Error shapes

Errors are now structs from the `Splode`-based `Artefact.Error.*`
namespace. Two flavours:

### `Artefact.Error.Invalid` — class `:invalid`

Validation rule violations on the produced or input artefact.

```elixir
%Artefact.Error.Invalid{reasons: ["uuid is not a valid UUIDv7"]}
```

`:reasons` is a list of human-readable strings — same shape as 0.1.5's
`validate/1` reasons, just wrapped in a struct.

### `Artefact.Error.Operation` — class `:operation`

Op-specific outcomes that prevent the op from proceeding even with
valid input. The `:tag` field discriminates the specific outcome:

| Op | `:tag` values | `:details` |
|----|---------------|------------|
| `combine` | `:no_shared_bindings` | `%{}` |
| `harmonise` | `:self_harmonise` | `%{uuid: ...}` |
| `harmonise` | `:same_base_label` | `%{base_label: ...}` |
| `graft` | `:missing_uuid` | `%{key: ...}` |
| `graft` | `:invalid_uuid` | `%{key: ..., uuid: ...}` |
| `graft` | `:invalid_labels` | `%{key: ..., labels: ...}` |
| `graft` | `:invalid_properties` | `%{key: ..., properties: ...}` |
| `graft` | `:duplicate_keys` | `%{keys: [...]}` |
| `graft` | `:unknown_rel_key` | `%{key: ...}` |
| `graft` | `:islands` | `%{keys: [...]}` |

Pattern matching on the tag is the idiomatic way:

```elixir
case Artefact.combine(heart, other) do
  {:ok, result} -> result
  {:error, %Artefact.Error.Operation{tag: :no_shared_bindings}} ->
    Artefact.compose!(heart, other)
end
```

## Specific raise-type changes

If you were rescuing exceptions from 0.1.x:

| 0.1.x raise | 0.2.0 raise (from `!` variants) |
|-------------|---------------------------------|
| `ArgumentError` "invalid artefact: ..." | `Artefact.Error.Invalid` |
| `ArgumentError` "cannot harmonise an artefact with itself" | `Artefact.Error.Operation` (tag `:self_harmonise`) |
| `ArgumentError` "cannot harmonise artefacts with the same base_label" | `Artefact.Error.Operation` (tag `:same_base_label`) |
| `MatchError` (combine, no shared bindings) | `Artefact.Error.Operation` (tag `:no_shared_bindings`) |
| `ArgumentError` "graft: ..." | `Artefact.Error.Operation` (op `:graft`, various tags) |

`rescue` clauses should switch to the new types:

```elixir
# 0.1.x
try do
  Artefact.combine(heart, other)
rescue
  MatchError -> :ok
end

# 0.2.0
case Artefact.combine(heart, other) do
  {:ok, _} -> :ok
  {:error, _} -> :ok
end
```

## Validation API

`is_artefact?/1`, `is_valid?/1`, `validate/1`, `validate!/1` are now
delegated from `Artefact` to the new `Artefact.Validator` module —
the surface call site is unchanged. Two shape changes:

* `validate/1` — return is now `:ok` or `{:error, %Artefact.Error.Invalid{reasons: [...]}}`
  (was `{:error, [reason_strings]}`).
* `validate!/1` — raises `Artefact.Error.Invalid` (was `ArgumentError`).

## New module surface

Internal modules introduced in 0.2.0:

* `Artefact.Op` — implementation home for `new`, `compose`, `combine`,
  `harmonise`, `graft`. Don't depend on this directly — `Artefact` is
  still the supported surface.
* `Artefact.Validator` — validation rule implementation, surfaced via
  `Artefact`'s defdelegated functions.
* `Artefact.Error` — Splode root.
* `Artefact.Error.Invalid`, `Artefact.Error.Operation`,
  `Artefact.Error.Unknown` — error structs.

The `Artefact` module itself becomes a thin macro facade plus the
struct definition. Future internal refactors won't require consumer
changes if you stick to `Artefact.*`.

## Dependency added

`{:splode, "~> 0.3"}` — error-class library used for the new error
structs. Adds about 1KB compiled, no transitive runtime deps beyond
Elixir core.

## Held in the commons

If your migration surfaces a sharp edge or a missing escape hatch,
file an issue at https://github.com/diffo-dev/artefactory/issues.
