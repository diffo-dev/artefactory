<!--
SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
SPDX-License-Identifier: MIT
-->

# Drafts — Artefact.graft convenience wrapper

Drafts only. Branch corresponding to issue #20. Per `.claude/settings.json`
no `git commit / push / add` was run.

---

## Draft commit message — `artefact`

```
feat(artefact): pipeline-friendly graft/3

Artefact.graft(left, args, opts \\ []) is a convenience wrapper for
extending an existing artefact with new nodes and relationships
declared inline (same shape as Artefact.new accepts) — without
constructing a second artefact:

    our_shells_artefact
    |> Artefact.combine(our_manifesto_artefact)
    |> Artefact.graft(args, title: "Our Shells and Manifesto",
         description: "Our Shells and Manifesto shape our Association Knowing.")

Args is a keyword list with :nodes and :relationships, identical in
shape to Artefact.new's inline form — except every node entry MUST
carry an explicit :uuid. There is no auto-find: the uuid is the
binding.

Each args node either:
- Binds to an existing left node (uuid present in left.graph.nodes).
  Labels are unioned, properties merged with left winning conflicts,
  position untouched. Same primary-wins pattern as do_harmonise.
- Adds a new node (uuid not in left). Receives a fresh sequential id
  continuing left's offset.

Args relationships use args-local atom keys, like Artefact.new. Every
key referenced by a relationship must be declared in args.nodes;
otherwise ArgumentError. Relationship dedupe with the existing left
relationships uses the same {from_id, type, to_id} key trick already
used by harmonise and compose, with left winning on properties.

opts honours :title and :description only — both name the result.
:base_label is NOT honoured; the result keeps left.base_label.

Provenance: :grafted with the calling module, a summary of left, and
right: %{title: opts[:title], description: opts[:description]} — the
result's name as provided. Distinct source from :composed and
:harmonised.

Test fixture lives at test/support/our_shells_fixture.ex, adapted from
diffo-dev/.github/livebook/shells.livemd. Loaded by test_helper.exs
via Code.require_file (no mix.exs touch).
```

## Notes for the next yarn

- **No find, only bind.** This was the key spec clarification — combine
  uses Binding.find/2 to discover shared uuids automatically. Graft
  refuses to do that. The author writes the uuid; the uuid is the
  contract. Easier to read what a graft step is doing, harder to fool
  yourself with accidental shared uuids.

- **Bind-only nodes carrying labels/properties get merged left-wins.**
  We considered three options (silently drop, raise, merge). Settled on
  merge with left winning, matching the do_harmonise primary-wins
  pattern. So passing extra labels in a bind-only entry IS valid — it
  unions them in. Useful when grafting introduces a new perspective on
  an already-known node.

- **No :base_label override.** Graft can't change the identity-shape
  of left. If you want a new base_label, do the work in a fresh
  artefact and combine instead. We deliberately tightened opts to
  :title and :description only.

- **Provenance shape is asymmetric.** Left gets the full summary
  (title, base_label, uuid, provenance). Right just gets {title,
  description} — what was provided in opts. There's no "right artefact"
  to summarise; args is a graph fragment, not a named thing. If we
  ever want to capture the args graph in provenance (node count,
  uuid lists), that's a separate decision.

- **`mix format` and `mix test` not run from the agent sandbox** —
  Elixir/mix isn't installed there. Run locally:

      cd artefact
      mix format
      mix test

  Tests added: 17 new tests across 5 describe blocks
  ("happy path with OurShells fixture", "opts behaviour",
  "bind-only merge semantics", "relationship dedupe", "guards").

- **Test fixture as `Artefact.new` form, not Arrows JSON.** Per the
  yarn — fixtures live at `test/support/our_shells_fixture.ex`.
  `mix.exs` configures `elixirc_paths: ["lib", "test/support"]` for
  the `:test` env so the fixture compiles automatically (and avoids
  the `:test_load_filters` warning that scans `test/` for stray
  non-`*_test.exs` files). Standard Phoenix-style pattern; future
  fixtures drop into the same dir.

---

*Held in the commons.*
