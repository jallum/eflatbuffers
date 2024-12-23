defimpl Flatbuffer.Buffer, for: BitString do
  alias Flatbuffer.Cursor

  @impl true
  def size(b), do: byte_size(b)

  @impl true
  def binary(b), do: b

  @impl true
  def binary(b, offset, size), do: binary_part(b, offset, size)

  @impl true
  def iodata(b), do: b

  @impl true
  def iodata(b, offset, size), do: binary_part(b, offset, size)

  @impl true
  def cursor(t, offset), do: %Cursor{buffer: t, offset: offset}
end
