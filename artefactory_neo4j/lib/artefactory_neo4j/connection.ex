# SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule ArtefactoryNeo4j.Connection do
  @moduledoc """
  A supervised Bolty connection to a Neo4j instance.

  Wrap this in a supervision tree to maintain a persistent, restarting
  connection. Each entity (Me, Mob, native You) uses the same connection
  to the shared Neo4j instance, routing to its own named database via `db:`.
  """
  use GenServer

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def conn(name \\ __MODULE__) do
    GenServer.call(name, :conn)
  end

  @impl true
  def init(opts) do
    {:ok, conn} = ArtefactoryNeo4j.connect(opts)
    {:ok, %{conn: conn, opts: opts}}
  end

  @impl true
  def handle_call(:conn, _from, state) do
    {:reply, state.conn, state}
  end
end
