# SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Artefact.Error.Invalid do
  @moduledoc """
  Validation rule violations on an `%Artefact{}`.

  Returned as `{:error, %Artefact.Error.Invalid{reasons: [...]}}` from
  `Artefact.validate/1` and from any operation that received an invalid
  input or produced an invalid output. Raised by `Artefact.validate!/1`
  and by the `!` variants of the operations.

  `:reasons` is a list of human-readable strings, one per rule
  violation.
  """

  use Splode.Error, fields: [:reasons], class: :invalid

  def message(%{reasons: reasons}) when is_list(reasons) do
    "invalid artefact: " <> Enum.join(reasons, "; ")
  end

  def message(_), do: "invalid artefact"
end
