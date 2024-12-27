defmodule Flatbuffer.Access do
  @moduledoc false

  alias Flatbuffer.BadFlatbufferError
  alias Flatbuffer.Utils
  alias Flatbuffer.Reading
  alias Flatbuffer.Cursor

  def get(nil, _, _, _), do: nil
  def get(cursor, key, type, schema) when is_atom(key), do: get(cursor, [key], type, schema)
  def get(cursor, [], type, schema), do: Reading.read(type, cursor, schema)

  def get(cursor, [key | keys], {:table, %{name: table_name}}, schema) when is_atom(key) do
    case resolve_field!(schema, table_name, key) do
      {index, {:union_type, union_name}} ->
        cursor
        |> data_pointer(index)
        |> Cursor.get_u8()
        |> case do
          0 ->
            nil

          type_index ->
            {:union, union_definition} = Map.get(schema.entities, union_name)
            Map.get(union_definition.members, type_index - 1)
        end

      {index, {:union, %{name: union_name}}} ->
        # We are getting the field type from the field and the data is actually
        # in the next field since the schema does not contain the *_type field
        cursor
        |> data_pointer(index)
        |> Cursor.get_u8()
        |> case do
          0 ->
            nil

          type_index ->
            {:union, union_definition} = Map.get(schema.entities, union_name)
            union_type = Map.get(union_definition.members, type_index - 1)

            cursor
            |> data_pointer(index + 1)
            |> get(keys, {:table, %{name: union_type}}, schema)
        end

      {index, type} ->
        cursor
        |> data_pointer(index)
        |> get(keys, type, schema)

      nil ->
        nil
    end
  end

  def get(cursor, [index | keys], {:vector, type}, schema) when is_integer(index) do
    vector = Cursor.jump_u32(cursor)
    count = Cursor.get_u32(vector)

    if index >= count do
      nil
    else
      data_pointer = Cursor.skip(vector, 4 + index * Utils.sizeof(type, schema))

      case keys do
        [] -> Reading.read(type, data_pointer, schema)
        _ -> get(data_pointer, keys, type, schema)
      end
    end
  end

  defp resolve_field!(schema, table_name, field_name) do
    case Map.get(schema.entities, table_name) do
      {:table, %{indices: indices}} ->
        Map.get(indices, field_name)

      _ ->
        raise BadFlatbufferError, message: "Table definition not found: #{table_name}"
    end
  end

  defp data_pointer(cursor, index) do
    table = Cursor.jump_i32(cursor)
    vtable = Cursor.rjump_i32(table)

    case Cursor.get_i16(vtable, 4 + index * 2) do
      0 -> nil
      data_offset -> Cursor.skip(table, data_offset)
    end
  end
end
