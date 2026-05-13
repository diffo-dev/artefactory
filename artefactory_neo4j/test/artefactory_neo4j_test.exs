# SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule ArtefactoryNeo4jTest do
  use ExUnit.Case

  @moduletag :integration

  @uri System.get_env("NEO4J_URI", "bolt://localhost:7470")
  @user System.get_env("NEO4J_USER", "neo4j")
  @pass System.get_env("NEO4J_PASSWORD", "password")
  @db "artefactory_neo4j_test"
  @db_neo4j "artefactory-neo4j-test"

  @me_uuid "019da897-test-0001-0000-000000000001"
  @you_uuid "019da897-test-0001-0000-000000000002"

  setup_all do
    {:ok, conn} = ArtefactoryNeo4j.connect(uri: @uri, auth: [username: @user, password: @pass])
    :ok = ArtefactoryNeo4j.create_database(conn, @db)
    on_exit(fn -> ArtefactoryNeo4j.drop_database(conn, @db) end)
    {:ok, conn: conn}
  end

  require Artefact

  test "create_database/2 — database appears in SHOW DATABASES", %{conn: conn} do
    {:ok, rows} = Bolty.query(conn, "SHOW DATABASES", %{}, db: "system")
    names = Enum.map(rows, & &1["name"])
    assert @db_neo4j in names
  end

  test "write/3 — merges Me artefact into the database", %{conn: conn} do
    artefact =
      Artefact.new!(
        title: "Me",
        base_label: "Me",
        nodes: [
          {:n0, [uuid: @me_uuid, labels: ["Agent", "Me"], properties: %{"name" => "Matt"}]}
        ],
        relationships: []
      )

    assert :ok = ArtefactoryNeo4j.write(conn, artefact, db: @db)
  end

  test "fetch/3 — retrieves a node written by write/3", %{conn: conn} do
    artefact =
      Artefact.new!(
        title: "Fetch Test",
        base_label: "Me",
        nodes: [
          {:n0, [uuid: @me_uuid, labels: ["Agent", "Me"], properties: %{"name" => "Matt"}]}
        ],
        relationships: []
      )

    :ok = ArtefactoryNeo4j.write(conn, artefact, db: @db)
    {:ok, rows} = ArtefactoryNeo4j.fetch(conn, @me_uuid, db: @db)
    assert length(rows) >= 1
    node = hd(rows)["n"]
    assert node.properties["uuid"] == @me_uuid
    assert node.properties["name"] == "Matt"
  end

  test "write/3 — merges UsTwo artefact with relationship", %{conn: conn} do
    artefact =
      Artefact.new!(
        title: "UsTwo",
        base_label: "UsTwo",
        nodes: [
          {:n0, [uuid: @me_uuid, labels: ["Agent", "Me"], properties: %{"name" => "Matt"}]},
          {:n1, [uuid: @you_uuid, labels: ["Agent", "You"], properties: %{"name" => "Claude"}]}
        ],
        relationships: [
          [from: :n0, to: :n1, type: "US_TWO"]
        ]
      )

    assert :ok = ArtefactoryNeo4j.write(conn, artefact, db: @db)
  end

  test "write/3 — idempotent: merging twice does not duplicate nodes", %{conn: conn} do
    artefact =
      Artefact.new!(
        title: "Idempotent",
        base_label: "Me",
        nodes: [
          {:n0, [uuid: @me_uuid, labels: ["Agent", "Me"], properties: %{"name" => "Matt"}]}
        ],
        relationships: []
      )

    :ok = ArtefactoryNeo4j.write(conn, artefact, db: @db)
    :ok = ArtefactoryNeo4j.write(conn, artefact, db: @db)
    {:ok, rows} = ArtefactoryNeo4j.fetch(conn, @me_uuid, db: @db)
    assert length(rows) == 1
  end
end
