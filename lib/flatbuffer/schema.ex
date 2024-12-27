defmodule Flatbuffer.Schema do
  @moduledoc """
  Schema definition and parser for FlatBuffers.

  Handles parsing and processing of FlatBuffer schema files (.fbs),
  including type definitions, namespaces, and includes. Supports:

  - Tables, structs, enums, and unions
  - Basic types (bool, int, float, string, etc.)
  - Vectors and references
  - Schema includes and namespaces
  - File identifiers

  ## Example
      {:ok, schema} = Schema.from_file("schema.fbs")
      # or
      {:ok, schema} = Schema.from_string(schema_string)

      # Optionally, you can supply a resolver for includes
      {:ok, schema} = Schema.from_file("schema.fbs", resolver: &File.read/1)
  """

  @type t :: %__MODULE__{
          entities: %{type_name() => type_def()},
          id: binary() | nil,
          root_type: type_ref()
        }
  defstruct entities: %{}, root_type: nil, id: nil

  @type type_name :: String.t()

  @type type_ref ::
          {:table, %{name: type_name()}}
          | {:struct, %{name: type_name()}}
          | {:enum, %{name: type_name()}}
          | {:union, %{name: type_name()}}
          | {:vector, type_ref()}
          | {:bool, %{default: boolean()}}
          | {:byte, %{default: integer()}}
          | {:ubyte, %{default: integer()}}
          | {:short, %{default: integer()}}
          | {:ushort, %{default: integer()}}
          | {:int, %{default: integer()}}
          | {:uint, %{default: integer()}}
          | {:long, %{default: integer()}}
          | {:ulong, %{default: integer()}}
          | {:float, %{default: float()}}
          | {:double, %{default: float()}}
          | {:string, %{default: String.t()}}

  @type type_def ::
          table_def()
          | struct_def()
          | union_def()
          | enum_def()

  @type field_name :: atom()

  @type table_def ::
          {:table,
           %{
             fields: [{field_name(), type_ref()}],
             indices: %{field_name() => {integer(), type_ref()}}
           }}

  @type struct_def :: {:struct, %{members: [{field_name(), type_def()}]}}

  @type union_def ::
          {:union,
           %{
             members: %{
               type_name() => integer(),
               integer() => type_name()
             }
           }}

  @type enum_name :: atom()
  @type enum_def :: {:enum, %{members: %{enum_name() => integer(), integer() => enum_name()}}}

  @type resolver_fn :: (filename :: String.t() -> String.t())

  @type from_errors ::
          {:error, {:no_resolver, file_name :: String.t()}}
          | {:error, :root_type_is_undefined}
          | {:error, {:root_type_not_found, type_name :: String.t()}}
          | {:error, {:root_type_is_not_a_table, type_name :: String.t()}}
          | {:error, {:type_not_found, type_name :: String.t()}}

  @doc """
  Reads and parses a FlatBuffer schema from a file.

  ## Parameters

    - `file_name` (String.t()): The path to the schema file.
    - `opts` ([resolver: resolver_fn()]): Optional keyword list of options.
      - `:resolver` (resolver_fn()): A function to resolve imports or includes within the schema.

  ## Returns

    - The parsed schema, or an error tuple if the schema could not be parsed.

  ## Examples

      iex> Flatbuffer.Schema.from_file("path/to/schema.fbs")
      {:ok, schema}

      iex> Flatbuffer.Schema.from_file("path/to/schema.fbs", resolver: &my_resolver/1)
      {:ok, schema}
  """
  @spec from_file(file_name :: String.t(), opts :: [resolver: resolver_fn()]) ::
          {:ok, t()} | from_errors()
  def from_file(file_name, opts \\ []) do
    with resolver_fn <- opts[:resolver] || (&File.read/1),
         true <- is_function(resolver_fn, 1) || {:error, {:no_resolver, file_name}},
         {:ok, file_contents} <- resolver_fn.(file_name),
         {:ok, {entities, directives}} <- chain_load(file_name, file_contents, resolver_fn),
         {:ok, entities} <- resolve_types(entities) do
      {:ok, new(entities, directives)}
    end
  end

  @doc """
  Parses a FlatBuffer schema from a string.

  ## Parameters

    - `string` (String.t()): The FlatBuffer schema as a string.
    - `opts` ([resolver: resolver_fn()]): Optional keyword list of options.
      - `:resolver` (resolver_fn()): A function used to resolve schema dependencies.

  ## Returns

  A parsed schema.

  ## Examples
    iex(1)> schema = \"""
    ...(1)> table Table {
    ...(1)>   field: int;
    ...(1)> }
    ...(1)>
    ...(1)> root_type Table;
    ...(1)> \"""
    iex(2)> {:ok, parsed_schema} = Flatbuffer.Schema.from_string(schema)
  """
  @spec from_string(string :: String.t(), opts :: [resolver: resolver_fn()]) ::
          {:ok, t()} | from_errors()
  def from_string(string, opts \\ []) do
    with {:ok, {entities, directives}} <- chain_load(:string, string, opts[:resolver]),
         {:ok, entities} <- resolve_types(entities) do
      {:ok, new(entities, directives)}
    end
  end

  defp new(entities, directives) do
    %__MODULE__{
      entities: entities,
      root_type: directives[:root_type],
      id: directives[:file_identifier]
    }
  end

  defp chain_load(source, file_contents, resolver_fn, loaded \\ []) do
    with {:ok, tokens, _} <-
           file_contents |> String.to_charlist() |> :flatbuffer_schema_lexer.string(),
         {:ok, {entities, directives}} <- :flatbuffer_schema_parser.parse(tokens),
         file_id <- directives[:file_identifier],
         namespace <- directives[:namespace],
         root_type_name <- directives[:root_type],
         entities <- apply_namespace(entities, namespace),
         {:ok, root_type} <- determine_root_type(entities, root_type_name, namespace) do
      directives
      |> find_include_files()
      |> Enum.reduce_while(%{}, fn
        file_name, entities ->
          cond do
            not is_function(resolver_fn, 1) ->
              {:halt, {:error, {:no_resolver, file_name}}}

            file_name in loaded ->
              {:cont, entities}

            true ->
              with {:ok, include_file_contents} <- resolver_fn.(file_name),
                   {:ok, {included_entities, _}} <-
                     chain_load(file_name, include_file_contents, resolver_fn, [source | loaded]) do
                {:cont, Map.merge(entities, included_entities)}
              else
                {:error, _reason} = error -> {:halt, error}
              end
          end
      end)
      |> case do
        {:error, reason} ->
          {:error, reason}

        included_entities ->
          {:ok,
           {Map.merge(included_entities, entities),
            [root_type: root_type, file_identifier: file_id]}}
      end
    end
  end

  @spec determine_root_type(entities :: %{}, type_name :: String.t(), namespace :: String.t()) ::
          {:ok, {:table, %{name: String.t()}}}
          | {:error, :root_type_is_undefined}
          | {:error, {:root_type_not_found, type_name :: String.t()}}
          | {:error, {:root_type_is_not_a_table, type_name :: String.t()}}
  defp determine_root_type(_, nil, _), do: {:error, :root_type_is_undefined}

  defp determine_root_type(entities, type_name, namespace) do
    namespaced_type_name = apply_namespace(type_name, namespace)

    case Map.get(entities, namespaced_type_name) do
      {:table, _members} -> {:ok, {:table, %{name: namespaced_type_name}}}
      nil -> {:error, {:root_type_not_found, type_name}}
      _ -> {:error, {:root_type_is_not_a_table, type_name}}
    end
  end

  defp find_include_files([{:include, file_name} | directives]),
    do: [file_name | find_include_files(directives)]

  defp find_include_files([_ | directives]), do: find_include_files(directives)
  defp find_include_files([]), do: []

  defp apply_namespace(type, nil), do: type
  defp apply_namespace(type, _) when is_atom(type), do: type

  defp apply_namespace(types, namespace) when is_map(types) do
    Map.new(types, fn
      {name, type} -> {apply_namespace(name, namespace), apply_namespace(type, namespace)}
    end)
  end

  defp apply_namespace({:table, fields}, namespace) do
    {:table,
     fields
     |> Enum.map(fn {field_name, field_type} ->
       {field_name, apply_namespace(field_type, namespace)}
     end)}
  end

  defp apply_namespace({:struct, fields}, namespace) do
    {:struct,
     fields
     |> Enum.map(fn {field_name, field_type} ->
       {field_name, apply_namespace(field_type, namespace)}
     end)}
  end

  defp apply_namespace({:enum, type}, namespace),
    do: {:enum, apply_namespace(type, namespace)}

  defp apply_namespace({:vector, type}, namespace),
    do: {:vector, apply_namespace(type, namespace)}

  defp apply_namespace({:union, types}, namespace),
    do: {:union, types |> Enum.map(&apply_namespace(&1, namespace))}

  defp apply_namespace({name, default_value}, namespace),
    do: {apply_namespace(name, namespace), default_value}

  defp apply_namespace(name, namespace) when is_binary(name) do
    if String.contains?(name, ".") do
      name
    else
      "#{namespace}.#{name}"
    end
  end

  # this preprocesses the schema in order to keep the read/write code as simple
  # as possible correlate tables with names and define defaults explicitly
  def resolve_types(entities) do
    {:ok,
     Enum.reduce(
       entities,
       %{},
       fn
         # for a tables we transform the types to explicitly signify vectors,
         # tables, and enums
         {key, {:table, fields}}, acc ->
           Map.put(acc, key, {:table, table_options(fields, entities)})

         # for enums we change the list of options into a map for faster lookup
         # when writing and reading
         {key, {{:enum, type}, members}}, acc ->
           members = enumerate_members(members)
           Map.put(acc, key, {:enum, %{type: {type, %{default: 0}}, members: members}})

         {key, {:union, members}}, acc ->
           members = enumerate_members(members)
           Map.put(acc, key, {:union, %{members: members}})

         {key, {:struct, fields}}, acc ->
           Map.put(acc, key, {:struct, %{members: fields}})
       end
     )}
  catch
    {:error, {:type_not_found, _type_name}} = error ->
      error
  end

  defp enumerate_members(members) do
    members
    |> Enum.with_index()
    |> Enum.reduce(
      %{},
      fn {field, index}, acc ->
        Map.put(acc, field, index) |> Map.put(index, field)
      end
    )
  end

  defp table_options(fields, entities) do
    {_, fields, indices} =
      fields
      |> Enum.reduce({0, [], %{}}, fn
        {name, type}, {index, fields, indices} ->
          resolved_type = resolve_type(type, entities)

          updated_indices =
            case resolved_type do
              {:union, %{name: union_name}} ->
                indices
                |> Map.put(name, {index, resolved_type})
                |> Map.put(:"#{name}_type", {index, {:union_type, union_name}})

              _ ->
                Map.put(indices, name, {index, resolved_type})
            end

          {
            next_index(index, resolved_type),
            [{name, resolved_type} | fields],
            updated_indices
          }
      end)

    %{fields: Enum.reverse(fields), indices: indices}
  end

  defp next_index(index, {:union, _}), do: index + 2
  defp next_index(index, _), do: index + 1

  defp resolve_type({:vector, type}, entities),
    do: {:vector, resolve_type(type, entities)}

  defp resolve_type(name, entities) when is_binary(name) do
    case Map.get(entities, name) do
      nil -> throw({:error, {:type_not_found, name}})
      {:table, _} -> {:table, %{name: name}}
      {{:enum, _}, _} -> {:enum, %{name: name}}
      {:union, _} -> {:union, %{name: name}}
      {:struct, _} -> {:struct, %{name: name}}
    end
  end

  defp resolve_type(:bool, _), do: {:bool, %{default: false}}
  defp resolve_type(:string, _), do: {:string, %{}}

  defp resolve_type(type, _)
       when type in [
              :byte,
              :ubyte,
              :bool,
              :short,
              :ushort,
              :int,
              :uint,
              :float,
              :long,
              :ulong,
              :double
            ],
       do: {type, %{default: 0}}

  defp resolve_type({type, default}, entities),
    do: resolve_type(type, entities) |> with_default_value(default)

  defp with_default_value({type, %{} = options}, default),
    do: {type, Map.put(options, :default, default)}
end
