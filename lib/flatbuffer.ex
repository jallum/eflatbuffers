defmodule Flatbuffer do
  alias Flatbuffer.Buffer
  alias Flatbuffer.Reading
  alias Flatbuffer.Schema

  @spec read(Buffer.t(), Schema.t()) ::
          {:ok, map()}
          | {:error, {:id_mismatch, %{data_id: binary(), schema_id: binary()}}}
  def read(buffer, %Schema{} = schema) do
    cursor = Buffer.cursor(buffer, 0)

    with :ok <- Reading.check_buffer_id(cursor, schema.id) do
      {:ok, Reading.read(schema.root_type, cursor, schema)}
    end
  end

  @spec read!(Buffer.t(), Schema.t()) :: map()
  def read!(buffer, %Schema{} = schema) do
    with {:ok, root} <- read(buffer, schema) do
      root
    else
      {:error, _reason} = error -> throw(error)
    end
  end
end
