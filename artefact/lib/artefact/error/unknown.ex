# SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Artefact.Error.Unknown do
  @moduledoc """
  Catch-all for errors that don't match any known Artefact error class.

  Required by `Artefact.Error`'s Splode configuration as the
  `:unknown_error` fallback.
  """

  use Splode.Error, fields: [:error], class: :operation

  def message(%{error: error}), do: "unknown artefact error: #{inspect(error)}"
end
