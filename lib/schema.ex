defmodule Eflatbuffers.Schema do
  @type resolver_fn :: (filename :: String.t() -> String.t())

  @type t :: {entities :: %{}, options :: keyword()}

  @spec from_file(file_name :: String.t(), opts :: [resolver: resolver_fn()]) ::
          {:ok, t()} | {:error, term()}
  def from_file(file_name, opts \\ []) do
    with resolver_fn <- opts[:resolver] || (&File.read/1),
         true <- is_function(resolver_fn, 1) || {:error, {:no_resolver, file_name}},
         {:ok, file_contents} <- resolver_fn.(file_name),
         {:ok, {entities, directives}} <- chain_load(file_name, file_contents, resolver_fn) do
      {:ok, {entities |> decorate(), directives}}
    end
  end

  @spec from_string(string :: String.t(), opts :: [resolver: resolver_fn()]) ::
          {:ok, t()} | {:error, term()}
  def from_string(string, opts \\ []) do
    case chain_load(:string, string, opts[:resolver]) do
      {:ok, entities} -> {:ok, {entities, []}}
      error -> error
    end
  end

  defp chain_load(source, file_contents, resolver_fn, loaded \\ []) do
    with {:ok, tokens, _} <- file_contents |> String.to_charlist() |> :schema_lexer.string(),
         {:ok, {entities, directives}} <- :schema_parser.parse(tokens),
         namespace <- directives[:namespace],
         root_type <- directives[:root_type],
         entities <- apply_namespace(entities, namespace),
         {:ok, root_type} <- determine_root_type(entities, root_type, namespace) do
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
          {:ok, {Map.merge(included_entities, entities), [root_type: root_type]}}
      end
    end
  end

  @spec determine_root_type(entities :: %{}, type_name :: String.t(), namespace :: String.t()) ::
          {:ok, {:table, %{name: String.t()}}}
          | {:error, :root_type_is_undefined}
          | {:root_type_not_found, type_name :: String.t()}
          | {:root_type_is_not_a_table, type_name :: String.t()}
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
    if String.starts_with?(name, namespace) do
      name
    else
      "#{namespace}.#{name}"
    end
  end

  # this preprocesses the schema in order to keep the read/write code as simple
  # as possible correlate tables with names and define defaults explicitly
  def decorate(entities) do
    Enum.reduce(
      entities,
      %{},
      fn
        # for a tables we transform the types to explicitly signify vectors,
        # tables, and enums
        {key, {:table, fields}}, acc ->
          Map.put(
            acc,
            key,
            {:table, table_options(fields, entities)}
          )

        # for enums we change the list of options into a map for faster lookup
        # when writing and reading
        {key, {{:enum, type}, fields}}, acc ->
          hash =
            Enum.reduce(
              Enum.with_index(fields),
              %{},
              fn {field, index}, hash_acc ->
                Map.put(hash_acc, field, index) |> Map.put(index, field)
              end
            )

          Map.put(acc, key, {:enum, %{type: {type, %{default: 0}}, members: hash}})

        {key, {:union, fields}}, acc ->
          hash =
            Enum.reduce(
              Enum.with_index(fields),
              %{},
              fn {field, index}, hash_acc ->
                Map.put(hash_acc, field, index) |> Map.put(index, field)
              end
            )

          Map.put(acc, key, {:union, %{members: hash}})

        {key, {:struct, fields}}, acc ->
          Map.put(acc, key, {:struct, %{members: fields}})
      end
    )
  end

  def table_options(fields, entities) do
    fields_and_indices(fields, entities, {0, [], %{}})
  end

  def fields_and_indices([], _, {_, fields, indices}),
    do: %{fields: Enum.reverse(fields), indices: indices}

  def fields_and_indices(
        [{field_name, field_value} | fields],
        entities,
        {index, fields_acc, indices_acc}
      ) do
    index_offset = index_offset(field_value, entities)
    decorated_type = decorate_field(field_value, entities)
    index_new = index + index_offset
    fields_acc_new = [{field_name, decorated_type} | fields_acc]
    indices_acc_new = Map.put(indices_acc, field_name, {index, decorated_type})
    fields_and_indices(fields, entities, {index_new, fields_acc_new, indices_acc_new})
  end

  def index_offset(field_value, entities) do
    case is_referenced?(field_value) do
      true ->
        case Map.get(entities, field_value) do
          {:union, _} ->
            2

          _ ->
            1
        end

      false ->
        1
    end
  end

  def decorate_field({:vector, type}, entities),
    do: {:vector, %{type: decorate_field(type, entities)}}

  def decorate_field(field_value, entities) do
    if is_referenced?(field_value) do
      decorate_referenced_field(field_value, entities)
    else
      decorate_field(field_value)
    end
  end

  def decorate_referenced_field({field_value, default_value}, entities) do
    case Map.get(entities, field_value) do
      nil ->
        throw({:error, {:entity_not_found, field_value}})

      {{:enum, _}, _} ->
        {:enum, %{name: field_value, default: default_value}}
    end
  end

  def decorate_referenced_field(field_value, entities) do
    case Map.get(entities, field_value) do
      nil ->
        throw({:error, {:entity_not_found, field_value}})

      {:table, _} ->
        {:table, %{name: field_value}}

      {{:enum, _}, _} ->
        {:enum, %{name: field_value}}

      {:union, _} ->
        {:union, %{name: field_value}}

      {:struct, _} ->
        {:struct, %{name: field_value}}
    end
  end

  def decorate_field({type, default}), do: {type, %{default: default}}
  def decorate_field(:bool), do: {:bool, %{default: false}}
  def decorate_field(:string), do: {:string, %{}}
  def decorate_field(type), do: {type, %{default: 0}}

  def is_referenced?({type, _default}), do: is_referenced?(type)
  def is_referenced?(type), do: not Enum.member?(literal_types(), type)

  defp literal_types,
    do: [
      :string,
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
    ]
end
