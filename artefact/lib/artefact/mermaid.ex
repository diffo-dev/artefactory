# SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Artefact.Mermaid do
  @moduledoc """
  Derives Mermaid diagram source from an `%Artefact{}`.

  Uses the legacy `graph` syntax for broad renderer compatibility (GitHub,
  Notion, mdBook, Livebook). Nodes render as circles (`id(("..."))`) — the
  property-graph convention, and a closer match to the vis-network ellipses in
  the `ArtefactKino` heartside panel. Labels mirror that panel: the `name`
  property (or node id, when no name is set) on top, semantic labels joined
  with a space below, separated by `<br/>`.

  When `artefact.title` is set, a YAML front-matter block carries the title
  (rendered as a heading by Mermaid 9.4+) and an `accTitle:` line is emitted
  for screen readers. A nil title produces neither — the export starts at
  `graph <direction>`.

  Lossy: `position`, `style`, properties beyond `name`, and the artefact-level
  `base_label` (collapsed into per-node labels at output time) are not represented.
  """

  @directions ~w(LR RL TB BT TD)a

  @doc """
  Emit a Mermaid source string for the artefact.

  ## Options

    * `:direction` — flow direction. One of `:LR`, `:RL`, `:TB`, `:BT`, `:TD`.
      Defaults to `:LR`.

  ## Example

  For the `us_two` artefact:

      ---
      title: UsTwo
      ---
      graph LR
        accTitle: UsTwo
        n0(("Matt<br/>Agent Me"))
        n1(("Claude<br/>Agent You"))
        n0 -->|US_TWO| n1

  """
  def export(%Artefact{title: title, base_label: base_label, graph: graph}, opts \\ []) do
    direction = Keyword.get(opts, :direction, :LR)

    unless direction in @directions do
      raise ArgumentError,
            "invalid :direction #{inspect(direction)} — expected one of #{inspect(@directions)}"
    end

    node_lines = Enum.map(graph.nodes, &node_line(&1, base_label))
    rel_lines = Enum.map(graph.relationships, &rel_line/1)

    body = ["graph #{direction}" | acc_title_lines(title) ++ node_lines ++ rel_lines]

    Enum.join(front_matter(title) ++ body, "\n")
  end

  # -- front-matter & accessibility --

  defp front_matter(nil), do: []
  defp front_matter(title), do: ["---", "title: #{yaml_scalar(title)}", "---"]

  defp acc_title_lines(nil), do: []
  defp acc_title_lines(title), do: ["  accTitle: #{single_line(title)}"]

  # YAML plain scalar where safe; double-quoted (with `"` and `\` escaped)
  # when the value contains characters that break a bare scalar.
  defp yaml_scalar(value) do
    s = to_string(value)

    if needs_yaml_quoting?(s) do
      escaped =
        s
        |> String.replace("\\", "\\\\")
        |> String.replace("\"", "\\\"")

      "\"#{escaped}\""
    else
      s
    end
  end

  defp needs_yaml_quoting?(""), do: true

  defp needs_yaml_quoting?(s) do
    String.contains?(s, [":", "\"", "#", "\n"]) or
      String.starts_with?(s, [" ", "\t", "&", "*", "!", "?", "{", "[", "|", ">", "%", "@", "`", "'", "-"])
  end

  # accTitle / accDescr inline form is single-line; collapse any newlines to spaces.
  defp single_line(value) do
    value
    |> to_string()
    |> String.replace(~r/\s*\n\s*/, " ")
  end

  defp node_line(%Artefact.Node{} = node, base_label) do
    name = Map.get(node.properties, "name", node.id)
    semantic = Enum.reject(node.labels, &(&1 == base_label))

    label_text =
      case semantic do
        [] -> escape(name)
        labels -> "#{escape(name)}<br/>#{escape(Enum.join(labels, " "))}"
      end

    "  #{node.id}((\"#{label_text}\"))"
  end

  defp rel_line(%Artefact.Relationship{type: type, from_id: from, to_id: to}) do
    "  #{from} -->|#{escape_pipe(type)}| #{to}"
  end

  # Mermaid node label text inside `(("..."))` — escape double quotes only;
  # `<br/>` is rendered as a line break, which is what we want.
  defp escape(value) do
    value
    |> to_string()
    |> String.replace("\"", "&quot;")
  end

  # Edge labels live between pipes, so the pipe itself must be entity-encoded.
  defp escape_pipe(value) do
    value
    |> to_string()
    |> String.replace("|", "&#124;")
    |> String.replace("\"", "&quot;")
  end
end
