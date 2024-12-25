[![Build Status](https://github.com/jallum/flatbuffer/workflows/CI/badge.svg)](https://github.com/jallum/flatbuffer/actions) [![Hex.pm](https://img.shields.io/hexpm/v/flatbuffer.svg)](https://hex.pm/packages/flatbuffer) [![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/flatbuffer/)


---

# Flatbuffer

This is a [flatbuffers](https://google.github.io/flatbuffers/) implementation in Elixir.

In contrast to existing implementations there is no need to compile code from a schema. Instead, data and schemas are processed dynamically at runtime, offering greater flexibility.

## Using Flatbuffer

Schema file:
```
table Root {
  foreground:Color;
  background:Color;
}

table Color {
  red:   ubyte;
  green: ubyte;
  blue:  ubyte;
}
root_type Root;
```

Parsing the schema:
```elixir
iex(1)> {:ok, schema} = Flatbuffer.Schema.from_file("Example.fbs")
{:ok,
 %Flatbuffer.Schema{
   entities: %{
     "Color" => {:table,
      %{
        fields: [
          red: {:ubyte, %{default: 0}},
          green: {:ubyte, %{default: 0}},
          blue: {:ubyte, %{default: 0}}
        ],
        indices: %{
          blue: {2, {:ubyte, %{default: 0}}},
          green: {1, {:ubyte, %{default: 0}}},
          red: {0, {:ubyte, %{default: 0}}}
        }
      }},
     "Root" => {:table,
      %{
        fields: [
          foreground: {:table, %{name: "Color"}},
          background: {:table, %{name: "Color"}}
        ],
        indices: %{
          foreground: {0, {:table, %{name: "Color"}}},
          background: {1, {:table, %{name: "Color"}}}
        }
      }}
   },
   root_type: {:table, %{name: "Root"}},
   id: nil
 }}
 ```

Serializing data:

```elixir
iex(2)> color_scheme = %{foreground: %{red: 128, green: 20, blue: 255}, background: %{red: 0, green: 100, blue: 128}}
iex(3)> color_scheme_fb = Flatbuffer.to_binary(color_scheme, schema)
<<16, 0, 0, 0, 0, 0, 0, 0, 8, 0, 12, 0, 4, 0, 8, 0, 8, 0, 0, 0, 18, 0, 0,
  0, 31, 0, 0, 0, 10, 0, 7, 0, 4, 0, 5, 0, 6, 0, 10, 0, 0, 0, 128, 20,
  255, 10, 0, 6, 0, 0, ...>>
```

So we can `read` the whole thing which converts it back into a map:

```elixir
iex(4)> Flatbuffer.read!(color_scheme_fb, schema)
%{
  foreground: %{blue: 255, green: 20, red: 128},
  background: %{blue: 128, green: 100, red: 0}
}
```

Or we can `get` a portion with means it seeks into the flatbuffer and only deserializes the part below the path:
```elixir
iex(5)> Flatbuffer.get!(color_scheme_fb, [:background], schema)
%{blue: 128, green: 100, red: 0}
iex(6)> Flatbuffer.get!(color_scheme_fb, [:background, :green], schema)
100
```

## Comparing Flatbufer to flatc

### features both in Flatbufer and flatc

* tables
* scalars
* strings
* vflatbufferrs
* structs
* unions
* enums
* defaults
* file identifier + validation
* random access
* validate file identifiers
* includes

### features only in flatcs

* shared strings
* shared vtables
* alignment
* additional attributes