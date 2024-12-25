defmodule Flatbuffer do
  alias Flatbuffer.Access
  alias Flatbuffer.Buffer
  alias Flatbuffer.Reading
  alias Flatbuffer.Schema
  alias Flatbuffer.Writer

  @spec read(Buffer.t(), Schema.t()) ::
          {:ok, map()}
          | {:error, {:id_mismatch, %{buffer_id: binary(), schema_id: binary()}}}
  def read(buffer, %Schema{} = schema) do
    cursor = Buffer.cursor(buffer, 0)

    with :ok <- Reading.check_buffer_id(cursor, schema.id) do
      {:ok, Reading.read(schema.root_type, cursor, schema)}
    end
  end

  @spec read!(Buffer.t(), Schema.t()) :: map()
  def read!(buffer, %Schema{} = schema) do
    with {:ok, value} <- read(buffer, schema) do
      value
    else
      {:error, _reason} = error -> throw(error)
    end
  end

  @spec get(Buffer.t(), [atom() | integer()], Schema.t()) ::
          {:ok, any()} | {:error, :index_out_of_range}
  def get(buffer, path, schema) do
    cursor = Buffer.cursor(buffer, 0)

    with :ok <- Reading.check_buffer_id(cursor, schema.id) do
      Access.get(path, schema.root_type, cursor, schema)
    end
  end

  @spec get!(Buffer.t(), [atom() | integer()], Schema.t()) :: any()
  def get!(buffer, path, schema) do
    with {:ok, value} <- get(buffer, path, schema) do
      value
    else
      {:error, _reason} = error -> throw(error)
    end
  end

  @spec to_iolist(map(), Schema.t()) :: iolist()
  def to_iolist(%{} = map, %Schema{} = schema) do
    root_table =
      [<<vtable_offset::little-size(16)>> | _] =
      Writer.write(schema.root_type, map, [], schema)

    buffer_id = schema.id || <<0, 0, 0, 0>>

    [
      <<vtable_offset + 4 + byte_size(buffer_id)::little-size(32)>>,
      buffer_id,
      root_table
    ]
  end

  @spec to_binary(map(), Schema.t()) :: binary()
  def to_binary(%{} = map, %Schema{} = schema) do
    map
    |> to_iolist(schema)
    |> IO.iodata_to_binary()
  end

  defmacro __using__(opts) do
    resolver =
      case Keyword.get(opts, :path) do
        nil -> &File.read/1
        path -> &File.read(Path.join(path, &1))
      end

    file = Keyword.get(opts, :file) || raise "Missing :file option"

    with {:ok, schema} <- Schema.from_file(file, resolver: resolver) do
      quote do
        def schema, do: unquote(Macro.escape(schema))
        def read(buffer), do: Flatbuffer.read(buffer, schema())
        def read!(buffer), do: Flatbuffer.read!(buffer, schema())
        def get(buffer, path), do: Flatbuffer.get(buffer, path, schema())
        def get!(buffer, path), do: Flatbuffer.get!(buffer, path, schema())
        def to_iolist(map), do: Flatbuffer.to_iolist(map, schema())
        def to_binary(map), do: Flatbuffer.to_binary(map, schema())
      end
    else
      {:error, reason} -> raise "Failed to load schema from file (#{file}): #{inspect(reason)}"
    end
  end
end
