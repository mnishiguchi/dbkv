defmodule DBKV do
  @moduledoc """
  A disk-based key-value store built on top of [`:dets`](https://erlang.org/doc/man/dets.html).
  Inspired by [CubDB](https://github.com/lucaong/cubdb)'s intuitive API.
  """

  alias DBKV.MatchSpec

  #
  # Table commands
  #

  @spec create_table(keyword) :: :ok | {:error, any}
  def create_table(opts \\ []) do
    name = Keyword.fetch!(opts, :name)
    data_dir = opts[:data_dir] || "tmp"
    File.mkdir_p!(data_dir)

    case :dets.open_file(dets_name(name), file: dets_file(data_dir, name), type: :set) do
      {:ok, ^name} -> :ok
      error -> error
    end
  end

  defp dets_name(name) when is_atom(name), do: name

  defp dets_file(data_dir, name), do: :binary.bin_to_list("#{data_dir}/#{name}.db")

  @spec delete_table(atom) :: :ok | {:error, any}
  def delete_table(table_name) do
    :dets.close(table_name)
  end

  @spec describe_table(atom) :: map | :undefined
  def describe_table(table_name) when is_atom(table_name) do
    case :dets.info(table_name) do
      :undefined -> :undefined
      info_list -> Enum.into(info_list, %{})
    end
  end

  @spec exist?(atom) :: boolean
  def exist?(table_name) when is_atom(table_name) do
    table_name in :dets.all()
  end

  @spec size(atom) :: integer | :undefined
  def size(table_name) when is_atom(table_name) do
    case :dets.info(table_name, :size) do
      :undefined -> :undefined
      size -> size
    end
  end

  #
  # CRUD commands
  #

  @spec has_key?(atom, any) :: boolean
  def has_key?(table_name, key) when is_atom(table_name) do
    ensure_table_exists(table_name, fn ->
      !is_nil(get(table_name, key))
    end)
  end

  @spec get(atom, any, any) :: any
  def get(table_name, key, default \\ nil) when is_atom(table_name) do
    ensure_table_exists(table_name, fn ->
      case :dets.lookup(table_name, key) do
        [] -> default
        [{_key, value} | _rest] -> value
      end
    end)
  end

  @spec put(atom, any, any) :: :ok | {:error, any}
  def put(table_name, key, value) when is_atom(table_name) do
    ensure_table_exists(table_name, fn ->
      :dets.insert(table_name, [{key, value}])
    end)
  end

  @spec put_new(atom, any, any) :: :ok | {:error, any}
  def put_new(table_name, key, value) when is_atom(table_name) do
    ensure_table_exists(table_name, fn ->
      case :dets.insert_new(table_name, [{key, value}]) do
        false -> {:error, :exists}
        true -> :ok
        error -> error
      end
    end)
  end

  @spec update(atom, any, any, (any -> any)) :: :ok | {:error, any}
  def update(table_name, key, default, fun) when is_atom(table_name) and is_function(fun) do
    ensure_table_exists(table_name, fn ->
      case get(table_name, key) do
        nil -> put(table_name, key, default)
        value -> put(table_name, key, fun.(value))
      end
    end)
  end

  @spec delete(atom, any) :: :ok | {:error, any}
  def delete(table_name, key) when is_atom(table_name) do
    ensure_table_exists(table_name, fn ->
      :dets.delete(table_name, key)
    end)
  end

  @spec select_by_match_spec(atom, list) :: list
  def select_by_match_spec(table_name, match_spec) do
    ensure_table_exists(table_name, fn ->
      :dets.select(table_name, match_spec)
    end)
  end

  @spec select_by_key_range(atom, any, any, list) :: list
  def select_by_key_range(table_name, min_key, max_key, opts \\ []) do
    ensure_table_exists(table_name, fn ->
      match_spec = MatchSpec.key_range(min_key, max_key, opts)
      :dets.select(table_name, match_spec)
    end)
  end

  @spec select_by_min_key(atom, any) :: list
  def select_by_min_key(table_name, min_key) do
    ensure_table_exists(table_name, fn ->
      match_spec = MatchSpec.min_key(min_key)
      :dets.select(table_name, match_spec)
    end)
  end

  @spec select_by_max_key(atom, any, list) :: list
  def select_by_max_key(table_name, max_key, opts \\ []) do
    ensure_table_exists(table_name, fn ->
      match_spec = MatchSpec.max_key(max_key, opts)
      :dets.select(table_name, match_spec)
    end)
  end

  @spec select_by_value_range(atom, any, any, list) :: list
  def select_by_value_range(table_name, min_value, max_value, opts \\ []) do
    ensure_table_exists(table_name, fn ->
      match_spec = MatchSpec.value_range(min_value, max_value, opts)
      :dets.select(table_name, match_spec)
    end)
  end

  @spec select_by_min_value(atom, any) :: list
  def select_by_min_value(table_name, min_value) do
    ensure_table_exists(table_name, fn ->
      match_spec = MatchSpec.min_value(min_value)
      :dets.select(table_name, match_spec)
    end)
  end

  @spec select_by_max_value(atom, any, list) :: list
  def select_by_max_value(table_name, max_value, opts \\ []) do
    ensure_table_exists(table_name, fn ->
      match_spec = MatchSpec.max_value(max_value, opts)
      :dets.select(table_name, match_spec)
    end)
  end

  #
  # Helpers
  #

  defp ensure_table_exists(table_name, fun) do
    if exist?(table_name) do
      fun.()
    else
      {:error, :table_not_exists}
    end
  end
end
