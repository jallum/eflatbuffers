defprotocol Flatbuffer.Buffer do
  alias Flatbuffer.Cursor

  @type t :: term()

  @spec size(t()) :: non_neg_integer()
  def size(t)

  @spec binary(t()) :: binary()
  def binary(t)

  @spec binary(t(), start :: non_neg_integer(), size :: non_neg_integer()) :: binary()
  def binary(t, start, size)

  @spec iodata(t()) :: iodata()
  def iodata(t)

  @spec binary(t(), start :: non_neg_integer(), size :: non_neg_integer()) :: binary()
  def iodata(t, start, size)

  @spec cursor(t(), offset :: non_neg_integer()) :: Cursor.t()
  def cursor(t, offset \\ 0)
end
