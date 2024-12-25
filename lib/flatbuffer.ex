defmodule Flatbuffer do
  @moduledoc """
  Flatbuffer binary serialization for Elixir.

  Provides functions to read from and write to Flatbuffer binaries using schema definitions.
  Supports direct access to nested data without parsing the entire buffer.

  ## Usage
      # Read/Write
      {:ok, data} = Flatbuffer.read(buffer, schema)
      binary = Flatbuffer.to_binary(map, schema)

      # Direct access
      {:ok, value} = Flatbuffer.get(buffer, [:table, :field], schema)

      # With schema file
      def YourThing do
        use Flatbuffer, file: "schema.fbs"
      end

      # Read/Write
      {:ok, data} = YourThing.read(buffer)
      binary = YourThing.to_binary(map)

  """

  alias Flatbuffer.Access
  alias Flatbuffer.Buffer
  alias Flatbuffer.Reading
  alias Flatbuffer.Schema
  alias Flatbuffer.Writer

  @doc """
  Reads a Flatbuffer into a map using the given schema.
  Returns {:ok, map} or {:error, reason}.
  """
  @spec read(buffer :: iodata(), Schema.t()) ::
          {:ok, map()}
          | {:error, {:id_mismatch, %{buffer_id: binary(), schema_id: binary()}}}
  def read(buffer, %Schema{} = schema) do
    cursor = Buffer.cursor(buffer, 0)

    with :ok <- Reading.check_buffer_id(cursor, schema.id) do
      {:ok, Reading.read(schema.root_type, cursor, schema)}
    end
  end

  @doc """
  Same as read/2 but raises on error.
  """
  @spec read!(buffer :: iodata(), Schema.t()) :: map()
  def read!(buffer, %Schema{} = schema) do
    with {:ok, value} <- read(buffer, schema) do
      value
    else
      {:error, _reason} = error -> throw(error)
    end
  end

  @doc """
  Retrieves a value from a path without decoding the entire buffer.
  Returns {:ok, value} or {:error, :index_out_of_range}.
  """
  @spec get(buffer :: iodata(), [atom() | integer()], Schema.t()) ::
          {:ok, any()} | {:error, :index_out_of_range}
  def get(buffer, path, schema) do
    cursor = Buffer.cursor(buffer, 0)

    with :ok <- Reading.check_buffer_id(cursor, schema.id) do
      Access.get(path, schema.root_type, cursor, schema)
    end
  end

  @doc """
  Same as get/3 but raises on error.
  """
  @spec get!(buffer :: iodata(), [atom() | integer()], Schema.t()) :: any()
  def get!(buffer, path, schema) do
    with {:ok, value} <- get(buffer, path, schema) do
      value
    else
      {:error, _reason} = error -> throw(error)
    end
  end

  @doc """
  Serializes a map into a Flatbuffer iolist using the schema.
  """
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

  @doc """
  Serializes a map into a Flatbuffer binary using the schema.
  """
  @spec to_binary(map(), Schema.t()) :: binary()
  def to_binary(%{} = map, %Schema{} = schema) do
    map
    |> to_iolist(schema)
    |> IO.iodata_to_binary()
  end

  @doc """
  Generates schema-aware functions (read, get, to_iolist, etc.) in the caller module.
  Options:
    * :file - Required schema file path.
    * :path - Base path for schema includes.
  """
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
