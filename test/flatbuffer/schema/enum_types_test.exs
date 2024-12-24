defmodule Flatbuffer.Schema.EnumTypesTest do
  use ExUnit.Case,
    async: true

  use ExUnit.Case,
    parameterize: [
      %{type: :byte},
      %{type: :ubyte},
      %{type: :short},
      %{type: :ushort},
      %{type: :int},
      %{type: :uint},
      %{type: :long},
      %{type: :ulong}
    ]

  alias Flatbuffer.Schema

  describe "from_string/1" do
    test "when given a schema with an enum it will return the correct result",
         %{type: type} do
      expected_enum_name = RandomIdentifier.generate()

      expected_name_1 = RandomIdentifier.generate()
      expected_name_2 = RandomIdentifier.generate()
      expected_name_3 = RandomIdentifier.generate()

      expected_atom_1 = String.to_atom(expected_name_1)
      expected_atom_2 = String.to_atom(expected_name_2)
      expected_atom_3 = String.to_atom(expected_name_3)

      expected_table_name = RandomIdentifier.generate()

      schema = """
      enum #{expected_enum_name}: #{type} {
        #{expected_name_1},
        #{expected_name_2},
        #{expected_name_3}
      }

      table #{expected_table_name} {
        v: #{expected_enum_name};
      }

      root_type #{expected_table_name};
      """

      assert {:ok,
              %Flatbuffer.Schema{
                entities: %{
                  ^expected_enum_name =>
                    {:enum,
                     %{
                       type: {^type, %{default: 0}},
                       members: %{
                         0 => ^expected_atom_1,
                         1 => ^expected_atom_2,
                         2 => ^expected_atom_3,
                         ^expected_atom_3 => 2,
                         ^expected_atom_2 => 1,
                         ^expected_atom_1 => 0
                       }
                     }},
                  ^expected_table_name =>
                    {:table,
                     %{
                       fields: [v: {:enum, %{name: ^expected_enum_name}}],
                       indices: %{v: {0, {:enum, %{name: ^expected_enum_name}}}}
                     }}
                },
                root_type: {:table, %{name: ^expected_table_name}},
                id: nil
              }} = Schema.from_string(schema)
    end
  end
end
