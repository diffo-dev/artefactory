<!--
SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
SPDX-License-Identifier: MIT
-->

# Rules for working with ArtefactoryNeo4j

## Installation

The preferred way to add ArtefactoryNeo4j to a project is via Igniter:

```bash
mix igniter.install artefactory_neo4j
```

This automatically: configures Bolty connection details in `runtime.exs`, adds `Bolty` to the supervision tree, and installs the `artefact` dependency. If your project does not use Igniter, do these steps manually and run `mix deps.get`.

## What ArtefactoryNeo4j is

ArtefactoryNeo4j persists `%Artefact{}` structs to a Neo4j-compatible graph database via the Bolt protocol (Bolty driver). It is a persistence boundary for knowledge graph fragments — not an ORM, not a data layer, not a query builder. You bring the artefact; it handles the Cypher.

Multi-database support (one named database per entity — Me, Mob, a You) requires DozerDB or Neo4j Enterprise. It is not available on Neo4j Community Edition.

## Connection model

ArtefactoryNeo4j uses **direct Bolty connections**, not a named supervised pool. There is no global `Bolt` process, no `Repo` module, no application-level config key to set.

```elixir
{:ok, conn} = ArtefactoryNeo4j.connect(
  uri: "bolt://localhost:7688",
  auth: [username: "neo4j", password: "password"]
)
```

This is different from `ash_neo4j`, which starts a named `Bolt` process in the supervision tree and reads from `config :bolty, Bolt, ...`. Do not carry that pattern here.

## The `db:` option is required on every query

Every `write/3` and `fetch/3` call requires a `db:` option that names the target database. There is no default database.

```elixir
:ok = ArtefactoryNeo4j.write(conn, artefact, db: "matt_artefactory")
{:ok, rows} = ArtefactoryNeo4j.fetch(conn, uuid, db: "matt_artefactory")
```

Omitting `db:` raises `KeyError` — it is a required key, not optional.

## Database naming convention

Database names follow Elixir convention in code — `snake_case` atom or string. ArtefactoryNeo4j converts them to Neo4j `kebab-case` automatically:

```elixir
# These are equivalent
ArtefactoryNeo4j.write(conn, artefact, db: :matt_artefactory)
ArtefactoryNeo4j.write(conn, artefact, db: "matt_artefactory")
# Both write to Neo4j database "matt-artefactory"
```

Do not pass a `kebab-case` string directly — it will be double-converted.

## Property naming convention

Node property keys are converted at the Bolt boundary automatically:

- Elixir `snake_case` → Neo4j `camelCase` on write
- Neo4j `camelCase` → Elixir `snake_case` on read

```elixir
# In Elixir: %{"first_name" => "Matt"}
# In Neo4j:  {firstName: "Matt"}
```

Do not manually convert property keys before passing them to ArtefactoryNeo4j, and do not expect `camelCase` keys in results.

## write/3 uses MERGE — it is idempotent

`write/3` generates parameterised `MERGE` Cypher, not `CREATE`. Calling it twice with the same artefact will update in place rather than create duplicate nodes. This is intentional — artefacts are knowledge fragments, and re-writing the same knowledge should be safe.

## Connection pooling (DBConnection)

Bolty is built on [DBConnection](https://hexdocs.pm/db_connection), which provides connection pooling. The `connect/1` call starts a pool — `pool_size:` controls how many concurrent Bolt connections it maintains. Tune this based on load in production.

```elixir
{:ok, conn} = ArtefactoryNeo4j.connect(
  uri: "bolt://localhost:7688",
  auth: [username: "neo4j", password: "password"],
  pool_size: 10
)
```

ArtefactoryNeo4j does not currently expose transactions. If you need transactional writes, use `Bolty.transaction/4` directly on the connection returned by `connect/1` — see the Bolty documentation.

## Database lifecycle (DozerDB)

Named databases are a DozerDB / Neo4j Enterprise feature. Each entity in the diffo model has its own named database:

```elixir
:ok = ArtefactoryNeo4j.create_database(conn, "matt_artefactory")
:ok = ArtefactoryNeo4j.write(conn, artefact, db: "matt_artefactory")

# Lifecycle
:ok = ArtefactoryNeo4j.stop_database(conn, "matt_artefactory")
:ok = ArtefactoryNeo4j.start_database(conn, "matt_artefactory")
:ok = ArtefactoryNeo4j.drop_database(conn, "matt_artefactory")
```

All lifecycle operations route through the `system` database internally — you do not need to manage that yourself.

`create_database/2` uses `IF NOT EXISTS` — safe to call repeatedly.
