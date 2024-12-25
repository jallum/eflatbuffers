defmodule Flatbuffer.Cursor do
  @moduledoc false

  alias Flatbuffer.Buffer

  @type t :: %__MODULE__{
          buffer: Buffer.t(),
          offset: non_neg_integer()
        }
  defstruct [:buffer, :offset]

  def skip(c, offset), do: %__MODULE__{c | offset: c.offset + offset}

  def rjump_i32(c), do: %__MODULE__{c | offset: c.offset - get_i32(c)}
  def jump_i32(c), do: %__MODULE__{c | offset: c.offset + get_i32(c)}
  def jump_u32(c), do: %__MODULE__{c | offset: c.offset + get_u32(c)}

  def get_i8(c, offset \\ 0), do: Buffer.binary(c.buffer, c.offset + offset, 1) |> decode_i8()
  def get_u8(c, offset \\ 0), do: Buffer.binary(c.buffer, c.offset + offset, 1) |> decode_u8()
  def get_i16(c, offset \\ 0), do: Buffer.binary(c.buffer, c.offset + offset, 2) |> decode_i16()
  def get_u16(c, offset \\ 0), do: Buffer.binary(c.buffer, c.offset + offset, 2) |> decode_u16()
  def get_i32(c, offset \\ 0), do: Buffer.binary(c.buffer, c.offset + offset, 4) |> decode_i32()
  def get_u32(c, offset \\ 0), do: Buffer.binary(c.buffer, c.offset + offset, 4) |> decode_u32()
  def get_i64(c, offset \\ 0), do: Buffer.binary(c.buffer, c.offset + offset, 8) |> decode_i64()
  def get_u64(c, offset \\ 0), do: Buffer.binary(c.buffer, c.offset + offset, 8) |> decode_u64()
  def get_f32(c, offset \\ 0), do: Buffer.binary(c.buffer, c.offset + offset, 4) |> decode_f32()
  def get_f64(c, offset \\ 0), do: Buffer.binary(c.buffer, c.offset + offset, 8) |> decode_f64()

  def get_bytes(c, size), do: Buffer.binary(c.buffer, c.offset, size)
  def get_bytes(c, offset, size), do: Buffer.binary(c.buffer, c.offset + offset, size)

  defp decode_i8(<<i8::signed-size(8)>>), do: i8
  defp decode_u8(<<u8::unsigned-size(8)>>), do: u8
  defp decode_i16(<<i16::signed-little-size(16)>>), do: i16
  defp decode_u16(<<u16::unsigned-little-size(16)>>), do: u16
  defp decode_i32(<<i32::signed-little-size(32)>>), do: i32
  defp decode_u32(<<u32::unsigned-little-size(32)>>), do: u32
  defp decode_i64(<<i64::signed-little-size(64)>>), do: i64
  defp decode_u64(<<u64::unsigned-little-size(64)>>), do: u64
  defp decode_f32(<<f32::float-little-size(32)>>), do: f32
  defp decode_f64(<<f64::float-little-size(64)>>), do: f64
end
