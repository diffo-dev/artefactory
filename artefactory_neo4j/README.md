<!--
SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
SPDX-License-Identifier: MIT
-->

# ArtefactoryNeo4j

Neo4j persistence for [`Artefact`](https://hex.pm/packages/artefact) — read, write, and database lifecycle via [Bolty](https://hex.pm/packages/bolty) and [DozerDB](https://dozerdb.org).

Part of the [Artefactory](https://github.com/diffo-dev/artefactory) monorepo.

## What it does

Persists `%Artefact{}` structs into a Neo4j graph database. Each entity (Me, a Mob, a native You) gets its own named database. A single Bolt connection routes to any of them via the `db:` option.

Named databases on Neo4j Community Edition require **DozerDB** — a free plugin that adds enterprise multi-database features. See [Local dev](#local-dev) below.

## Installation

The preferred way to install ArtefactoryNeo4j is via Igniter:

```bash
mix igniter.install artefactory_neo4j
```

This automatically configures Bolty in `runtime.exs`, adds `Bolty` to the supervision tree, and installs the `artefact` dependency.

Or add the dependency manually:

```elixir
def deps do
  [
    {:artefactory_neo4j, "~> 0.1"}
  ]
end
```

## Usage

```elixir
{:ok, conn} = ArtefactoryNeo4j.connect(
  uri: "bolt://localhost:7470",
  auth: [username: "neo4j", password: "password"]
)

# Create a named database (DozerDB feature)
:ok = ArtefactoryNeo4j.create_database(conn, "matt_me")

# Write an artefact
:ok = ArtefactoryNeo4j.write(conn, artefact, db: "matt_me")

# Fetch nodes by uuid
{:ok, rows} = ArtefactoryNeo4j.fetch(conn, uuid, db: "matt_me")
```

Database names follow Elixir convention — `snake_case` atom or string. They are converted to Neo4j `kebab-case` automatically at the boundary (`"matt_me"` → `"matt-me"`). Property keys are similarly converted `snake_case → camelCase` on write and back on fetch.

## Supervised connection

Use `ArtefactoryNeo4j.Connection` to hold a Bolty connection in a supervision tree:

```elixir
children = [
  {ArtefactoryNeo4j.Connection,
   uri: "bolt://localhost:7470",
   auth: [username: "neo4j", password: "password"],
   name: :my_conn}
]

# Retrieve the connection anywhere
conn = ArtefactoryNeo4j.Connection.conn(:my_conn)
```

## Database lifecycle

These commands require DozerDB — they will fail on plain Neo4j Community.

```elixir
ArtefactoryNeo4j.create_database(conn, "matt_me")
ArtefactoryNeo4j.drop_database(conn, "matt_me")
ArtefactoryNeo4j.stop_database(conn, "matt_me")
ArtefactoryNeo4j.start_database(conn, "matt_me")
```

## Neo4j conventions

`artefactory_neo4j` is the boundary between Elixir country and Neo4j country.
All naming convention translation happens here — callers stay in Elixir convention throughout.

| Thing              | Elixir (caller)      | Neo4j               |
|--------------------|----------------------|---------------------|
| Database names     | `snake_case` string/atom | `kebab-case` string |
| Property keys      | `snake_case` string  | `camelCase` string  |
| Node labels        | `PascalCase` string  | `PascalCase` string |
| Relationship types | `MACRO_CASE` string  | `MACRO_CASE` string |

Node labels and relationship types are already in Neo4j convention in `%Artefact{}` structs — they pass through unchanged.

## Local dev

DozerDB runs as a drop-in replacement for Neo4j Community 5.26.3. The easiest path is Docker — a `docker-compose.yml` is provided at the `artefactory` repo root.

```sh
cd artefactory
cp .env.example .env        # set NEO4J_PASSWORD
docker compose up -d
```

Ports:
- `7474` — Neo4j Browser / HTTP (Chrome or Firefox; Safari needs 7473)
- `7473` — Neo4j Browser / HTTPS
- `7470` — Bolt direct (`bolt://`) — use this for connections
- `7471` — Bolt with routing (`neo4j://`)

When connecting in the Neo4j Browser, set the connection URL to `bolt://localhost:7470` (the browser defaults to 7687).

## Running tests

Integration tests require a live DozerDB instance:

```sh
mix test --include integration
```

Excluded by default (`mix test` runs only unit tests).

## Licence

MIT — see [LICENSES/MIT.txt](LICENSES/MIT.txt). © 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>.
