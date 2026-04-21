# SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule ArtefactoryNeo4j.Util do
  @moduledoc """
  Case conversion and validation for the Neo4j boundary.

  Artefactory is Elixir country — names follow Elixir conventions internally.
  At the Neo4j boundary, `ArtefactoryNeo4j` adapts to Neo4j conventions:

  | Thing              | Elixir (artefactory) | Neo4j               |
  |--------------------|----------------------|---------------------|
  | Property keys      | `snake_case` string  | `camelCase` string  |
  | Node labels        | `PascalCase` string  | `PascalCase` string |
  | Relationship types | `MACRO_CASE` string  | `MACRO_CASE` string |
  | Database names     | `snake_case` atom/string | `kebab-case` string |

  Node labels and relationship types are already in Neo4j convention in
  `%Artefact{}` structs — they pass through unchanged.

  Property keys and database names are converted at the boundary.

  Adapted from `AshNeo4j.Util` by diffo-dev.
  """

  @doc """
  Converts a `snake_case` string or atom to Neo4j `camelCase` string.
  Used for property keys at the write boundary.

  ## Examples

      iex> ArtefactoryNeo4j.Util.to_camel_case("first_name")
      "firstName"
      iex> ArtefactoryNeo4j.Util.to_camel_case("name")
      "name"
      iex> ArtefactoryNeo4j.Util.to_camel_case(:first_name)
      "firstName"
  """
  def to_camel_case(value) when is_atom(value), do: to_camel_case(Atom.to_string(value))

  def to_camel_case(value) when is_binary(value) do
    [head | tail] = String.split(value, "_")
    head <> Enum.map_join(tail, "", &String.capitalize/1)
  end

  @doc """
  Converts a Neo4j `camelCase` string to Elixir `snake_case` string.
  Used for property keys at the read boundary.

  ## Examples

      iex> ArtefactoryNeo4j.Util.to_snake_case("firstName")
      "first_name"
      iex> ArtefactoryNeo4j.Util.to_snake_case("name")
      "name"
  """
  def to_snake_case(value) when is_binary(value) do
    value
    |> String.replace(~r/([A-Z])/, "_\\1")
    |> String.downcase()
    |> String.trim_leading("_")
  end

  @doc """
  Converts a `snake_case` atom or string to a valid Neo4j database name (`kebab-case`).
  Neo4j database names may contain ASCII letters, numbers, dots, and dashes — not underscores.

  ## Examples

      iex> ArtefactoryNeo4j.Util.to_database_name(:matt_me)
      "matt-me"
      iex> ArtefactoryNeo4j.Util.to_database_name("diffo_mob")
      "diffo-mob"
      iex> ArtefactoryNeo4j.Util.to_database_name("already-fine")
      "already-fine"
  """
  def to_database_name(value) when is_atom(value), do: to_database_name(Atom.to_string(value))

  def to_database_name(value) when is_binary(value) do
    String.replace(value, "_", "-")
  end

  @doc """
  Converts property map keys from Elixir `snake_case` to Neo4j `camelCase`.
  Applied to `%Artefact.Node{}` property maps at the write boundary.

  ## Examples

      iex> ArtefactoryNeo4j.Util.properties_to_neo4j(%{"first_name" => "Matt", "age" => 42})
      %{"firstName" => "Matt", "age" => 42}
  """
  def properties_to_neo4j(props) when is_map(props) do
    Map.new(props, fn {k, v} -> {to_camel_case(k), v} end)
  end

  @doc """
  Converts property map keys from Neo4j `camelCase` back to Elixir `snake_case`.
  Applied to properties returned by `fetch/3`.

  ## Examples

      iex> ArtefactoryNeo4j.Util.properties_from_neo4j(%{"firstName" => "Matt", "age" => 42})
      %{"first_name" => "Matt", "age" => 42}
  """
  def properties_from_neo4j(props) when is_map(props) do
    Map.new(props, fn {k, v} -> {to_snake_case(k), v} end)
  end

  @doc """
  Returns true if the string is a valid Neo4j property key (`camelCase`, starts lowercase).

  ## Examples

      iex> ArtefactoryNeo4j.Util.valid_property_key?("firstName")
      true
      iex> ArtefactoryNeo4j.Util.valid_property_key?("first_name")
      false
  """
  def valid_property_key?(value) when is_binary(value) do
    Regex.match?(~r/^[a-z][a-zA-Z0-9]*$/, value)
  end

  @doc """
  Returns true if the string is a valid Neo4j node label (`PascalCase`).

  ## Examples

      iex> ArtefactoryNeo4j.Util.valid_label?("Agent")
      true
      iex> ArtefactoryNeo4j.Util.valid_label?("agent")
      false
  """
  def valid_label?(value) when is_binary(value) do
    Regex.match?(~r/^[A-Z][a-zA-Z0-9]*$/, value)
  end

  @doc """
  Returns true if the string is a valid Neo4j relationship type (`MACRO_CASE`).

  ## Examples

      iex> ArtefactoryNeo4j.Util.valid_relationship_type?("US_TWO")
      true
      iex> ArtefactoryNeo4j.Util.valid_relationship_type?("us_two")
      false
  """
  def valid_relationship_type?(value) when is_binary(value) do
    Regex.match?(~r/^[A-Z]+(_[A-Z]+)*$/, value)
  end

  @doc """
  Returns true if the string is a valid Neo4j database name (letters, numbers, dots, dashes).

  ## Examples

      iex> ArtefactoryNeo4j.Util.valid_database_name?("matt-me")
      true
      iex> ArtefactoryNeo4j.Util.valid_database_name?("matt_me")
      false
  """
  def valid_database_name?(value) when is_binary(value) do
    Regex.match?(~r/^[a-zA-Z0-9][a-zA-Z0-9.\-]*$/, value)
  end
end
