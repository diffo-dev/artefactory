# SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule ArtefactKino do
  @moduledoc """
  Livebook Kino widget for rendering `%Artefact{}` knowledge graphs.

  Renders three panels: interactive vis-network graph (heartside), an export
  panel toggling between CREATE / MERGE Cypher, Arrows JSON and Mermaid
  source, and a tabbed Elixir inspector showing the artefact, nodes and
  relationships as tables.

  ## Usage

      ArtefactKino.new(artefact)
      ArtefactKino.new(artefact, default: :merge)
  """

  use Kino.JS

  @doc """
  Render an `%Artefact{}` as a three-panel Kino widget.

  Options:
  - `default:` — `:create` (default) or `:merge`
  """
  def new(%Artefact{} = artefact, opts \\ []) do
    default = Keyword.get(opts, :default, :create)
    Kino.JS.new(__MODULE__, build_data(artefact, default))
  end

  defp build_data(artefact, default) do
    %{
      nodes:         vis_nodes(artefact),
      edges:         vis_edges(artefact),
      create_cypher: Artefact.Cypher.create(artefact),
      merge_cypher:  Artefact.Cypher.merge(artefact),
      arrows_json:   Artefact.Arrows.to_json(artefact),
      mermaid:       Artefact.Mermaid.export(artefact),
      default:       Atom.to_string(default),
      title:         artefact.title || artefact.base_label || "Artefact",
      description:   artefact.description,
      artefact_rows: artefact_rows(artefact),
      nodes_rows:    nodes_rows(artefact),
      rels_rows:     rels_rows(artefact)
    }
  end

  defp vis_nodes(%Artefact{graph: graph, base_label: base_label}) do
    Enum.map(graph.nodes, fn node ->
      all_labels      = Enum.uniq(node.labels ++ if(base_label, do: [base_label], else: []))
      semantic_labels = Enum.reject(node.labels, &(&1 == base_label))
      name    = Map.get(node.properties, "name", node.id)
      label   = if semantic_labels == [], do: name, else: "#{name}\n#{Enum.join(semantic_labels, " ")}"
      tooltip = node.properties
        |> Enum.map(fn {k, v} -> "#{k}: #{v}" end)
        |> Enum.join("\n")
      %{id: node.id, label: label, labels: all_labels, title: "#{node.uuid}\n#{tooltip}"}
    end)
  end

  defp vis_edges(%Artefact{graph: graph}) do
    graph.relationships
    |> Enum.with_index()
    |> Enum.map(fn {rel, idx} ->
      %{id: idx, from: rel.from_id, to: rel.to_id, label: rel.type, arrows: "to"}
    end)
  end

  defp artefact_rows(%Artefact{} = a) do
    [
      %{key: "id",          value: a.id},
      %{key: "uuid",        value: a.uuid},
      %{key: "title",       value: inspect(a.title)},
      %{key: "description", value: inspect(a.description)},
      %{key: "base_label",  value: inspect(a.base_label)},
      %{key: "metadata",    value: inspect(a.metadata, pretty: true)}
    ]
  end

  defp nodes_rows(%Artefact{graph: graph}) do
    Enum.map(graph.nodes, fn n ->
      %{
        id:         n.id,
        uuid:       n.uuid,
        labels:     Enum.join(n.labels, ", "),
        properties: inspect(n.properties)
      }
    end)
  end

  defp rels_rows(%Artefact{graph: graph}) do
    graph.relationships
    |> Enum.with_index()
    |> Enum.map(fn {r, idx} ->
      %{
        idx:        idx,
        from:       r.from_id,
        type:       r.type,
        to:         r.to_id,
        properties: inspect(r.properties)
      }
    end)
  end

  asset "main.js" do
    """
    const VIS_CDN = "https://unpkg.com/vis-network/standalone/umd/vis-network.min.js";

    const LAYOUTS = {
      physics: {
        physics: { enabled: true, solver: "forceAtlas2Based", stabilization: { iterations: 150 } },
        layout:  {}
      },
      hierarchical: {
        physics: { enabled: false },
        layout:  { hierarchical: { enabled: true, direction: "UD", sortMethod: "directed", nodeSpacing: 120, levelSeparation: 100 } }
      },
      radial: {
        physics: { enabled: true, solver: "repulsion", repulsion: { nodeDistance: 150 } },
        layout:  {}
      }
    };

    // -- colour theory --

    function buildLabelHues(nodes) {
      const labels = new Set();
      nodes.forEach(n => n.labels.forEach(l => labels.add(l)));
      const sorted = [...labels].sort();
      const hues = {};
      sorted.forEach((l, i) => { hues[l] = (i / sorted.length) * 360; });
      return hues;
    }

    function blendHues(hues) {
      let sx = 0, sy = 0;
      hues.forEach(h => { sx += Math.cos(h * Math.PI / 180); sy += Math.sin(h * Math.PI / 180); });
      return ((Math.atan2(sy, sx) * 180 / Math.PI) + 360) % 360;
    }

    function toLinear(c) { return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); }
    function toSRGB(c)   { return c <= 0.0031308 ? c * 12.92 : 1.055 * Math.pow(c, 1/2.4) - 0.055; }

    function hslToRGB(h, s, l) {
      s /= 100; l /= 100;
      const a = s * Math.min(l, 1 - l);
      const f = n => { const k = (n + h / 30) % 12; return l - a * Math.max(-1, Math.min(k - 3, 9 - k, 1)); };
      return [f(0), f(8), f(4)];
    }

    function rgbToHex(r, g, b) {
      return "#" + [r, g, b].map(c => Math.round(Math.max(0, Math.min(1, c)) * 255).toString(16).padStart(2, "0")).join("");
    }

    function nodeColour(labels, labelHues) {
      if (!labels || labels.length === 0) return { bg: "#2a2a2a", border: "#555" };
      const hues   = labels.map(l => labelHues[l] ?? 0);
      const blended = blendHues(hues);
      const [r1, g1, b1] = hslToRGB(blended, 55, 30);
      const [r2, g2, b2] = hslToRGB(blended, 65, 50);
      return {
        bg:     rgbToHex(toSRGB(toLinear(r1)), toSRGB(toLinear(g1)), toSRGB(toLinear(b1))),
        border: rgbToHex(toSRGB(toLinear(r2)), toSRGB(toLinear(g2)), toSRGB(toLinear(b2)))
      };
    }

    // -- table builder --

    function table(cols, rows, idCol) {
      const thStyle = "padding:5px 10px;text-align:left;border-bottom:1px solid #444;color:#aaa;font-size:11px;white-space:nowrap;";
      const tdStyle = "padding:4px 10px;border-bottom:1px solid #2a2a2a;font-size:11px;vertical-align:top;color:#e0e0e0;word-break:break-all;";
      const ths = cols.map(c => `<th style="${thStyle}">${c}</th>`).join("");
      const trs = rows.map((r, i) => {
        const rowId = idCol ? (r[idCol] ?? i) : i;
        return `<tr data-id="${rowId}">${cols.map(c => `<td style="${tdStyle}">${r[c] ?? ""}</td>`).join("")}</tr>`;
      }).join("");
      return `<table style="border-collapse:collapse;width:100%;"><thead><tr>${ths}</tr></thead><tbody>${trs}</tbody></table>`;
    }

    function highlightRow(container, id) {
      container.querySelectorAll("tr[data-id]").forEach(r => {
        r.style.background = r.dataset.id === String(id) ? "#1a3a1a" : "";
      });
      const target = container.querySelector(`tr[data-id="${id}"]`);
      if (target) target.scrollIntoView({ block: "nearest", behavior: "smooth" });
    }

    export function init(ctx, data) {
      ctx.root.style.cssText = "font-family:monospace;background:#111;color:#e0e0e0;";

      const escapeHtml = (s) => String(s)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#39;");

      const headerHtml = `
        <div style="padding:6px 8px;border-bottom:1px solid #333;">
          <div style="font-size:13px;color:#aaa;">${escapeHtml(data.title)}</div>
          ${data.description
            ? `<div style="font-size:11px;color:#888;margin-top:2px;font-style:italic;white-space:pre-line;">${escapeHtml(data.description)}</div>`
            : ""}
        </div>`;

      ctx.root.innerHTML = `
        ${headerHtml}
        <div style="display:flex;height:560px;gap:0;">

          <!-- graph panel -->
          <div style="flex:1.2;display:flex;flex-direction:column;border-right:1px solid #333;">
            <div style="display:flex;gap:4px;padding:6px;border-bottom:1px solid #333;">
              <button class="lbtn" data-layout="physics">Physics</button>
              <button class="lbtn" data-layout="hierarchical">Hierarchical</button>
              <button class="lbtn" data-layout="radial">Radial</button>
            </div>
            <div id="graph" style="flex:1;min-height:480px;width:100%;"></div>
          </div>

          <!-- elixir panel -->
          <div style="flex:1;display:flex;flex-direction:column;border-right:1px solid #333;">
            <div style="display:flex;gap:0;border-bottom:1px solid #333;">
              <button class="tbtn" data-tab="artefact" style="flex:1;">Artefact</button>
              <button class="tbtn" data-tab="nodes"    style="flex:1;">Nodes</button>
              <button class="tbtn" data-tab="rels"     style="flex:1;">Relationships</button>
            </div>
            <div id="tab-content" style="flex:1;overflow:auto;"></div>
          </div>

          <!-- cypher/json panel -->
          <div id="export-panel" style="flex:1;display:flex;flex-direction:column;">
            <div style="display:flex;gap:4px;padding:6px;border-bottom:1px solid #333;align-items:center;">
              <button class="cbtn" data-cypher="create">CREATE</button>
              <button class="cbtn" data-cypher="merge">MERGE</button>
              <button class="cbtn" data-cypher="json">JSON</button>
              <button class="cbtn" data-cypher="mermaid">MERMAID</button>
              <button id="collapse-btn" title="Collapse" style="margin-left:auto;">◀</button>
            </div>
            <pre id="cypher" style="flex:1;overflow:auto;margin:0;padding:10px;font-size:11px;line-height:1.6;color:#e0e0e0;white-space:pre-wrap;cursor:text;"></pre>
          </div>

        </div>
      `;

      const btnStyle = (el, active) => {
        el.style.cssText = `padding:4px 8px;border-radius:3px;cursor:pointer;font-family:monospace;font-size:11px;border:1px solid #555;background:${active ? "#3a5a3a" : "#222"};color:#e0e0e0;`;
      };

      const tabBtnStyle = (el, active) => {
        el.style.cssText = `padding:5px 4px;cursor:pointer;font-family:monospace;font-size:11px;border:none;border-bottom:2px solid ${active ? "#5a8a5a" : "transparent"};background:#111;color:${active ? "#e0e0e0" : "#777"};`;
      };

      // -- cypher toggle --
      let currentCypher = data.default;
      const cypherEl   = ctx.root.querySelector("#cypher");
      const cypherBtns = ctx.root.querySelectorAll(".cbtn");

      function renderCypher() {
        if (currentCypher === "create")        cypherEl.textContent = data.create_cypher;
        else if (currentCypher === "merge")    cypherEl.textContent = data.merge_cypher;
        else if (currentCypher === "mermaid")  cypherEl.textContent = data.mermaid;
        else                                   cypherEl.textContent = data.arrows_json;
        cypherBtns.forEach(b => btnStyle(b, b.dataset.cypher === currentCypher));
      }
      cypherBtns.forEach(b => b.addEventListener("click", () => { currentCypher = b.dataset.cypher; renderCypher(); }));
      renderCypher();

      // -- collapse export panel --
      const exportPanel  = ctx.root.querySelector("#export-panel");
      const collapseBtn  = ctx.root.querySelector("#collapse-btn");
      let exportCollapsed = false;

      btnStyle(collapseBtn, false);
      collapseBtn.addEventListener("click", () => {
        exportCollapsed = !exportCollapsed;
        exportPanel.style.flex    = exportCollapsed ? "0 0 32px" : "1";
        exportPanel.style.overflow = "hidden";
        collapseBtn.textContent   = exportCollapsed ? "▶" : "◀";
        btnStyle(collapseBtn, exportCollapsed);
        ctx.root.querySelector("#cypher").style.display = exportCollapsed ? "none" : "";
        ctx.root.querySelectorAll(".cbtn").forEach(b => b.style.display = exportCollapsed ? "none" : "");
      });

      // -- click to select all in pre elements --
      function selectAll(el) {
        const range = document.createRange();
        range.selectNodeContents(el);
        const sel = window.getSelection();
        sel.removeAllRanges();
        sel.addRange(range);
      }
      ctx.root.querySelectorAll("pre").forEach(pre => {
        pre.addEventListener("click", () => selectAll(pre));
      });

      // -- elixir tabs --
      const TABS = {
        artefact: () => table(["key", "value"], data.artefact_rows, null),
        nodes:    () => table(["id", "uuid", "labels", "properties"], data.nodes_rows, "id"),
        rels:     () => table(["from", "type", "to", "properties"], data.rels_rows, "idx")
      };

      let currentTab = "artefact";
      let pendingHighlight = null;
      const tabContent = ctx.root.querySelector("#tab-content");
      const tabBtns    = ctx.root.querySelectorAll(".tbtn");

      function renderTab(tab) {
        currentTab = tab;
        tabContent.innerHTML = TABS[tab]();
        tabBtns.forEach(b => tabBtnStyle(b, b.dataset.tab === tab));
        if (pendingHighlight) {
          highlightRow(tabContent, pendingHighlight);
          pendingHighlight = null;
        }
      }
      tabBtns.forEach(b => b.addEventListener("click", () => renderTab(b.dataset.tab)));
      renderTab("artefact");

      // -- layout buttons --
      let network = null;
      let currentLayout = "physics";
      const layoutBtns = ctx.root.querySelectorAll(".lbtn");

      function applyLayout(name) {
        currentLayout = name;
        layoutBtns.forEach(b => btnStyle(b, b.dataset.layout === name));
        if (!network) return;
        const cfg = LAYOUTS[name];
        network.setOptions({ physics: cfg.physics, layout: cfg.layout });
        if (cfg.physics.enabled !== false) network.stabilize();
      }
      layoutBtns.forEach(b => b.addEventListener("click", () => applyLayout(b.dataset.layout)));
      layoutBtns.forEach(b => btnStyle(b, b.dataset.layout === currentLayout));

      // -- vis-network --
      loadVis()
        .catch(err => {
          ctx.root.querySelector("#graph").innerHTML = `<div style="padding:20px;color:#f88;">Failed to load vis-network: ${err}</div>`;
        })
        .then(() => {
          if (!window.vis) return;
          const labelHues = buildLabelHues(data.nodes);

          const nodes = new vis.DataSet(data.nodes.map(n => {
            const { bg, border } = nodeColour(n.labels, labelHues);
            return {
              ...n,
              shape: "ellipse",
              color: { background: bg, border: border, highlight: { background: border, border: "#fff" } },
              font:  { color: "#e0e0e0", size: 13, face: "monospace" }
            };
          }));

          const edges = new vis.DataSet(data.edges.map(e => ({
            ...e,
            color: { color: "#666", highlight: "#aaa" },
            font:  { color: "#ddd", size: 11, face: "monospace", align: "middle", background: "#1a1a1a", strokeWidth: 0 },
            smooth: { type: "curvedCW", roundness: 0.15 }
          })));

          const cfg = LAYOUTS[currentLayout];
          network = new vis.Network(
            ctx.root.querySelector("#graph"),
            { nodes, edges },
            { physics: cfg.physics, layout: cfg.layout, interaction: { hover: true, tooltipDelay: 150 } }
          );

          network.on("selectNode", ({ nodes: selected }) => {
            if (!selected.length) return;
            pendingHighlight = selected[0];
            renderTab("nodes");
          });

          network.on("selectEdge", ({ edges: selected, nodes: selectedNodes }) => {
            if (!selected.length) return;
            if (selectedNodes && selectedNodes.length > 0) return;
            pendingHighlight = selected[0];
            renderTab("rels");
          });

          network.on("deselectNode", () => {
            if (currentTab === "nodes") tabContent.querySelectorAll("tr[data-id]").forEach(r => r.style.background = "");
          });

          network.on("deselectEdge", () => {
            if (currentTab === "rels") tabContent.querySelectorAll("tr[data-id]").forEach(r => r.style.background = "");
          });
        });
    }

    function loadVis() {
      if (window.vis) return Promise.resolve();
      return new Promise((resolve, reject) => {
        const s = document.createElement("script");
        s.src = VIS_CDN;
        s.onload = resolve;
        s.onerror = reject;
        document.head.appendChild(s);
      });
    }
    """
  end
end
