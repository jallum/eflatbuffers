defmodule Flatbuffer.Access do
  alias Flatbuffer.Utils
  alias Flatbuffer.Reading
  alias Flatbuffer.Cursor

  def get(_, _, nil, _), do: nil
  def get([], type, cursor, schema), do: {:ok, Reading.read(type, cursor, schema)}

  def get([key | keys], {:table, %{name: table_name}}, cursor, schema) when is_atom(key) do
    {:table, table_options} = Map.get(schema.entities, table_name)
    {index, type} = Map.get(table_options.indices, key)

    {type_concrete, index_concrete} =
      case type do
        {:union, %{name: union_name}} ->
          # we are getting the field type from the field
          # and the data is actually in the next field
          # since the schema does not contain the *_type field
          type_pointer = data_pointer(cursor, index)
          union_type_index = Cursor.get_u8(type_pointer) - 1

          {:union, union_definition} = Map.get(schema.entities, union_name)
          union_type = Map.get(union_definition.members, union_type_index)
          {{:table, %{name: union_type}}, index + 1}

        _ ->
          {type, index}
      end

    get(keys, type_concrete, data_pointer(cursor, index_concrete), schema)
  end

  def get([index | keys], {:vector, type}, cursor, schema) when is_integer(index) do
    vector = Cursor.jump_u32(cursor)
    count = Cursor.get_u32(vector)

    if index >= count do
      {:error, :index_out_of_range}
    else
      data_pointer = Cursor.skip(vector, 4 + index * Utils.sizeof(type, schema))

      case keys do
        [] ->
          {:ok, Reading.read(type, data_pointer, schema)}

        _ ->
          get(keys, type, data_pointer, schema)
      end
    end
  end

  defp data_pointer(c, index) do
    table = Cursor.jump_i32(c)
    vtable = Cursor.rjump_i32(table)

    case Cursor.get_i16(vtable, 4 + index * 2) do
      0 -> nil
      data_offset -> Cursor.skip(table, data_offset)
    end
  end
end
