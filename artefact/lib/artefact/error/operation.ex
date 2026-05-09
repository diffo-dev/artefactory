# SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Artefact.Error.Operation do
  @moduledoc """
  Op-specific outcomes that prevent an operation from proceeding even
  when its inputs are valid.

  Returned as `{:error, %Artefact.Error.Operation{op: op, tag: tag, details: details}}`
  from the operation that couldn't proceed. Raised by the `!` variants.

  Tags by op:

    * `combine` — `:no_shared_bindings`
    * `harmonise` — `:self_harmonise` (details: `%{uuid: ...}`),
      `:same_base_label` (details: `%{base_label: ...}`)
    * `graft` — `:missing_uuid` (details: `%{key: ...}`),
      `:invalid_uuid` (details: `%{key: ..., uuid: ...}`),
      `:invalid_labels` (details: `%{key: ..., labels: ...}`),
      `:invalid_properties` (details: `%{key: ..., properties: ...}`),
      `:duplicate_keys` (details: `%{keys: [...]}`),
      `:unknown_rel_key` (details: `%{key: ...}`),
      `:islands` (details: `%{keys: [...]}`)

  `:details` is always a map; empty when the tag carries no extra info.
  """

  use Splode.Error, fields: [:op, :tag, :details], class: :operation

  def message(%{op: op, tag: tag, details: details})
      when is_map(details) and map_size(details) > 0 do
    "#{op}: #{tag} #{inspect(details)}"
  end

  def message(%{op: op, tag: tag}), do: "#{op}: #{tag}"
end
