defmodule Eflatbuffers.Reader do
  alias Eflatbuffers.Utils

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

  defp read_i8(data, at), do: read_from_data_buffer(data, at, 1) |> decode_i8()
  defp read_u8(data, at), do: read_from_data_buffer(data, at, 1) |> decode_u8()
  defp read_i16(data, at), do: read_from_data_buffer(data, at, 2) |> decode_i16()
  defp read_u16(data, at), do: read_from_data_buffer(data, at, 2) |> decode_u16()
  defp read_i32(data, at), do: read_from_data_buffer(data, at, 4) |> decode_i32()
  defp read_u32(data, at), do: read_from_data_buffer(data, at, 4) |> decode_u32()
  defp read_i64(data, at), do: read_from_data_buffer(data, at, 8) |> decode_i64()
  defp read_u64(data, at), do: read_from_data_buffer(data, at, 8) |> decode_u64()
  defp read_f32(data, at), do: read_from_data_buffer(data, at, 4) |> decode_f32()
  defp read_f64(data, at), do: read_from_data_buffer(data, at, 8) |> decode_f64()

  defp read_scalar(:bool, data, at), do: read_u8(data, at) != 0
  defp read_scalar(:byte, data, at), do: read_i8(data, at)
  defp read_scalar(:ubyte, data, at), do: read_u8(data, at)
  defp read_scalar(:short, data, at), do: read_i16(data, at)
  defp read_scalar(:ushort, data, at), do: read_u16(data, at)
  defp read_scalar(:int, data, at), do: read_i32(data, at)
  defp read_scalar(:uint, data, at), do: read_u32(data, at)
  defp read_scalar(:float, data, at), do: read_f32(data, at)
  defp read_scalar(:long, data, at), do: read_i64(data, at)
  defp read_scalar(:ulong, data, at), do: read_u64(data, at)
  defp read_scalar(:double, data, at), do: read_f64(data, at)
  defp read_scalar(type, _, _), do: throw({:error, {:unknown_type, type}})

  # complex types

  def read({:string, _options}, vtable_pointer, data, _) do
    string_offset = read_u32(data, vtable_pointer)
    string_pointer = vtable_pointer + string_offset

    string_length = read_u32(data, string_pointer)
    read_from_data_buffer(data, string_pointer + 4, string_length)
  end

  def read({:vector, %{type: type}}, vtable_pointer, data, schema) do
    vector_offset = read_u32(data, vtable_pointer)
    vector_pointer = vtable_pointer + vector_offset

    vector_count = read_u32(data, vector_pointer)
    read_vector_elements(type, vector_pointer + 4, vector_count, data, schema)
  end

  def read({:enum, %{name: enum_name}}, vtable_pointer, data, {entities, _options} = schema) do
    {:enum, %{members: members, type: type}} = Map.get(entities, enum_name)
    index = read(type, vtable_pointer, data, schema)

    case Map.get(members, index) do
      nil -> throw({:error, {:not_in_enum, index, members}})
      value_atom -> value_atom
    end
  end

  # read a complete table, given a pointer to the springboard
  def read({:table, %{name: table_name}}, table_pointer_pointer, data, {entities, _} = schema)
      when is_atom(table_name) do
    {:table, %{fields: fields}} = Map.get(entities, table_name)

    table_offset = read_i32(data, table_pointer_pointer)
    table_pointer = table_pointer_pointer + table_offset

    vtable_offset = read_i32(data, table_pointer)
    vtable_pointer = table_pointer - vtable_offset

    vtable_length = read_i16(data, vtable_pointer)
    vtable_fields_pointer = vtable_pointer + 4
    vtable_fields_length = vtable_length - 4

    vtable = read_from_data_buffer(data, vtable_fields_pointer, vtable_fields_length)

    read_table_fields(fields, vtable, table_pointer, data, schema)
  end

  def read({:struct, %{name: struct_name}}, vtable_pointer, data, {entities, _} = schema)
      when is_atom(struct_name) do
    {:struct, %{members: members}} = Map.get(entities, struct_name)

    {struct, _offset} =
      members
      |> Enum.reduce({%{}, 0}, fn {name, type}, {acc, offset} ->
        value = read({type, %{}}, vtable_pointer + offset, data, schema)
        {Map.put(acc, name, value), offset + Utils.scalar_size(type)}
      end)

    struct
  end

  def read({type, _}, at, data, _), do: read_scalar(type, data, at)

  def read_vector_elements(_, _, 0, _, _), do: []

  def read_vector_elements(type, vector_pointer, vector_count, data, schema) do
    value = read(type, vector_pointer, data, schema)
    offset = Utils.sizeof(type, schema)
    [value | read_vector_elements(type, vector_pointer + offset, vector_count - 1, data, schema)]
  end

  # this is a utility that just reads data_size bytes from data after data_pointer
  def read_from_data_buffer(data, data_pointer, data_size),
    do: binary_part(data, data_pointer, data_size)

  def read_table_fields(fields, vtable, data_pointer, data, schema),
    do: %{} |> read_table_row(fields, vtable, data_pointer, data, schema)

  # we might still have more fields but we ran out of vtable slots
  # this happens if the schema has more fields than the data (schema evolution)
  defp read_table_row(row, _, <<>>, _, _, _), do: row

  # we might have more data but no more fields
  # that means the data is ahead and has more data than the schema
  defp read_table_row(row, [], _, _, _, _), do: row

  defp read_table_row(
         row,
         [{name, {:union, %{name: union_name}}} | fields],
         <<data_offset::little-size(16), vtable::binary>>,
         data_pointer,
         data,
         {tables, _options} = schema
       ) do
    # for a union byte field named $fieldname$_type is prefixed
    union_index = read_u8(data, data_pointer + data_offset)

    case union_index do
      0 ->
        # index is null, so field is not set
        # carry on
        read_table_row(row, fields, vtable, data_pointer, data, schema)

      _ ->
        # we have a table set so we get the type and
        # expect it as the next record in the vtable
        {:union, %{members: members}} = Map.get(tables, union_name)

        union_type = Map.get(members, union_index - 1)
        type_key = :"#{name}_type"

        row
        |> Map.put(type_key, union_type)
        |> read_table_row(
          [{name, {:table, %{name: union_type}}} | fields],
          vtable,
          data_pointer,
          data,
          schema
        )
    end
  end

  # we find a null pointer
  # so we set the dafault
  defp read_table_row(
         row,
         [{name, {:enum, options}} | fields],
         <<0, 0, vtable::binary>>,
         data_pointer,
         data,
         {tables, _} = schema
       ) do
    {_, enum_options} = Map.get(tables, options.name)
    {_, %{default: default}} = enum_options.type

    row
    |> Map.put(name, Map.get(enum_options.members, default))
    |> read_table_row(fields, vtable, data_pointer, data, schema)
  end

  defp read_table_row(
         row,
         [{name, {_type, options}} | fields],
         <<0, 0, vtable::binary>>,
         data_pointer,
         data,
         schema
       ) do
    case Map.get(options, :default) do
      nil -> row
      default -> row |> Map.put(name, default)
    end
    |> read_table_row(fields, vtable, data_pointer, data, schema)
  end

  defp read_table_row(
         row,
         [{name, type} | fields],
         <<data_offset::little-size(16), vtable::binary>>,
         data_pointer,
         data,
         schema
       ) do
    value = read(type, data_pointer + data_offset, data, schema)

    row
    |> Map.put(name, value)
    |> read_table_row(fields, vtable, data_pointer, data, schema)
  end
end
