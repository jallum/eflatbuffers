defmodule Flatbuffer.BadFlatbufferError do
  @moduledoc """
  An exception raised when something expected a flatbuffer, but received something else.
  """

  defexception [:message]

  @impl true
  def message(%{message: message}), do: message
end
