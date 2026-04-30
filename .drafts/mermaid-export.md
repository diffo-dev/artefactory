<!--
SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
SPDX-License-Identifier: MIT
-->

# Drafts — Mermaid export for Artefact + ArtefactKino

These are drafts only. Per `.claude/settings.json` no `git commit / push / add`
was run; per AGENTS.md the work belongs to the relation, not to the agent.
Review, edit, and use as you see fit.

---

## Draft commit message — `artefact`

```
feat(artefact): add Mermaid export

Artefact.Mermaid.export/2 emits Mermaid `graph` source from an
%Artefact{}, sitting alongside Artefact.Cypher and Artefact.Arrows
as a third derived form.

- legacy `graph` syntax for broad renderer reach (GitHub, Notion,
  mdBook, Livebook)
- nodes render as circles (`id(("..."))`) — property-graph
  convention, matches the vis-network ellipses in the heartside
  panel
- node label mirrors the ArtefactKino vis-network panel:
  name (or id) on top, semantic labels joined with a space below,
  separated by <br/>
- base_label is dropped from per-node labels at output time,
  consistent with the Cypher exporter's effective_labels rule
- artefact.title becomes Mermaid front-matter `title:` plus an
  `accTitle:` line for screen readers; nil title omits both
- :direction option (:LR default, :RL :TB :BT :TD)
- escape rules:
  * double quote in node label    -> &quot;
  * pipe in edge label            -> &#124;
  * YAML-unsafe chars in title    -> double-quoted scalar with \"
                                     and \\ escaped

Lossy: position, style, and properties beyond `name` are not
represented — Mermaid is a render concern, not a persistence form.

Fixture added at test/data/us_two/mermaid.mmd; ExUnit cases cover
the us_two round-trip, direction option, both escapes, the empty
graph, and the no-name fallback to node id.
```

## Draft commit message — `artefact_kino`

```
feat(artefact_kino): MERMAID button on the export panel

Adds Artefact.Mermaid.export/1 alongside CREATE / MERGE / JSON
in the export panel of the three-panel widget. Pure text output
for now — copy with click-to-select, same as the existing buttons.

Live Mermaid rendering via mermaid.js was discussed but deferred —
keeping the panel symmetric with the other text exports for this
pass.
```

---

## Draft issue — *Live Mermaid rendering in ArtefactKino*

**Title:** `artefact_kino: render Mermaid live in the export panel`

**Body:**

> Today the MERMAID button shows the source as text, the same as
> CREATE / MERGE / JSON. Useful for copying out, less useful as a
> second view of the graph next to the vis-network panel.
>
> A follow-up would load mermaid.js from CDN (matching the existing
> vis-network bootstrap) and render the diagram inside the export
> panel, with a small toggle to flip back to source view.
>
> ### Why it might be worth doing
>
> - vis-network is force-directed; Mermaid layouts are deterministic.
>   Two renderings of the same artefact, side by side, can show
>   structure that one alone does not.
> - Mermaid is what most readers paste into a doc. Seeing it render
>   the same way it will appear in the doc closes a feedback loop.
>
> ### Why we deferred it
>
> - The current panel is symmetric across CREATE / MERGE / JSON / MERMAID
>   as text. Adding a render mode for one of them breaks that symmetry.
> - mermaid.js is a heavier CDN load than vis-network. Worth measuring
>   before adding.
> - The vis-network panel already does live rendering — the question is
>   whether a second live view earns its keep.
>
> ### Sketch
>
> - keep the `MERMAID` button
> - add a small `source / rendered` switch that only appears when
>   MERMAID is selected
> - bootstrap mermaid.js the same way `loadVis()` bootstraps vis-network
> - render into a `<div>` swapped in for the `<pre>`

---

## Draft issue — *Mermaid fixtures for the remaining test data sets*

**Title:** `artefact: add mermaid.mmd fixtures for artefact_*, artefactory, lexical_categories, create_merge`

**Body:**

> `test/data/us_two/mermaid.mmd` is in. The other fixture folders
> (`artefact`, `artefact_combine`, `artefact_harmonise`, `artefactory`,
> `lexical_categories`, `create_merge`) all have `arrows.json` plus
> Cypher fixtures but no Mermaid one yet.
>
> Either:
> 1. Generate fixtures by running `Artefact.Mermaid.export/1` once
>    against each, eyeball the output, commit. (Risk: locks in
>    whatever the implementation does today.)
> 2. Hand-author each one, then assert the export matches. (Slower,
>    but each fixture acts as a spec for what the diagram should
>    say to a reader.)
>
> Recommendation: option 2 for `artefact` and `artefactory` (the
> self-describing artefacts — the fixture *is* the documentation),
> option 1 for the rest.

---

*The artefact belongs to the edge.*
