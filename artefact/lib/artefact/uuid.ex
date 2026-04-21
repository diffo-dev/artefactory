# SPDX-FileCopyrightText: 2026 diffo-dev
# SPDX-License-Identifier: MIT

defmodule Artefact.UUID do
  @moduledoc false
  import Bitwise

  @doc "Generate a UUIDv7 string. Time-ordered; lower value = earlier creation."
  def generate_v7 do
    # 48-bit millisecond timestamp
    ms = :os.system_time(:millisecond)
    <<ts::48>> = <<ms::48>>

    # 74 random bits (12 + 62, we generate 80 and split)
    <<rand_a::12, rand_b::62, _::6>> = :crypto.strong_rand_bytes(10)

    # version = 7 (4 bits), variant = 0b10 (2 bits)
    <<a::32, b::16, _::4, c::12, _::2, d::62>> =
      <<ts::48, 7::4, rand_a::12, 0b10::2, rand_b::62>>

    format(a, b, 0x7000 ||| c, 0x8000000000000000 ||| d)
  end

  @doc "Compare two UUIDv7 strings. Returns the lower (earlier) of the two."
  def harmonise(uuid_a, uuid_b) when uuid_a <= uuid_b, do: uuid_a
  def harmonise(_uuid_a, uuid_b), do: uuid_b

  defp format(a, b, c, d) do
    :io_lib.format(
      "~8.16.0b-~4.16.0b-~4.16.0b-~4.16.0b-~12.16.0b",
      [a, b, c, d >>> 48, d &&& 0xFFFFFFFFFFFF]
    )
    |> IO.iodata_to_binary()
  end
end
