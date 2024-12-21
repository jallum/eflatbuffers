defmodule Eflatbuffers do
  alias Eflatbuffers.RandomAccess
  alias Eflatbuffers.Reader
  alias Eflatbuffers.Schema
  alias Eflatbuffers.Writer

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

  def read(data, {_, opts} = schema) do
    with :ok <- match_ids(data, Keyword.get(opts, :file_identifier)),
         root_type <- Keyword.get(opts, :root_type) do
      {:ok, Reader.read(root_type, 0, data, schema)}
    end
  end

  def read!(data, schema) do
    case read(data, schema) do
      {:ok, result} -> result
      {:error, reason} -> throw(reason)
    end
  end

  defp match_ids(<<_::binary-size(4), data_id::binary-size(4), _::binary>>, id) do
    cond do
      is_nil(id) -> :ok
      id == data_id -> :ok
      true -> {:error, {:id_mismatch, %{data: data_id, schema: id}}}
    end
  end

  def get(data, path, schema) do
    {:ok, get!(data, path, schema)}
  rescue
    error -> {:error, error}
  catch
    error -> error
  end

  def get!(data, path, schema) when is_binary(schema),
    do: get!(data, path, parse_schema!(schema))

  def get!(data, path, {_tables, options} = schema) do
    root_type = Keyword.fetch!(options, :root_type)
    RandomAccess.get(path, root_type, 0, data, schema)
  end
end
