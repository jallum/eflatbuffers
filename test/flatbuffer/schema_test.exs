defmodule Flatbuffer.SchemaTest do
  use ExUnit.Case
  alias Flatbuffer.Schema

  describe "Schema.from_string/1" do
    test "when given a schema that does not declare a root type, returns the correct error" do
      schema = """
      table Table {
      }
      """

      assert {:error, :root_type_is_undefined} == Schema.from_string(schema)
    end

    test "when given a schema that declares a root type that is not a table, returns the correct error" do
      schema = """
      struct Struct {
        field1: byte;
      }

      root_type Struct;
      """

      assert {:error, {:root_type_is_not_a_table, "Struct"}} == Schema.from_string(schema)
    end
  end
end
