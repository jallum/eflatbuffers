defmodule Eflatbuffers.Reader do
  alias Eflatbuffers.Utils
  alias Flatbuffers.Buffer
  alias Flatbuffers.Cursor

  # complex types

  def read({:bool, _}, c, _), do: Cursor.get_i8(c) != 0
  def read({:byte, _}, c, _), do: Cursor.get_i8(c)
  def read({:ubyte, _}, c, _), do: Cursor.get_u8(c)
  def read({:short, _}, c, _), do: Cursor.get_i16(c)
  def read({:ushort, _}, c, _), do: Cursor.get_u16(c)
  def read({:int, _}, c, _), do: Cursor.get_i32(c)
  def read({:uint, _}, c, _), do: Cursor.get_u32(c)
  def read({:long, _}, c, _), do: Cursor.get_i64(c)
  def read({:ulong, _}, c, _), do: Cursor.get_u64(c)
  def read({:float, _}, c, _), do: Cursor.get_f32(c)
  def read({:double, _}, c, _), do: Cursor.get_f64(c)

  def read({:string, _options}, c, _) do
    Cursor.get_bytes(
      Cursor.skip(c, 4),
      Cursor.get_u32(c)
    )
  end

  def read({:vector, %{type: type}}, c, schema) do
    read_vector_elements(
      type,
      Cursor.skip(c, 4),
      Cursor.get_u32(c),
      Utils.sizeof(type, schema),
      schema
    )
  end

  def read({:enum, %{name: enum_name}}, c, {entities, _options} = schema) do
    {:enum, %{members: members, type: type}} = Map.get(entities, enum_name)
    index = read(type, c, schema)

    case Map.get(members, index) do
      nil -> throw({:error, {:not_in_enum, index, members}})
      value_atom -> value_atom
    end
  end

  def read({:struct, %{name: struct_name}}, c, {entities, _} = schema) do
    {:struct, %{members: members}} = Map.get(entities, struct_name)

    {struct, _offset} =
      members
      |> Enum.reduce({%{}, 0}, fn {name, type}, {acc, offset} ->
        value = read({type, %{}}, Cursor.skip(c, offset), schema)
        {Map.put(acc, name, value), offset + Utils.scalar_size(type)}
      end)

    struct
  end

  defp read_vector_elements(_, _, 0, _, _), do: []

  defp read_vector_elements(type, c, count, size, schema) do
    [
      read(type, c, schema)
      | read_vector_elements(type, Cursor.skip(c, size), count - 1, size, schema)
    ]
  end

  ########################

  def read(type, %Cursor{buffer: buffer, offset: offset}, schema),
    do: read(type, offset, buffer, schema)

  def read({:string, _options}, vtable_pointer, data, _) do
    c = Buffer.cursor(data, vtable_pointer) |> Cursor.jump_u32()

    Cursor.get_bytes(
      Cursor.skip(c, 4),
      Cursor.get_u32(c)
    )
  end

  def read({:vector, %{type: type}}, vtable_pointer, data, schema) do
    c = Buffer.cursor(data, vtable_pointer) |> Cursor.jump_u32()

    read_vector_elements(
      type,
      Cursor.skip(c, 4),
      Cursor.get_u32(c),
      Utils.sizeof(type, schema),
      schema
    )
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
  def read({:table, %{name: table_name}}, table_pointer_pointer, data, {entities, _} = schema) do
    {:table, %{fields: fields}} = Map.get(entities, table_name)

    table_offset = Buffer.cursor(data, table_pointer_pointer) |> Cursor.get_i32()
    table_pointer = table_pointer_pointer + table_offset

    vtable_offset = Buffer.cursor(data, table_pointer) |> Cursor.get_i32()
    vtable_pointer = table_pointer - vtable_offset

    vtable_length = Buffer.cursor(data, vtable_pointer) |> Cursor.get_i16()
    vtable_fields_pointer = vtable_pointer + 4
    vtable_fields_length = vtable_length - 4
    IO.inspect(vtable_fields_length)

    vtable = Buffer.cursor(data, vtable_fields_pointer) |> Cursor.get_bytes(vtable_fields_length)

    read_table_fields(fields, vtable, table_pointer, data, schema)
  end

  def read({:struct, %{name: struct_name}}, vtable_pointer, data, {entities, _} = schema) do
    {:struct, %{members: members}} = Map.get(entities, struct_name)

    {struct, _offset} =
      members
      |> Enum.reduce({%{}, 0}, fn {name, type}, {acc, offset} ->
        value = read({type, %{}}, vtable_pointer + offset, data, schema)
        {Map.put(acc, name, value), offset + Utils.scalar_size(type)}
      end)

    struct
  end

  def read({:bool, _}, at, data, _), do: Buffer.cursor(data, at) |> Cursor.get_i8() != 0
  def read({:byte, _}, at, data, _), do: Buffer.cursor(data, at) |> Cursor.get_i8()
  def read({:ubyte, _}, at, data, _), do: Buffer.cursor(data, at) |> Cursor.get_u8()
  def read({:short, _}, at, data, _), do: Buffer.cursor(data, at) |> Cursor.get_i16()
  def read({:ushort, _}, at, data, _), do: Buffer.cursor(data, at) |> Cursor.get_u16()
  def read({:int, _}, at, data, _), do: Buffer.cursor(data, at) |> Cursor.get_i32()
  def read({:uint, _}, at, data, _), do: Buffer.cursor(data, at) |> Cursor.get_u32()
  def read({:long, _}, at, data, _), do: Buffer.cursor(data, at) |> Cursor.get_i64()
  def read({:ulong, _}, at, data, _), do: Buffer.cursor(data, at) |> Cursor.get_u64()
  def read({:float, _}, at, data, _), do: Buffer.cursor(data, at) |> Cursor.get_f32()
  def read({:double, _}, at, data, _), do: Buffer.cursor(data, at) |> Cursor.get_f64()

  def read(type, _, _, _), do: throw({:error, {:unknown_type, type}})

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
    union_index = Buffer.cursor(data, data_pointer + data_offset) |> Cursor.get_u8()

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
