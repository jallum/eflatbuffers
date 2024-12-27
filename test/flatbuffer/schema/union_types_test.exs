defmodule FlatBuffer.Schema.UnionTypesTest do
  use ExUnit.Case
  alias Flatbuffer.Schema

  describe "union types" do
    test "union types" do
      schema = """
      file_identifier "cmnd";

      table hello
      {
        salute:string;
      }

      table bye
      {
        greeting:int;
      }
      union command { hello, bye }

      table command_root {
        data:command;
        additions_value:int;
      }

      root_type command_root;
      """

      assert {:ok,
              %Flatbuffer.Schema{
                entities: %{
                  "bye" =>
                    {:table,
                     %{
                       fields: [greeting: {:int, %{default: 0}}],
                       indices: %{greeting: {0, {:int, %{default: 0}}}}
                     }},
                  "command" =>
                    {:union, %{members: %{0 => "hello", 1 => "bye", "bye" => 1, "hello" => 0}}},
                  "command_root" =>
                    {:table,
                     %{
                       fields: [
                         data: {:union, %{name: "command"}},
                         additions_value: {:int, %{default: 0}}
                       ],
                       indices: %{
                         data: {0, {:union, %{name: "command"}}},
                         additions_value: {2, {:int, %{default: 0}}},
                         data_type: {0, {:union_type, "command"}}
                       }
                     }},
                  "hello" =>
                    {:table,
                     %{fields: [salute: {:string, %{}}], indices: %{salute: {0, {:string, %{}}}}}}
                },
                root_type: {:table, %{name: "command_root"}},
                id: "cmnd"
              }} == Schema.from_string(schema)
    end
  end
end
