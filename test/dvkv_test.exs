defmodule DBKVTest do
  use ExUnit.Case
  @moduletag :tmp_dir

  require Ex2ms

  # Checks equality ignoring the order.
  defp equal?(one, other) do
    case one do
      [{_k, _v}] -> assert MapSet.new(one) == MapSet.new(other)
      non_keyword_list when is_list(non_keyword_list) -> assert Enum.sort(one) == Enum.sort(other)
      _ -> one == other
    end
  end

  setup context do
    table_name = :dbkv_test
    {:ok, ^table_name} = DBKV.open(name: table_name, data_dir: context.tmp_dir)

    %{table_name: table_name}
  end

  test "when table not exists" do
    assert_raise ArgumentError, fn -> DBKV.get(:non_existent_table, 0) end
    assert_raise ArgumentError, fn -> DBKV.put(:non_existent_table, 0, 0) end
  end

  test "basic use", %{tmp_dir: tmp_dir, table_name: t} do
    assert DBKV.open?(t)
    assert String.to_charlist("#{tmp_dir}/dbkv_test.db") == DBKV.filename(t)

    # Insert
    :ok = DBKV.put(t, :word, "Hi")
    assert "Hi" == DBKV.get(t, :word)
    assert 1 == DBKV.size(t)

    # Upsert
    :ok = DBKV.put(t, :word, "Hello")
    assert "Hello" == DBKV.get(t, :word)
    assert 1 == DBKV.size(t)

    # Insert new
    {:error, :exists} = DBKV.put_new(t, :word, "World")
    assert "Hello" == DBKV.get(t, :word)
    :ok = DBKV.put_new(t, :temp, 88)
    assert 88 == DBKV.get(t, :temp)
    assert 2 == DBKV.size(t)

    # Update
    :ok = DBKV.update(t, :word, "default", &(&1 <> "!!!"))
    assert "Hello!!!" == DBKV.get(t, :word)
    assert 2 == DBKV.size(t)

    :ok = DBKV.update(t, :lang, "Elixir", &(&1 <> "!!!"))
    assert "Elixir" == DBKV.get(t, :lang)
    assert 3 == DBKV.size(t)

    # Delete
    :ok = DBKV.delete(t, :word)
    assert is_nil(DBKV.get(t, :word))
    assert 2 == DBKV.size(t)

    # Data persistence across restart
    :ok = DBKV.close(t)
    refute DBKV.open?(t)
    DBKV.open(name: t, data_dir: tmp_dir)
    assert "Elixir" == DBKV.get(t, :lang)
  end

  test "delete_all", %{table_name: t} do
    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}])
    :ok = DBKV.delete_all(t)
    assert 0 == DBKV.size(t)
  end

  test "increment", %{table_name: t} do
    :ok = DBKV.put_new(t, "count", 0)

    assert 1 == DBKV.increment(t, "count", 1)
    assert 2 == DBKV.increment(t, "count", 1)
    assert 9 == DBKV.increment(t, "count", 7)
  end

  test "decrement", %{table_name: t} do
    :ok = DBKV.put_new(t, "count", 9)

    assert 8 == DBKV.decrement(t, "count", 1)
    assert 7 == DBKV.decrement(t, "count", 1)
    assert 0 == DBKV.decrement(t, "count", 7)
  end

  test "all/1", %{table_name: t} do
    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}])
    assert equal?([{0, "a"}, {1, "b"}, {2, "c"}], DBKV.all(t))
  end

  test "all/2", %{table_name: t} do
    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}])
    assert equal?(["0--a", "1--b", "2--c"], DBKV.all(t, fn k, v -> "#{k}--#{v}" end))
  end

  test "keys", %{table_name: t} do
    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}])
    assert equal?([0, 1, 2], DBKV.keys(t))
  end

  test "values", %{table_name: t} do
    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}])
    assert equal?(["a", "b", "c"], DBKV.values(t))
  end

  test "select_by_match_spec", %{table_name: t} do
    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}, {3, "d"}, {4, "e"}])

    match_spec =
      Ex2ms.fun do
        {k, v} = kv when 1 <= k and k <= 3 -> kv
      end

    assert equal?([{1, "b"}, {2, "c"}, {3, "d"}], DBKV.select_by_match_spec(t, match_spec))
    # This may fail because dets does not guarantee the order.
    assert equal?([{3, "d"}], DBKV.select_by_match_spec(t, match_spec, 1))
  end

  test "select_by_key_range", %{table_name: t} do
    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}, {3, "d"}, {4, "e"}])
    assert equal?([{1, "b"}, {2, "c"}, {3, "d"}], DBKV.select_by_key_range(t, 1, 3))

    assert equal?(
             [{2, "c"}, {3, "d"}],
             DBKV.select_by_key_range(t, 1, 3, min_inclusive: false)
           )

    assert equal?(
             [{1, "b"}, {2, "c"}],
             DBKV.select_by_key_range(t, 1, 3, max_inclusive: false)
           )

    assert equal?(
             [{2, "c"}],
             DBKV.select_by_key_range(t, 1, 3, min_inclusive: false, max_inclusive: false)
           )

    assert equal?([], DBKV.select_by_key_range(t, 10, 20))
  end

  test "select_by_min_key", %{table_name: t} do
    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}, {3, "d"}, {4, "e"}])
    assert equal?([{2, "c"}, {3, "d"}, {4, "e"}], DBKV.select_by_min_key(t, 2))
    assert equal?([], DBKV.select_by_min_key(t, 10))
  end

  test "select_by_max_key", %{table_name: t} do
    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}, {3, "d"}, {4, "e"}])
    assert equal?([{0, "a"}, {1, "b"}, {2, "c"}], DBKV.select_by_max_key(t, 2))
    assert equal?([{0, "a"}, {1, "b"}], DBKV.select_by_max_key(t, 2, false))
    assert equal?([], DBKV.select_by_max_key(t, -1))
  end

  test "select_by_value_range", %{table_name: t} do
    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}, {3, "d"}, {4, "e"}])

    assert equal?(
             [{1, "b"}, {2, "c"}, {3, "d"}],
             DBKV.select_by_value_range(t, "b", "d")
           )

    assert equal?(
             [{1, "b"}, {2, "c"}],
             DBKV.select_by_value_range(t, "b", "d", max_inclusive: false)
           )

    assert equal?([], DBKV.select_by_value_range(t, "v", "z"))
  end

  test "select_by_min_value", %{table_name: t} do
    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}, {3, "d"}, {4, "e"}])
    assert equal?([{2, "c"}, {3, "d"}, {4, "e"}], DBKV.select_by_min_value(t, "c"))
    assert equal?([], DBKV.select_by_min_value(t, "v"))
  end

  test "select_by_max_value", %{table_name: t} do
    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}, {3, "d"}, {4, "e"}])
    assert equal?([{0, "a"}, {1, "b"}, {2, "c"}], DBKV.select_by_max_value(t, "c"))

    assert equal?(
             [{0, "a"}, {1, "b"}],
             DBKV.select_by_max_value(t, "c", false)
           )

    assert equal?([], DBKV.select_by_max_value(t, "#"))
  end

  test "select_by_value", %{table_name: t} do
    :ok = DBKV.init_table(t, a: 0, b: 1, c: 1, d: 0)
    assert equal?([{:a, 0}, {:d, 0}], DBKV.select_by_value(t, 0))
    assert equal?([{:b, 1}, {:c, 1}], DBKV.select_by_value(t, 1))
    assert equal?([], DBKV.select_by_value(t, 2))
  end

  test "delete_by_match_spec", %{table_name: t} do
    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}, {3, "d"}, {4, "e"}])

    match_spec =
      Ex2ms.fun do
        {k, v} = kv when 2 <= k and k <= 3 -> true
      end

    assert 2 == DBKV.delete_by_match_spec(t, match_spec)
    assert 3 == DBKV.size(t)
  end

  test "delete_by_key_range", %{table_name: t} do
    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}, {3, "d"}, {4, "e"}])
    assert 3 == DBKV.delete_by_key_range(t, 1, 3)
    assert 2 == DBKV.size(t)

    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}, {3, "d"}, {4, "e"}])
    assert 2 == DBKV.delete_by_key_range(t, 2, 4, min_inclusive: false)

    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}, {3, "d"}, {4, "e"}])
    assert 2 == DBKV.delete_by_key_range(t, 1, 3, max_inclusive: false)

    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}, {3, "d"}, {4, "e"}])
    assert 1 == DBKV.delete_by_key_range(t, 0, 2, min_inclusive: false, max_inclusive: false)
  end

  test "delete_by_min_key", %{table_name: t} do
    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}])
    assert 2 == DBKV.delete_by_min_key(t, 1)
    assert 1 == DBKV.size(t)

    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}])
    assert 1 == DBKV.delete_by_min_key(t, 1, false)
  end

  test "delete_by_max_key", %{table_name: t} do
    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}])
    assert 2 == DBKV.delete_by_max_key(t, 1)
    assert 1 == DBKV.size(t)

    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}])
    assert 1 == DBKV.delete_by_max_key(t, 1, false)
  end

  test "delete_by_value_range", %{table_name: t} do
    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}, {3, "d"}, {4, "e"}])
    assert 3 == DBKV.delete_by_value_range(t, "b", "d")
    assert 2 == DBKV.size(t)

    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}, {3, "d"}, {4, "e"}])
    assert 2 == DBKV.delete_by_value_range(t, "b", "d", max_inclusive: false)

    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}, {3, "d"}, {4, "e"}])

    assert 1 ==
             DBKV.delete_by_value_range(t, "b", "d", min_inclusive: false, max_inclusive: false)
  end

  test "delete_by_min_value", %{table_name: t} do
    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}])
    assert 2 == DBKV.delete_by_min_value(t, "b")
    assert 1 == DBKV.size(t)

    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}])
    assert 1 == DBKV.delete_by_min_value(t, "b", false)
  end

  test "delete_by_max_value", %{table_name: t} do
    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}])
    assert 2 == DBKV.delete_by_max_value(t, "b")
    assert 1 == DBKV.size(t)

    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}])
    assert 1 == DBKV.delete_by_max_value(t, "b", false)
  end

  test "delete_by_value", %{table_name: t} do
    :ok = DBKV.init_table(t, a: 0, b: 1, c: 0)
    assert 2 == DBKV.delete_by_value(t, 0)

    :ok = DBKV.init_table(t, a: 0, b: 1, c: 0)
    assert 1 == DBKV.delete_by_value(t, 1)

    :ok = DBKV.init_table(t, a: 0, b: 1, c: 0)
    assert 0 == DBKV.delete_by_value(t, 2)
  end

  test "reduce/3", %{table_name: t} do
    :ok = DBKV.init_table(t, a: 1, b: 3, c: 5)

    assert equal?(
             [5, :c, 3, :b, 1, :a],
             DBKV.reduce(t, [], fn {k, v}, acc -> [v] ++ [k] ++ acc end)
           )
  end
end
