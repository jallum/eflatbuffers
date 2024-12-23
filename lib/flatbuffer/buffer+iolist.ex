defimpl Flatbuffer.Buffer, for: List do
  alias Flatbuffer.Cursor

  @impl true
  def size(b), do: :erlang.iolist_size(b)

  @impl true
  def binary(b), do: :erlang.iolist_to_binary(b)

  @impl true
  def binary(b, start, size),
    do: iodata(b, start, size) |> IO.iodata_to_binary()

  @impl true
  def iodata(b), do: b

  @impl true
  def iodata(b, start, length) do
    [b]
    |> seek(start)
    |> case do
      {t, 0} ->
        gather(t, length)
        |> case do
          {[bin], _} when is_binary(bin) -> bin
          {iolist, _} -> iolist
        end

      _ ->
        []
    end
  end

  @impl true
  def cursor(t, offset), do: %Cursor{buffer: t, offset: offset}

  defp seek([bin | tail], n) when is_binary(bin) do
    length_of_bin = byte_size(bin)

    cond do
      n > length_of_bin ->
        seek(tail, n - length_of_bin)

      n == length_of_bin ->
        {tail, 0}

      true ->
        {[binary_part(bin, n, length_of_bin - n) | tail], 0}
    end
  end

  defp seek([byte | tail], n) when is_integer(byte) do
    if n > 0 do
      seek(tail, n - 1)
    else
      {[n | tail], 0}
    end
  end

  defp seek([head | tail], n) do
    case seek(head, n) do
      {[], n} when n > 0 ->
        seek(tail, n)

      {h, n} when tail != [] ->
        {[h | tail], n}

      r ->
        r
    end
  end

  defp seek([], n), do: {[], n}

  defp gather([bin | tail], n) when is_binary(bin) do
    length_of_bin = byte_size(bin)

    cond do
      n > length_of_bin ->
        {tl, n} = gather(tail, n - length_of_bin)
        {[bin | tl], n}

      n == length_of_bin ->
        {[bin], 0}

      true ->
        {[binary_part(bin, 0, n)], 0}
    end
  end

  defp gather([byte | tail], n) when is_integer(byte) do
    if n > 0 do
      {tl, n} = gather(tail, n - 1)
      {[byte | tl], n}
    else
      {[byte], n}
    end
  end

  defp gather([head | tail], n) do
    case gather(head, n) do
      {[], n} when n > 0 ->
        gather(tail, n)

      {tl, n} when n > 0 ->
        {ttl, nn} = gather(tail, n)
        {[tl | ttl], nn}

      r ->
        r
    end
  end

  defp gather([], n), do: {[], n}
end
