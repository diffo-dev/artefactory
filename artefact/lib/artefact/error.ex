# SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Artefact.Error do
  @moduledoc """
  Splode root for Artefact errors.

  Two error classes:

    * `:invalid` — the input or produced artefact violates one or more
      validation rules. See `Artefact.Error.Invalid`.
    * `:operation` — the input is a valid artefact, but the requested
      operation cannot proceed for a deterministic reason (no shared
      bindings, self-harmonise, graft islands, etc.). See
      `Artefact.Error.Operation`.

  Errors are real Elixir exceptions, so they can be raised by the `!`
  variants of the operations (`combine!`, `graft!`, etc.) and pattern
  matched on as struct values from the non-`!` variants.
  """

  use Splode,
    error_classes: [
      invalid: Artefact.Error.Invalid,
      operation: Artefact.Error.Operation
    ],
    unknown_error: Artefact.Error.Unknown
end
