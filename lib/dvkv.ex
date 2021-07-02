defmodule DBKV do
  @moduledoc """
  A disk-based key-value store built on top of [`:dets`](https://erlang.org/doc/man/dets.html).
  Inspired by [CubDB](https://github.com/lucaong/cubdb)'s intuitive API.
  """

  alias DBKV.BooleanMatchSpec
  alias DBKV.FinderMatchSpec

  @type t :: atom

  #
  # Table
  #

  @doc """
  Opens a table. An empty `:dets` table is created if no file exists.
  """
  @spec open(keyword) :: {:ok, t} | {:error, any}
  def open(opts \\ []) do
    name = Keyword.fetch!(opts, :name)
    data_dir = opts[:data_dir] || "tmp"
    File.mkdir_p!(data_dir)

    :dets.open_file(dets_name(name), file: dets_file(data_dir, name), type: :set)
  end

  @deprecated "Use `open/1` instead"
  def create_table(opts \\ []) do
    case open(opts) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  defp dets_name(name) when is_atom(name), do: name

  defp dets_file(data_dir, name), do: :binary.bin_to_list("#{data_dir}/#{name}.db")

  @doc """
  Closes a table. Only processes that have opened a table are allowed to close it.
  All open tables must be closed before the system is stopped.
  """
  @spec close(t) :: :ok | {:error, any}
  def close(table) do
    :dets.close(table)
  end

  @deprecated "Use `close/1` instead"
  def delete_table(table), do: delete_table(table)

  @doc """
  Returns information about `table`.
  """
  @spec info(t) :: map | :undefined
  def info(table) when is_atom(table) do
    case :dets.info(table) do
      :undefined -> :undefined
      info_list -> Enum.into(info_list, %{})
    end
  end

  @deprecated "Use `info/1` instead"
  def describe_table(table), do: info(table)

  @doc """
  Returns whether `table` is open.
  """
  @spec open?(t) :: boolean
  def open?(table) when is_atom(table) do
    table in :dets.all()
  end

  @deprecated "Use `open?/1` instead"
  def exist?(table), do: open?(table)

  @doc """
  Returns the size of the collection in `table`.
  """
  @spec size(t) :: integer | :undefined
  def size(table) when is_atom(table) do
    case :dets.info(table, :size) do
      :undefined -> :undefined
      size -> size
    end
  end

  @doc """
  Returns whether the given `key` exists in `table`.
  """
  @spec has_key?(t, any) :: boolean
  def has_key?(table, key) when is_atom(table) do
    case :dets.member(table, key) do
      true -> true
      _ -> false
    end
  end

  #
  # CRUD
  #

  @doc """
  Gets the value for a specific `key` in `table`.
  """
  @spec get(t, any, any) :: any
  def get(table, key, default \\ nil) when is_atom(table) do
    case :dets.lookup(table, key) do
      [] -> default
      [{_key, value} | _rest] -> value
    end
  end

  @doc """
  Puts the given `value` under `key` in `table`.
  """
  @spec put(t, any, any) :: :ok | {:error, any}
  def put(table, key, value) when is_atom(table) do
    :dets.insert(table, [{key, value}])
  end

  @doc """
  Puts the given `value` under `key` unless the entry `key` already exists in `table`.
  """
  @spec put_new(t, any, any) :: :ok | {:error, any}
  def put_new(table, key, value) when is_atom(table) do
    case :dets.insert_new(table, [{key, value}]) do
      false -> {:error, :exists}
      true -> :ok
      error -> error
    end
  end

  @doc """
  Updates the `key` in `table` with the given function.

  If `key` is present in `table` then the existing `value` is passed to `fun` and its result is
  used as the updated value of `key`. If `key` is not present in `table`, `default` is inserted as
  the value of `key`. The default value will not be passed through the update function.
  """
  @spec update(t, any, any, (any -> any)) :: :ok | {:error, any}
  def update(table, key, default, fun) when is_atom(table) and is_function(fun) do
    case get(table, key) do
      nil -> put(table, key, default)
      value -> put(table, key, fun.(value))
    end
  end

  @doc """
  Deletes the entry in `table` for a specific `key`.
  """
  @spec delete(t, any) :: :ok | {:error, any}
  def delete(table, key) when is_atom(table) do
    :dets.delete(table, key)
  end

  @doc """
  Deletes all entries from `table`.
  """
  @spec delete_all(t) :: :ok | {:error, any}
  def delete_all(table) when is_atom(table) do
    :dets.delete_all_objects(table)
  end

  #
  # Counter
  #

  @doc """
  Increment a number field by one.
  """
  @spec increment(t, any, number) :: number
  def increment(table, key, by) do
    :dets.update_counter(table, key, by)
  end

  @doc """
  Decrement a number field by one.
  """
  @spec decrement(t, any, number) :: number
  def decrement(table, key, by) do
    :dets.update_counter(table, key, -by)
  end

  #
  # Select
  #

  @doc """
  Returns all entries from `table`.
  """
  @spec all(t) :: list
  def all(table) do
    match_spec = FinderMatchSpec.all()
    select_by_match_spec(table, match_spec)
  end

  @doc """
  Returns all `keys` from `table`.
  """
  @spec keys(t) :: list
  def keys(table) do
    match_spec = FinderMatchSpec.keys()
    select_by_match_spec(table, match_spec)
  end

  @doc """
  Returns all `values` from `table`.
  """
  @spec values(t) :: list
  def values(table) do
    match_spec = FinderMatchSpec.values()
    select_by_match_spec(table, match_spec)
  end

  @doc """
  Returns the results of applying `match_spec` to all or `n` entries stored in `table`.
  """
  @spec select_by_match_spec(t, list, non_neg_integer()) :: list
  def select_by_match_spec(table, match_spec, n \\ :default) do
    case :dets.select(table, match_spec, n) do
      {list, _continuation} -> list
      :"$end_of_table" -> []
    end
  end

  @spec select_by_key_range(t, any, any, keyword) :: list
  def select_by_key_range(table, min_key, max_key, opts \\ []) do
    match_spec = FinderMatchSpec.key_range(min_key, max_key, opts)
    select_by_match_spec(table, match_spec)
  end

  @spec select_by_min_key(t, any, keyword) :: list
  def select_by_min_key(table, min_key, inclusive \\ true) do
    match_spec = FinderMatchSpec.min_key(min_key, inclusive)
    select_by_match_spec(table, match_spec)
  end

  @spec select_by_max_key(t, any, keyword) :: list
  def select_by_max_key(table, max_key, inclusive \\ true) do
    match_spec = FinderMatchSpec.max_key(max_key, inclusive)
    select_by_match_spec(table, match_spec)
  end

  @spec select_by_value_range(t, any, any, keyword) :: list
  def select_by_value_range(table, min_value, max_value, opts \\ []) do
    match_spec = FinderMatchSpec.value_range(min_value, max_value, opts)
    select_by_match_spec(table, match_spec)
  end

  @spec select_by_min_value(t, any, keyword) :: list
  def select_by_min_value(table, min_value, inclusive \\ true) do
    match_spec = FinderMatchSpec.min_value(min_value, inclusive)
    select_by_match_spec(table, match_spec)
  end

  @spec select_by_max_value(t, any, keyword) :: list
  def select_by_max_value(table, max_value, inclusive \\ true) do
    match_spec = FinderMatchSpec.max_value(max_value, inclusive)
    select_by_match_spec(table, match_spec)
  end

  #
  # Select delete
  #

  @spec delete_by_match_spec(t, list) :: integer | {:error, any}
  def delete_by_match_spec(table, match_spec) do
    :dets.select_delete(table, match_spec)
  end

  @spec delete_by_key_range(t, any, any, keyword) :: integer | {:error, any}
  def delete_by_key_range(table, min_key, max_key, opts \\ []) do
    match_spec = BooleanMatchSpec.key_range(min_key, max_key, opts)
    delete_by_match_spec(table, match_spec)
  end

  @spec delete_by_min_key(t, any, boolean) :: integer | {:error, any}
  def delete_by_min_key(table, min_key, inclusive \\ true) do
    match_spec = BooleanMatchSpec.min_key(min_key, inclusive)
    delete_by_match_spec(table, match_spec)
  end

  @spec delete_by_max_key(t, any, boolean) :: integer | {:error, any}
  def delete_by_max_key(table, max_key, inclusive \\ true) do
    match_spec = BooleanMatchSpec.max_key(max_key, inclusive)
    delete_by_match_spec(table, match_spec)
  end

  @spec delete_by_value_range(t, any, any, keyword) :: integer | {:error, any}
  def delete_by_value_range(table, min_value, max_value, opts \\ []) do
    match_spec = BooleanMatchSpec.value_range(min_value, max_value, opts)
    delete_by_match_spec(table, match_spec)
  end

  @spec delete_by_min_value(t, any, boolean) :: integer | {:error, any}
  def delete_by_min_value(table, min_value, inclusive \\ true) do
    match_spec = BooleanMatchSpec.min_value(min_value, inclusive)
    delete_by_match_spec(table, match_spec)
  end

  @spec delete_by_max_value(t, any, boolean) :: integer | {:error, any}
  def delete_by_max_value(table, max_value, inclusive \\ true) do
    match_spec = BooleanMatchSpec.max_value(max_value, inclusive)
    delete_by_match_spec(table, match_spec)
  end
end
