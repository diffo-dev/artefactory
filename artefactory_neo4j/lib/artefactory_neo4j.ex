# SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule ArtefactoryNeo4j do
  @moduledoc """
  Neo4j persistence for `%Artefact{}` structs.

  Provides read/write access to a named Neo4j database (via Bolty and DozerDB)
  and database lifecycle management — create, drop, stop, start.

  Each entity (Me, Mob, a native You) has its own named database. The `db:`
  option on every query routes to the correct database without needing separate
  connections.

  ## Usage

      {:ok, conn} = ArtefactoryNeo4j.connect(uri: "bolt://localhost:7688",
                                              auth: [username: "neo4j", password: "password"])

      :ok = ArtefactoryNeo4j.create_database(conn, "matt_artefactory")

      :ok = ArtefactoryNeo4j.write(conn, artefact, db: "matt_artefactory")

      {:ok, artefact} = ArtefactoryNeo4j.fetch(conn, uuid, db: "matt_artefactory")
  """

  @doc """
  Open a Bolty connection to the Neo4j instance.
  """
  def connect(opts) do
    Bolty.start_link(opts)
  end

  @doc """
  Write an artefact to the given database using parameterised MERGE.

  The `db:` name is Elixir country — `snake_case` atom or string, converted
  to Neo4j `kebab-case` automatically. Property keys are converted from
  `snake_case` to `camelCase` at the boundary.
  """
  def write(conn, %Artefact{} = artefact, opts \\ []) do
    db = opts |> Keyword.fetch!(:db) |> ArtefactoryNeo4j.Util.to_database_name()
    {cypher, params} = artefact |> neo4j_properties() |> Artefact.Cypher.merge_params()

    case Bolty.query(conn, cypher, params, db: db) do
      {:ok, _} -> :ok
      {:error, _} = e -> e
    end
  end

  @doc """
  Fetch nodes matching a uuid from the given database.

  The `db:` name follows Elixir convention — converted to Neo4j `kebab-case`
  automatically. Returns `{:ok, rows}` where each row is a map of
  `field => %Bolty.Types.Node{}` with property keys in `snake_case`.
  """
  def fetch(conn, uuid, opts \\ []) do
    db = opts |> Keyword.fetch!(:db) |> ArtefactoryNeo4j.Util.to_database_name()

    case Bolty.query(conn, "MATCH (n {uuid: $uuid}) RETURN n", %{"uuid" => uuid}, db: db) do
      {:ok, %Bolty.Response{results: rows}} -> {:ok, Enum.map(rows, &from_neo4j_row/1)}
      {:error, _} = e -> e
    end
  end

  # -- database lifecycle (DozerDB) --

  @doc """
  Create a named database (DozerDB feature — not available on plain Community).
  Name is Elixir country (`snake_case` atom or string) — converted to `kebab-case` automatically.
  """
  def create_database(conn, name) do
    db = ArtefactoryNeo4j.Util.to_database_name(name)

    case Bolty.query(conn, "CREATE DATABASE `#{db}` IF NOT EXISTS", %{}, db: "system") do
      {:ok, _} -> :ok
      {:error, _} = e -> e
    end
  end

  @doc "Drop a named database. Name follows Elixir convention — converted to `kebab-case` automatically."
  def drop_database(conn, name) do
    db = ArtefactoryNeo4j.Util.to_database_name(name)

    case Bolty.query(conn, "DROP DATABASE `#{db}` IF EXISTS", %{}, db: "system") do
      {:ok, _} -> :ok
      {:error, _} = e -> e
    end
  end

  @doc "Stop a named database. Name follows Elixir convention — converted to `kebab-case` automatically."
  def stop_database(conn, name) do
    db = ArtefactoryNeo4j.Util.to_database_name(name)

    case Bolty.query(conn, "STOP DATABASE `#{db}`", %{}, db: "system") do
      {:ok, _} -> :ok
      {:error, _} = e -> e
    end
  end

  @doc "Start a named database. Name follows Elixir convention — converted to `kebab-case` automatically."
  def start_database(conn, name) do
    db = ArtefactoryNeo4j.Util.to_database_name(name)

    case Bolty.query(conn, "START DATABASE `#{db}`", %{}, db: "system") do
      {:ok, _} -> :ok
      {:error, _} = e -> e
    end
  end

  # -- boundary conversion helpers --

  # Convert all node property keys to camelCase before handing to Cypher generator.
  defp neo4j_properties(%Artefact{graph: graph} = artefact) do
    nodes =
      Enum.map(graph.nodes, fn node ->
        %{node | properties: ArtefactoryNeo4j.Util.properties_to_neo4j(node.properties)}
      end)

    %{artefact | graph: %{graph | nodes: nodes}}
  end

  # Convert a single result row — property keys on returned Bolty nodes back to snake_case.
  defp from_neo4j_row(row) do
    Map.new(row, fn
      {field, %Bolty.Types.Node{properties: props} = node} ->
        {field, %{node | properties: ArtefactoryNeo4j.Util.properties_from_neo4j(props)}}

      other ->
        other
    end)
  end
end
