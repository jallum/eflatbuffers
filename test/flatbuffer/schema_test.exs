defmodule Flatbuffer.SchemaTest do
  use ExUnit.Case
  alias Flatbuffer.Schema

  describe "from_string/1" do
    test "when given a schema that does not declare a root type, returns the correct error" do
      schema = """
      table Table {
      }
      """

      assert {:error, :root_type_is_undefined} == Schema.from_string(schema)
    end
  end
end
