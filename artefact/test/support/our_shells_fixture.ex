# SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Artefact.Test.Fixtures.OurShells do
  @moduledoc """
  Test fixture in `Artefact.new` form, adapted from
  `diffo-dev/.github/livebook/shells.livemd`.

  Provides a small "Our Shells" artefact (`our_shells/0`) and a matching
  graft args set (`manifesto_args/0`) that mixes bind-only references to
  existing nodes with brand-new nodes and relationships.

  Used to exercise `Artefact.graft/3`.
  """

  require Artefact

  # Stable uuids — same as the shells livebook so the fixture reads the same
  @me_uuid "019ddb71-c70b-7b3e-83b1-58f4d0be2852"
  @valuing_uuid "019ddb7f-a43d-7525-bb4f-bfd32d110719"
  @beings_uuid "019de8bb-86b0-7acf-b1b8-40e96a3775a6"
  @shells_uuid "019df584-d80b-798a-8b83-077273c43cea"
  @council_uuid "019df523-66a7-7dca-93c6-ec9579e9408f"
  @core_uuid "019df524-0bbf-7272-879a-20cba847223b"
  @association_uuid "019df524-638e-7fba-832a-b0f216843232"

  # Brand-new uuids the graft introduces
  @ethics_uuid "019df311-16f0-7eea-a66f-a5c502551c6d"
  @stewardship_uuid "019df318-698c-77d6-bc7b-ea041a019a7f"
  @intent_uuid "019df317-1c9d-7d84-afe8-0f356db70103"

  def me_uuid, do: @me_uuid
  def valuing_uuid, do: @valuing_uuid
  def beings_uuid, do: @beings_uuid
  def shells_uuid, do: @shells_uuid
  def council_uuid, do: @council_uuid
  def core_uuid, do: @core_uuid
  def association_uuid, do: @association_uuid

  def ethics_uuid, do: @ethics_uuid
  def stewardship_uuid, do: @stewardship_uuid
  def intent_uuid, do: @intent_uuid

  @doc """
  The "Our Shells" artefact — the canonical *left* in graft tests.
  """
  def our_shells do
    me = {:me, [labels: ["Agent"], properties: %{"name" => "me"}, uuid: @me_uuid]}

    valuing =
      {:valuing, [labels: ["Knowing"], properties: %{"name" => "valuing"}, uuid: @valuing_uuid]}

    beings =
      {:beings, [labels: ["Valuing"], properties: %{"name" => "beings"}, uuid: @beings_uuid]}

    shells =
      {:shells, [labels: ["Knowing"], properties: %{"name" => "shells"}, uuid: @shells_uuid]}

    council =
      {:council,
       [labels: ["Shell", "Beings"], properties: %{"name" => "council"}, uuid: @council_uuid]}

    core =
      {:core, [labels: ["Shell", "Beings"], properties: %{"name" => "core"}, uuid: @core_uuid]}

    association =
      {:association,
       [
         labels: ["Shell", "Beings"],
         properties: %{"name" => "association"},
         uuid: @association_uuid
       ]}

    Artefact.new!(
      title: "Our Shells",
      description: "Our Shells help us value Beings.",
      nodes: [me, valuing, beings, shells, council, core, association],
      relationships: [
        [from: :me, type: "VALUING", to: :valuing],
        [from: :valuing, type: "CONSIDERING", to: :beings],
        [from: :me, type: "KNOWING", to: :shells],
        [from: :beings, type: "LIKELY_IN", to: :shells],
        [from: :council, type: "INNERMOST", to: :shells],
        [from: :core, type: "INSIDE", to: :council],
        [from: :core, type: "INSIDE", to: :association]
      ]
    )
  end

  @doc """
  Graft args adapted from the shells.livemd "Our Shells and Manifesto"
  step. Mixes bind-only references (`:me`, `:council`, `:core`,
  `:association`) with new nodes (`:ethics`, `:stewardship`, `:intent`)
  and a handful of new relationships that span both.
  """
  def manifesto_args do
    [
      nodes: [
        # bind-only — uuid lives in our_shells
        {:me, [uuid: @me_uuid]},
        {:council, [uuid: @council_uuid]},
        {:core, [uuid: @core_uuid]},
        {:association, [uuid: @association_uuid]},
        # new
        {:ethics, [labels: ["Knowing"], properties: %{"name" => "ethics"}, uuid: @ethics_uuid]},
        {:stewardship,
         [labels: ["Knowing"], properties: %{"name" => "stewardship"}, uuid: @stewardship_uuid]},
        {:intent, [labels: ["Knowing"], properties: %{"name" => "intent"}, uuid: @intent_uuid]}
      ],
      relationships: [
        [from: :me, type: "KNOWING", to: :stewardship],
        [from: :council, type: "KNOWING", to: :ethics],
        [from: :core, type: "KNOWING", to: :intent],
        [from: :association, type: "KNOWING", to: :stewardship]
      ]
    ]
  end
end
