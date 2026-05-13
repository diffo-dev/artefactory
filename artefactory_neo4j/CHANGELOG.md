<!--
SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
SPDX-License-Identifier: MIT
-->

# Changelog

## 0.3.0 — 2026-05-13

### Tooling

- Igniter task `mix artefactory_neo4j.install` — preferred installation method; configures Bolty in `runtime.exs`, adds `Bolty` to the supervision tree, and installs the `artefact` dependency automatically.
- `usage-rules.md` — consumer-facing AI agent guidance, compatible with the `usage_rules` hex package ecosystem.
- `usage_rules` dev dependency added.

### Dependencies

- Bumps `artefact` requirement to `~> 0.3.0`.

## 0.1.0 — 2026-04-21

Initial release.

- `ArtefactoryNeo4j.connect/1` — open a Bolty connection to a Neo4j instance
- `ArtefactoryNeo4j.write/3` — persist an `%Artefact{}` via parameterised MERGE
- `ArtefactoryNeo4j.fetch/3` — retrieve nodes by uuid
- `ArtefactoryNeo4j.create_database/2`, `drop_database/2`, `stop_database/2`, `start_database/2` — DozerDB database lifecycle
- `ArtefactoryNeo4j.Connection` — supervised GenServer wrapping a Bolty connection
- `ArtefactoryNeo4j.Util` — case conversion and validation at the Neo4j boundary
- Automatic `snake_case → camelCase` conversion for property keys at write; reversed on fetch
- Automatic `snake_case → kebab-case` conversion for database names
