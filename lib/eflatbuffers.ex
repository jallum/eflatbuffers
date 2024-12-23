defmodule Eflatbuffers do
  alias Eflatbuffers.RandomAccess
  alias Flatbuffer.Schema
  alias Eflatbuffers.Writer
  alias Flatbuffer.Buffer

  def parse_schema(schema_str), do: Schema.from_string(schema_str)

  def parse_schema!(schema_str) do
    case parse_schema(schema_str) do
      {:ok, schema} -> schema
      error -> throw(error)
    end
  end

  def write!(map, {_, options} = schema) do
    root_type = Keyword.fetch!(options, :root_type)

    root_table =
      [<<vtable_offset::little-size(16)>> | _] =
      Writer.write(root_type, map, [], schema)

    data_identifier =
      case Keyword.get(options, :data_identifier) do
        <<bin::size(32)>> -> <<bin::size(32)>>
        _ -> <<0, 0, 0, 0>>
      end

    [
      <<vtable_offset + 4 + byte_size(data_identifier)::little-size(32)>>,
      data_identifier,
      root_table
    ]
    |> :erlang.iolist_to_binary()
  end

  def write(map, schema) do
    {:ok, write!(map, schema)}
  rescue
    error -> {:error, error}
  catch
    error -> error
  end

  def get(data, path, schema), do: {:ok, get!(data, path, schema)}

  def get!(data, path, schema),
    do: RandomAccess.get(path, schema.root_type, Buffer.cursor(data, 0), schema)
end
