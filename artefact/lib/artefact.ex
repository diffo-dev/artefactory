# SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Artefact do
  @moduledoc """
  A knowledge graph fragment — a small, self-contained piece of knowledge
  expressed as a property graph.

  The canonical form is the `%Artefact{}` struct. Arrows JSON and Cypher are
  derived representations: JSON for interchange and visual editing, Cypher
  for persistence.

  ## Operations

    * `new/1` — build an artefact, inline (`:nodes` + `:relationships`) or
      from a pre-built `%Artefact.Graph{}`.
    * `compose/3` — concatenate two artefacts; nodes remain disjoint.
    * `combine/3` — pipeline-friendly union; bindings auto-found via shared
      uuid; delegates to `harmonise/4`.
    * `harmonise/4` — union via declared bindings; lower uuid wins identity,
      labels are unioned, left wins on property conflict.
    * `graft/3` — pipeline-friendly extension; integrates inline `args`
      (same shape as `new`'s inline form, but every node MUST carry `:uuid`)
      into an existing artefact.

  Each op has two variants:

    * `op/n` returns `{:ok, %Artefact{}} | {:error, error}` where `error`
      is `Artefact.Error.Invalid` (a validation rule was violated) or
      `Artefact.Error.Operation` (an op-specific outcome — e.g. combine
      with no shared bindings, graft with disconnected islands).
    * `op!/n` returns the `%Artefact{}` directly or raises the error
      struct. Use when you'd rather let exceptions propagate (livebooks,
      scripts, tests).

  Every operation records its lineage in the result's `metadata.provenance`
  and validates its inputs and the produced artefact.

  ## Validation

    * `is_artefact?/1` — true when the value is an `%Artefact{}` struct.
    * `is_valid?/1` — true when the artefact passes every structural rule.
    * `validate/1` — `:ok | {:error, %Artefact.Error.Invalid{reasons: [...]}}`.
    * `validate!/1` — `:ok` or raises `Artefact.Error.Invalid`.

  An artefact is *valid* when its uuid is a UUIDv7, every node has a
  UUIDv7 uuid, every node's labels is a list of strings, every node's
  properties is a map, every relationship's `from_id` and `to_id`
  reference an extant node, every relationship type is a non-empty
  string, and node uuids, node ids and relationship ids are unique
  within the graph.

  ## Exporting

    * `Artefact.Arrows` — round-trip with [arrows.app](https://arrows.app)
      via `from_json/2`, `from_json!/2`, `to_json/1`.
    * `Artefact.Cypher` — derive Cypher (CREATE or MERGE) for Neo4j
      persistence, with parameterised variants for driver use.
  """

  defstruct [
    :id,
    :uuid,
    :title,
    :description,
    :base_label,
    :style,
    metadata: %{},
    graph: %Artefact.Graph{}
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          uuid: String.t(),
          title: String.t() | nil,
          description: String.t() | nil,
          base_label: String.t() | nil,
          style: atom() | nil,
          graph: Artefact.Graph.t(),
          metadata: map()
        }

  # =====================================================================
  # Validation API — delegated to Artefact.Validator
  # =====================================================================

  defdelegate is_artefact?(value), to: Artefact.Validator
  defdelegate is_valid?(value), to: Artefact.Validator
  defdelegate validate(value), to: Artefact.Validator
  defdelegate validate!(value), to: Artefact.Validator

  # =====================================================================
  # new / new!
  # =====================================================================

  @doc """
  Create a new Artefact. Returns `{:ok, %Artefact{}}` or
  `{:error, %Artefact.Error.Invalid{}}`.

  Defaults `base_label` and `title` to the short name of the calling
  module. Override with `title:` or `base_label:` in attrs. Optional
  `description:` is a longer human-readable note about the artefact.

  Records `:struct` provenance with the calling module.
  """
  defmacro new(attrs \\ []) do
    {caller, caller_name, default_base_label} = caller_info(__CALLER__.module)

    quote do
      Artefact.Op.new(
        unquote(attrs),
        unquote(caller),
        unquote(caller_name),
        unquote(default_base_label)
      )
    end
  end

  @doc "Same as `new/1` but raises `Artefact.Error.Invalid` on failure."
  defmacro new!(attrs \\ []) do
    {caller, caller_name, default_base_label} = caller_info(__CALLER__.module)

    quote do
      Artefact.bang!(
        Artefact.Op.new(
          unquote(attrs),
          unquote(caller),
          unquote(caller_name),
          unquote(default_base_label)
        )
      )
    end
  end

  # =====================================================================
  # compose / compose!
  # =====================================================================

  @doc """
  Compose two artefacts. Graphs are concatenated without merging.
  Returns `{:ok, %Artefact{}}` or `{:error, %Artefact.Error.Invalid{}}`.

  `base_label` defaults to the portmanteau of both artefacts' base_labels.
  Override with `base_label:` or `title:` in opts.

  Records `:composed` provenance with the calling module.
  """
  defmacro compose(a1, a2, opts \\ []) do
    caller = __CALLER__.module

    quote do
      Artefact.Op.compose(unquote(a1), unquote(a2), unquote(opts), unquote(caller))
    end
  end

  @doc "Same as `compose/3` but raises on failure."
  defmacro compose!(a1, a2, opts \\ []) do
    caller = __CALLER__.module

    quote do
      Artefact.bang!(
        Artefact.Op.compose(unquote(a1), unquote(a2), unquote(opts), unquote(caller))
      )
    end
  end

  # =====================================================================
  # combine / combine!
  # =====================================================================

  @doc """
  Combine `other` into `heart` using bindings auto-found via shared uuid.

  Returns `{:ok, %Artefact{}}` or `{:error, error}` where `error` is
  `Artefact.Error.Invalid` or `Artefact.Error.Operation` with `tag:
  :no_shared_bindings` if `heart` and `other` share no node uuids.

  Designed for pipelines:

      with {:ok, knowing}     <- Artefact.combine(my_knowing, my_valuing),
           {:ok, being}       <- Artefact.combine(knowing, my_being),
           {:ok, mind}        <- Artefact.combine(being, my_doing,
                                   title: "MeMind", description: "Mind of Me.") do
        ...
      end

  Or with `combine!/3` if you'd rather let it raise.

  Records `:harmonised` provenance with the calling module.
  """
  defmacro combine(heart, other, opts \\ []) do
    caller = __CALLER__.module

    quote do
      Artefact.Op.combine(unquote(heart), unquote(other), unquote(opts), unquote(caller))
    end
  end

  @doc "Same as `combine/3` but raises on failure."
  defmacro combine!(heart, other, opts \\ []) do
    caller = __CALLER__.module

    quote do
      Artefact.bang!(
        Artefact.Op.combine(unquote(heart), unquote(other), unquote(opts), unquote(caller))
      )
    end
  end

  # =====================================================================
  # harmonise / harmonise!
  # =====================================================================

  @doc """
  Harmonise two artefacts using declared bindings.

  Returns `{:ok, %Artefact{}}` or `{:error, error}` where `error` is
  `Artefact.Error.Invalid` or `Artefact.Error.Operation` with `tag:
  :self_harmonise` (same artefact) or `tag: :same_base_label`.

  Bound nodes are merged: lower uuid wins for identity and properties,
  labels are unioned. All relationships are preserved and remapped.

  Records `:harmonised` provenance with the calling module.
  """
  defmacro harmonise(a1, a2, bindings, opts \\ []) do
    caller = __CALLER__.module

    quote do
      Artefact.Op.harmonise(
        unquote(a1),
        unquote(a2),
        unquote(bindings),
        unquote(opts),
        unquote(caller)
      )
    end
  end

  @doc "Same as `harmonise/4` but raises on failure."
  defmacro harmonise!(a1, a2, bindings, opts \\ []) do
    caller = __CALLER__.module

    quote do
      Artefact.bang!(
        Artefact.Op.harmonise(
          unquote(a1),
          unquote(a2),
          unquote(bindings),
          unquote(opts),
          unquote(caller)
        )
      )
    end
  end

  # =====================================================================
  # graft / graft!
  # =====================================================================

  @doc """
  Graft `args` onto `left`, integrating new nodes and relationships
  declared inline (same shape as `Artefact.new` accepts). Every args
  node MUST carry an explicit `:uuid` — uuid is the binding.

  Returns `{:ok, %Artefact{}}` or `{:error, error}` where `error` is
  `Artefact.Error.Invalid` or `Artefact.Error.Operation` with one of
  `:missing_uuid`, `:invalid_uuid`, `:invalid_labels`,
  `:invalid_properties`, `:duplicate_keys`, `:unknown_rel_key`, or
  `:islands` (new nodes that don't reach a bind-only key).

  ## opts

  Honours `:title` and `:description` only — both name the result. If
  omitted, `left`'s title and description carry forward.
  `:base_label` is **not** honoured; the result keeps `left.base_label`.

  Records `:grafted` provenance with the calling module.
  """
  defmacro graft(left, args, opts \\ []) do
    caller = __CALLER__.module

    quote do
      Artefact.Op.graft(unquote(left), unquote(args), unquote(opts), unquote(caller))
    end
  end

  @doc "Same as `graft/3` but raises on failure."
  defmacro graft!(left, args, opts \\ []) do
    caller = __CALLER__.module

    quote do
      Artefact.bang!(
        Artefact.Op.graft(unquote(left), unquote(args), unquote(opts), unquote(caller))
      )
    end
  end

  # =====================================================================
  # Internal helpers — used by the `!` macros
  # =====================================================================

  @doc false
  def bang!({:ok, result}), do: result
  def bang!({:error, e}), do: raise(e)

  @doc false
  def caller_info(caller_module) do
    caller_name = caller_module && caller_module |> Module.split() |> List.last()
    default_base_label = caller_name && String.replace(caller_name, ~r/[^A-Za-z0-9]/, "")
    {caller_module, caller_name, default_base_label}
  end
end
