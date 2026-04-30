<!--
SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
SPDX-License-Identifier: MIT
-->

# Drafts — Artefact.combine convenience wrapper

Drafts only. Branch `10-convenience-combine`. Per `.claude/settings.json` no
`git commit / push / add` was run.

---

## Draft commit message — `artefact`

```
feat(artefact): pipeline-friendly combine/3

Artefact.combine(heart, other, opts \\ []) is a convenience wrapper around
Artefact.Binding.find/2 + Artefact.harmonise/4 designed for pipelines —
the heart flows through the pipe as the first argument:

    me_knowing
    |> Artefact.combine(me_valuing)
    |> Artefact.combine(me_being)
    |> Artefact.combine(me_doing, title: "MeMind", description: "Mind of Me")

Bindings are auto-found via shared uuids; opts pass through to harmonise
for :title and :base_label overrides. :description is patched onto the
result (since harmonise itself does not yet honour :description in opts).
Raises MatchError when there are no shared nodes.

Provenance: :harmonised, with the calling module. Combine is sugar over
harmonise — the underlying operation IS a harmonise, so the trace stays
honest. The convenience is the binding-find and the heart-first arg order.
```

## Notes for the next yarn

- **harmonise/compose could honour :description in opts.** Right now combine
  patches it post-hoc. If you later extend `do_harmonise/5` and `do_compose/4`
  to read `:description` from opts and pass it into `build/1`, combine can
  drop the patch and just delegate. Worth a small follow-up issue, not part
  of this branch.

- **Portmanteau base_label grows.** Each combine step concatenates the
  heart and other base_labels. Through a five-step pipeline that becomes a
  long word like `KnowingValuingBeingKnowingMoreDoing`. The final step's
  opts can rename it (`base_label: "MeMind"`), which is what the example
  in the docstring shows. Worth a note in any usage example.

- **No `combine!` variant.** combine raises MatchError on no bindings, which
  matches the user's original livebook helper. If we later want a
  `combine_with/3` that explicitly accepts `inject:` bindings, that's a new
  function — keep combine as the simple shared-uuid case.

---

*Held in the commons.*
