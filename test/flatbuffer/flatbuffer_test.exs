defmodule Flatbuffer.FlatbufferTest do
  use ExUnit.Case
  doctest Flatbuffer

  def schema do
    """
    table Root {
      field: int;
      nested_table: Nested;
      x_or_y: X_or_Y;
    }

    table Nested {
      nested_field: int;
    }

    union X_or_Y {
      X,
      Y
    }

    table X {
      x: int;
    }

    table Y {
      y: string;
    }

    root_type Root;
    """
    |> Flatbuffer.Schema.from_string()
    |> then(fn {:ok, schema} -> schema end)
  end

  def fb do
    %{
      field: 1,
      nested_table: %{
        nested_field: 2
      }
    }
    |> Flatbuffer.to_binary(schema())
  end

  describe "Flatbuffer.read/2" do
    test "it will return the correct structure" do
      assert {:ok,
              %{
                field: 1,
                nested_table: %{
                  nested_field: 2
                }
              }} ==
               Flatbuffer.read(fb(), schema())
    end

    test "it will return the correct structure with a union" do
      map = %{
        field: 1,
        nested_table: %{
          nested_field: 2
        },
        x_or_y_type: "Y",
        x_or_y: %{
          y: "string"
        }
      }

      fb = Flatbuffer.to_binary(map, schema())
      assert {:ok, map} == Flatbuffer.read(fb, schema())
    end
  end

  describe "Flatbuffer.get/4" do
    test "it will return a value given a valid key or path" do
      schema = schema()
      assert 2 = Flatbuffer.get(fb(), [:nested_table, :nested_field], schema)
      assert 1 = Flatbuffer.get(fb(), :field, schema)
    end

    test "it will return nil for an invalid key or path" do
      schema = schema()
      assert nil == Flatbuffer.get(fb(), [:nested_table, :does_not_exist], schema)
      assert nil == Flatbuffer.get(fb(), :does_not_exist, schema)
    end

    test "it will return the correct type when given a type key for a union field" do
      schema = schema()

      fb_y =
        %{
          x_or_y_type: "Y",
          x_or_y: %{
            y: "string"
          }
        }
        |> Flatbuffer.to_binary(schema)

      assert "Y" == Flatbuffer.get(fb_y, :x_or_y_type, schema)

      fb_x =
        %{
          x_or_y_type: "X",
          x_or_y: %{
            x: 3
          }
        }
        |> Flatbuffer.to_binary(schema)

      assert "X" == Flatbuffer.get(fb_x, :x_or_y_type, schema)
    end
  end

  describe "Flatbuffer.fetch/4" do
    test "it will return a value given a valid key or path" do
      schema = schema()
      assert {:ok, 2} = Flatbuffer.fetch(fb(), [:nested_table, :nested_field], schema)
      assert {:ok, 1} = Flatbuffer.fetch(fb(), :field, schema)
    end

    test "it will return :error for an invalid key or path" do
      schema = schema()
      assert :error = Flatbuffer.fetch(fb(), [:nested_table, :does_not_exist], schema)
      assert :error = Flatbuffer.fetch(fb(), :does_not_exist, schema)
    end
  end

  describe "Flatbuffer.fetch!/4" do
    test "it will return a value given a valid key or path" do
      schema = schema()
      assert 2 = Flatbuffer.fetch!(fb(), [:nested_table, :nested_field], schema)
      assert 1 = Flatbuffer.fetch!(fb(), :field, schema)
    end

    test "it will return :error for an invalid key or path" do
      schema = schema()

      assert_raise KeyError, fn ->
        Flatbuffer.fetch!(fb(), [:nested_table, :does_not_exist], schema)
      end

      assert_raise KeyError, fn ->
        Flatbuffer.fetch!(fb(), :does_not_exist, schema)
      end
    end
  end
end
