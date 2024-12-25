defmodule Flatbuffer.Schema.TableTest do
  use ExUnit.Case
  alias Flatbuffer.Schema

  describe "Schema.from_string/1" do
    test "with a single table it will return the correct result" do
      schema = """
      table Table {
      }

      root_type Table;
      """

      assert {:ok,
              %Schema{
                entities: %{"Table" => {:table, %{fields: [], indices: %{}}}},
                root_type: {:table, %{name: "Table"}},
                id: nil
              }} == Schema.from_string(schema)
    end

    test "with a nested table it will return the correct result" do
      schema = """
      table Table {
        nested_table: NestedTable;
      }

      table NestedTable {
      }

      root_type Table;
      """

      assert {
               :ok,
               %Schema{
                 entities: %{
                   "Table" => {
                     :table,
                     %{
                       fields: [{:nested_table, {:table, %{name: "NestedTable"}}}],
                       indices: %{nested_table: {0, {:table, %{name: "NestedTable"}}}}
                     }
                   },
                   "NestedTable" => {:table, %{fields: [], indices: %{}}}
                 },
                 id: nil,
                 root_type: {:table, %{name: "Table"}}
               }
             } == Schema.from_string(schema)
    end

    test "with a all sorts of fields it will return the correct result" do
      schema = """
      table Table {
        byte: byte;
        ubyte: ubyte;
        short: short;
        ushort: ushort;
        int: int;
        uint: uint;
        long: long;
        ulong: ulong;
        float: float;
        double: double;

        nested_table: NestedTable;
        enum: ByteEnum;

        string: string;
        vector_of_byte: [byte];
        vector_of_ubyte: [ubyte];
        vector_of_short: [short];
        vector_of_ushort: [ushort];
        vector_of_int: [int];
        vector_of_uint: [uint];
        vector_of_long: [long];
        vector_of_ulong: [ulong];
        vector_of_float: [float];
        vector_of_double: [double];
        vector_of_string: [string];
        vector_of_nested_table: [NestedTable];
        vector_of_byte_enum: [ByteEnum];

        struct: Struct;
        vector_of_struct: [Struct];
      }

      enum ByteEnum : byte {
        A,
        B,
        C
      }

      struct Struct {
        field1: byte;
        field2: short;
      }

      table NestedTable {
      }

      root_type Table;
      """

      assert {
               :ok,
               %Schema{
                 entities: %{
                   "NestedTable" => {:table, %{fields: [], indices: %{}}},
                   "Table" => {
                     :table,
                     %{
                       fields: [
                         {:byte, {:byte, %{default: 0}}},
                         {:ubyte, {:ubyte, %{default: 0}}},
                         {:short, {:short, %{default: 0}}},
                         {:ushort, {:ushort, %{default: 0}}},
                         {:int, {:int, %{default: 0}}},
                         {:uint, {:uint, %{default: 0}}},
                         {:long, {:long, %{default: 0}}},
                         {:ulong, {:ulong, %{default: 0}}},
                         {:float, {:float, %{default: 0}}},
                         {:double, {:double, %{default: 0}}},
                         {:nested_table, {:table, %{name: "NestedTable"}}},
                         {:enum, {:enum, %{name: "ByteEnum"}}},
                         {:string, {:string, %{}}},
                         {:vector_of_byte, {:vector, {:byte, %{default: 0}}}},
                         {:vector_of_ubyte, {:vector, {:ubyte, %{default: 0}}}},
                         {:vector_of_short, {:vector, {:short, %{default: 0}}}},
                         {:vector_of_ushort, {:vector, {:ushort, %{default: 0}}}},
                         {:vector_of_int, {:vector, {:int, %{default: 0}}}},
                         {:vector_of_uint, {:vector, {:uint, %{default: 0}}}},
                         {:vector_of_long, {:vector, {:long, %{default: 0}}}},
                         {:vector_of_ulong, {:vector, {:ulong, %{default: 0}}}},
                         {:vector_of_float, {:vector, {:float, %{default: 0}}}},
                         {:vector_of_double, {:vector, {:double, %{default: 0}}}},
                         {:vector_of_string, {:vector, {:string, %{}}}},
                         {:vector_of_nested_table, {:vector, {:table, %{name: "NestedTable"}}}},
                         {:vector_of_byte_enum, {:vector, {:enum, %{name: "ByteEnum"}}}},
                         {:struct, {:struct, %{name: "Struct"}}},
                         {:vector_of_struct, {:vector, {:struct, %{name: "Struct"}}}}
                       ],
                       indices: %{
                         nested_table: {10, {:table, %{name: "NestedTable"}}},
                         byte: {0, {:byte, %{default: 0}}},
                         double: {9, {:double, %{default: 0}}},
                         enum: {11, {:enum, %{name: "ByteEnum"}}},
                         float: {8, {:float, %{default: 0}}},
                         int: {4, {:int, %{default: 0}}},
                         long: {6, {:long, %{default: 0}}},
                         short: {2, {:short, %{default: 0}}},
                         string: {12, {:string, %{}}},
                         ubyte: {1, {:ubyte, %{default: 0}}},
                         uint: {5, {:uint, %{default: 0}}},
                         ulong: {7, {:ulong, %{default: 0}}},
                         ushort: {3, {:ushort, %{default: 0}}},
                         vector_of_byte: {13, {:vector, {:byte, %{default: 0}}}},
                         vector_of_double: {22, {:vector, {:double, %{default: 0}}}},
                         vector_of_float: {21, {:vector, {:float, %{default: 0}}}},
                         vector_of_int: {17, {:vector, {:int, %{default: 0}}}},
                         vector_of_long: {19, {:vector, {:long, %{default: 0}}}},
                         vector_of_nested_table:
                           {24, {:vector, {:table, %{name: "NestedTable"}}}},
                         vector_of_short: {15, {:vector, {:short, %{default: 0}}}},
                         vector_of_string: {23, {:vector, {:string, %{}}}},
                         vector_of_ubyte: {14, {:vector, {:ubyte, %{default: 0}}}},
                         vector_of_uint: {18, {:vector, {:uint, %{default: 0}}}},
                         vector_of_ulong: {20, {:vector, {:ulong, %{default: 0}}}},
                         vector_of_ushort: {16, {:vector, {:ushort, %{default: 0}}}},
                         vector_of_byte_enum: {25, {:vector, {:enum, %{name: "ByteEnum"}}}},
                         struct: {26, {:struct, %{name: "Struct"}}},
                         vector_of_struct: {27, {:vector, {:struct, %{name: "Struct"}}}}
                       }
                     }
                   },
                   "Struct" => {:struct, %{members: [field1: :byte, field2: :short]}},
                   "ByteEnum" =>
                     {:enum,
                      %{
                        type: {:byte, %{default: 0}},
                        members: %{0 => :A, 1 => :B, 2 => :C, :B => 1, :C => 2, :A => 0}
                      }}
                 },
                 id: nil,
                 root_type: {:table, %{name: "Table"}}
               }
             } == Schema.from_string(schema)
    end
  end
end
