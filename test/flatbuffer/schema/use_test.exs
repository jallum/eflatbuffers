defmodule Flatbuffer.Schema.UseTest do
  use ExUnit.Case

  defmodule TestSchema do
    use Flatbuffer,
      path: "test/examples",
      file: "test_schema.fbs"
  end

  describe "When using a schema to build a module" do
    test "it will build the schema correctly" do
      assert %Flatbuffer.Schema{
               entities: %{
                 "test.Table" =>
                   {:table,
                    %{
                      fields: [foo: {:int, %{default: 0}}],
                      indices: %{foo: {0, {:int, %{default: 0}}}}
                    }}
               },
               id: nil,
               root_type: {:table, %{name: "test.Table"}}
             } == TestSchema.schema()
    end

    test "it will encode and decode a map correctly" do
      binary_value =
        "0E00000000000000060008000400060000000C000000"
        |> Base.decode16!()

      assert ^binary_value = TestSchema.to_binary(%{foo: 12})

      assert {:ok, %{foo: 12}} == TestSchema.read(binary_value)
    end

    test "it will pick out a value correctly" do
      binary_value =
        "0E00000000000000060008000400060000000C000000"
        |> Base.decode16!()

      assert {:ok, 12} = TestSchema.get(binary_value, [:foo])
    end
  end
end
