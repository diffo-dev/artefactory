# SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Artefact.Mermaid do
  @moduledoc """
  Converts between `%Artefact{}` structs and Mermaid legacy `graph` source.

  Two public functions:

  - `export/2` — artefact → Mermaid string
  - `from_mmd!/2` — Mermaid string → artefact

  ## Round-trip fidelity

  `export/2` followed by `from_mmd!/2` followed by `export/2` produces
  identical Mermaid source. The preserved fields are: `title`, `description`,
  node `name` and `description` properties, node labels, and relationship
  types. See *Lossy* below for what is not preserved.

  ## Export format

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

  When `artefact.description` is set, an `accDescr:` line follows the
  `accTitle:` line. Multi-line descriptions use the block form
  (`accDescr { ... }`); single-line descriptions use the inline form. A nil
  description is omitted. Like `accTitle`, the description is screen-reader
  only — Mermaid does not render it visually.

  Node `description` properties are emitted as `click id "description"` tooltip lines —
  present in source, visible on hover, and parseable by `from_mmd!/2`.

  ## Lossy

  `position`, `style`, properties beyond `name` and `description`, and the
  artefact-level `base_label` (collapsed into per-node labels at output time)
  are not represented in Mermaid source and are not recovered on import.
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
  def export(
        %Artefact{title: title, description: description, base_label: base_label, graph: graph},
        opts \\ []
      ) do
    direction = Keyword.get(opts, :direction, :LR)

    unless direction in @directions do
      raise ArgumentError,
            "invalid :direction #{inspect(direction)} — expected one of #{inspect(@directions)}"
    end

    node_lines = Enum.map(graph.nodes, &node_line(&1, base_label))
    click_lines = Enum.flat_map(graph.nodes, &click_line/1)
    rel_lines = Enum.map(graph.relationships, &rel_line/1)

    accessibility = acc_title_lines(title) ++ acc_descr_lines(description)
    body = ["graph #{direction}" | accessibility ++ node_lines ++ click_lines ++ rel_lines]

    Enum.join(front_matter(title) ++ body, "\n")
  end

  # -- front-matter & accessibility --

  defp front_matter(nil), do: []
  defp front_matter(title), do: ["---", "title: #{yaml_scalar(title)}", "---"]

  defp acc_title_lines(nil), do: []
  defp acc_title_lines(title), do: ["  accTitle: #{single_line(title)}"]

  defp acc_descr_lines(nil), do: []

  defp acc_descr_lines(description) do
    s = to_string(description)

    if String.contains?(s, "\n") do
      indented =
        s
        |> String.split("\n")
        |> Enum.map_join("\n", &"    #{&1}")

      ["  accDescr {", indented, "  }"]
    else
      ["  accDescr: #{s}"]
    end
  end

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
      String.starts_with?(s, [
        " ",
        "\t",
        "&",
        "*",
        "!",
        "?",
        "{",
        "[",
        "|",
        ">",
        "%",
        "@",
        "`",
        "'",
        "-"
      ])
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

  defp click_line(%Artefact.Node{id: id, properties: props}) do
    case Map.get(props, "description") do
      nil -> []
      desc -> ["  click #{id} \"#{escape(desc)}\""]
    end
  end

  defp rel_line(%Artefact.Relationship{type: type, from_id: from, to_id: to}) do
    "  #{from} -->|#{escape_pipe(type)}| #{to}"
  end

  # -- parser --

  @doc """
  Parse a Mermaid `graph` source string into an `%Artefact{}`.

  Accepts both the round-trip format produced by `export/2` and the broader
  Mermaid legacy graph syntax used by tools like Confluence and GitHub.

  ## Node content conventions

  Three label formats are recognised inside node shapes:

  - `name<br/>Label1 Label2` — our export format: name on top, space-joined
    semantic labels below
  - `LABEL · name` — yarn convention: a single label and name separated by ` · `
  - plain text — treated as the name with no labels

  `click id "text"` lines become the node `description` property.

  ## UUID identity

  Each node's UUID is derived deterministically from its **Mermaid node id**
  (the `\w+` identifier, e.g. `val_0`, `std_ulogic`) via
  `Artefact.UUID.from_name/1`. The display name inside the shape label is not
  used. This means:

  - The same diagram imported twice produces the same artefact — safe to repeat.
  - Two diagrams that share a node id will bind via `combine!/2` without any
    manual UUID management.
  - Renaming a node id changes its UUID and breaks bindings. Keep ids stable.

  ## Inline edge + node syntax

  When a node's shape is declared on the same line as an edge
  (`A["label"] -->|TYPE| B["label"]`), only the **edge** is registered; the
  node label is not captured. Use a separate declaration line to preserve
  labels and names:

      graph LR
        val_0["VALUE · 0"]
        val_0 -->|ENUMERATES| value

  The round-trip format produced by `export/2` always emits separate node and
  edge lines, so this limitation does not affect round-trips.

  ## Options

    * `:title` — overrides the title parsed from YAML front matter
    * `:description` — overrides the description parsed from `accDescr:`
    * `:base_label` — sets the artefact base label (not inferred from source)

  ## Example

      iex> source = \"""
      ...> ---
      ...> title: Us Two
      ...> ---
      ...> graph LR
      ...>   n0(("Matt<br/>Agent Me"))
      ...>   n1(("Claude<br/>Agent You"))
      ...>   n0 -->|US_TWO| n1
      ...> \"""
      iex> artefact = Artefact.Mermaid.from_mmd!(source)
      iex> artefact.title
      "Us Two"
      iex> length(artefact.graph.nodes)
      2

  """
  def from_mmd!(source, opts \\ []) do
    require Artefact
    {parsed_title, parsed_desc, node_decls, edge_decls, click_decls} = parse_mmd(source)

    title = Keyword.get(opts, :title, parsed_title)
    description = Keyword.get(opts, :description, parsed_desc)
    base_label = Keyword.get(opts, :base_label)

    all_ids =
      (Map.keys(node_decls) ++
         Enum.flat_map(edge_decls, fn {f, _t, to} -> [f, to] end))
      |> Enum.uniq()

    id_to_key = all_ids |> Enum.with_index() |> Map.new(fn {id, i} -> {id, :"n#{i}"} end)

    nodes =
      Enum.map(all_ids, fn id ->
        {name, labels} = Map.get(node_decls, id, {id, []})
        desc = Map.get(click_decls, id)
        props = if desc, do: %{"name" => name, "description" => desc}, else: %{"name" => name}
        {id_to_key[id], [labels: labels, properties: props, uuid: Artefact.UUID.from_name(id)]}
      end)

    relationships =
      edge_decls
      |> Enum.map(fn {from_id, type, to_id} ->
        [from: id_to_key[from_id], type: type, to: id_to_key[to_id]]
      end)
      |> Enum.uniq()

    Artefact.new!(
      title: title,
      description: description,
      base_label: base_label,
      nodes: nodes,
      relationships: relationships
    )
  end

  defp parse_mmd(source) do
    {title_from_fm, body} = strip_front_matter(source)

    {title, desc, node_decls, edge_decls, click_decls} =
      body
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> collect_lines()

    {title_from_fm || title, desc, node_decls, edge_decls, click_decls}
  end

  defp strip_front_matter(source) do
    case Regex.run(~r/\A---\n(.*?)\n---\n/s, source) do
      [matched, fm_body] ->
        title =
          case Regex.run(~r/^title:\s*["']?(.+?)["']?\s*$/m, fm_body) do
            [_, t] -> String.trim(t, "\"")
            nil -> nil
          end

        {title, String.slice(source, String.length(matched)..-1//1)}

      nil ->
        {nil, source}
    end
  end

  defp collect_lines(lines) do
    acc = {nil, nil, %{}, [], %{}, false, []}

    {title, desc, node_decls, edge_decls, click_decls, _in_descr, _descr_lines} =
      Enum.reduce(lines, acc, fn line, state ->
        {title, desc, nodes, edges, clicks, in_descr, descr_lines} = state

        cond do
          # Close accDescr block
          in_descr and Regex.match?(~r/^\}/, line) ->
            {title, Enum.join(Enum.reverse(descr_lines), "\n"), nodes, edges, clicks, false, []}

          # Accumulate accDescr block lines
          in_descr ->
            {title, desc, nodes, edges, clicks, true, [String.trim_leading(line, "  ") | descr_lines]}

          # accDescr block open
          Regex.match?(~r/^accDescr\s*\{/, line) ->
            {title, desc, nodes, edges, clicks, true, []}

          # accDescr inline
          m = Regex.run(~r/^accDescr:\s*(.+)$/, line) ->
            [_, d] = m
            {title, d, nodes, edges, clicks, false, []}

          # accTitle (ignore — title comes from front matter or opts)
          Regex.match?(~r/^accTitle:/, line) ->
            state

          # graph declaration, subgraph, end, comments, blank — skip
          Regex.match?(~r/^(?:graph\s|subgraph\s|end$|%%|$)/, line) ->
            state

          # click tooltip: click id "text"
          m = Regex.run(~r/^click\s+(\w+)\s+"([^"]*)"/, line) ->
            [_, id, tooltip] = m
            {title, desc, nodes, edges, Map.put(clicks, id, unescape_html(tooltip)), false, []}

          # edge with label: id -->|TYPE| id  (also handles inline node shapes like A["label"] -->|TYPE| B)
          m = Regex.run(~r/^(\w+).*?(?:-->|-\.->|===>)\|([^|]+)\|\s*(\w+)/, line) ->
            [_, from_id, type, to_id] = m
            {title, desc, nodes, [{from_id, type, to_id} | edges], clicks, false, []}

          # node — try most specific format first
          m = Regex.run(~r/^(\w+)\(\("(.+?)"\)\)/, line) ->
            [_, id, content] = m
            {title, desc, Map.put_new(nodes, id, parse_node_content(content)), edges, clicks, false, []}

          m = Regex.run(~r/^(\w+)\["(.+?)"\]/, line) ->
            [_, id, content] = m
            {title, desc, Map.put_new(nodes, id, parse_node_content(content)), edges, clicks, false, []}

          m = Regex.run(~r/^(\w+)\("(.+?)"\)/, line) ->
            [_, id, content] = m
            {title, desc, Map.put_new(nodes, id, parse_node_content(content)), edges, clicks, false, []}

          m = Regex.run(~r/^(\w+)\[([^\]]+)\]/, line) ->
            [_, id, content] = m
            {title, desc, Map.put_new(nodes, id, parse_node_content(content)), edges, clicks, false, []}

          m = Regex.run(~r/^(\w+)\(([^)]+)\)/, line) ->
            [_, id, content] = m
            {title, desc, Map.put_new(nodes, id, parse_node_content(content)), edges, clicks, false, []}

          true ->
            state
        end
      end)

    {title, desc, node_decls, Enum.reverse(edge_decls), click_decls}
  end

  defp parse_node_content(content) do
    raw = unescape_html(content)

    cond do
      String.contains?(raw, "<br/>") ->
        [name_part, labels_part] = String.split(raw, "<br/>", parts: 2)
        labels = labels_part |> String.split(" ") |> Enum.reject(&(&1 == ""))
        {String.trim(name_part), labels}

      String.contains?(raw, " · ") ->
        [label, name] = String.split(raw, " · ", parts: 2)
        {String.trim(name), [String.trim(label)]}

      true ->
        {String.trim(raw), []}
    end
  end

  defp unescape_html(s) do
    s
    |> String.replace("&quot;", "\"")
    |> String.replace("&amp;", "&")
    |> String.replace("&#124;", "|")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
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
