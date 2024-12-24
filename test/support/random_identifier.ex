defmodule RandomIdentifier do
  @alphabet Enum.concat([?a..?z, ?A..?Z, ?0..?9])

  def generate(length \\ 8) do
    1..length
    |> Enum.map(fn _ -> Enum.random(@alphabet) end)
    |> List.to_string()
  end
end
