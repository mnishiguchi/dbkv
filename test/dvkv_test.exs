defmodule DBKVTest do
  # We cannot run this test async because the database file is global.
  use ExUnit.Case

  require Ex2ms

  # Checks equality ignoring the order.
  defp assert_equal(one, other) do
    case one do
      [{_k, _v}] -> assert Enum.into(one, %{}) == Enum.into(other, %{})
      [{_k, _v} | _more] -> assert Enum.into(one, %{}) == Enum.into(other, %{})
      list when is_list(list) -> assert Enum.sort(one) == Enum.sort(other)
    end
  end

  setup do
    table_name = :dbkv_test
    {:ok, ^table_name} = DBKV.open(name: table_name, data_dir: "tmp")

    on_exit(fn ->
      File.rm("tmp/dbkv_test.db")
    end)

    %{table_name: table_name}
  end

  test "when table not exists" do
    assert_raise ArgumentError, fn -> DBKV.get(:non_existent_table, 0) end
    assert_raise ArgumentError, fn -> DBKV.put(:non_existent_table, 0, 0) end
  end

  test "basic use", %{table_name: t} do
    assert %{
             file_size: _,
             filename: 'tmp/dbkv_test.db',
             keypos: _,
             size: _,
             type: :set
           } = DBKV.info(t)

    assert DBKV.open?(t)

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
    DBKV.open(name: t, data_dir: "tmp")
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

  test "all", %{table_name: t} do
    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}])
    assert_equal([{0, "a"}, {1, "b"}, {2, "c"}], DBKV.all(t))
  end

  test "keys", %{table_name: t} do
    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}])
    assert_equal([0, 1, 2], DBKV.keys(t))
  end

  test "values", %{table_name: t} do
    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}])
    assert_equal(["a", "b", "c"], DBKV.values(t))
  end

  test "select_by_match_spec", %{table_name: t} do
    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}, {3, "d"}, {4, "e"}])

    match_spec =
      Ex2ms.fun do
        {k, v} = kv when 1 <= k and k <= 3 -> kv
      end

    assert_equal([{1, "b"}, {2, "c"}, {3, "d"}], DBKV.select_by_match_spec(t, match_spec))

    # This may fail because dets does not guarantee the order.
    assert_equal([{3, "d"}], DBKV.select_by_match_spec(t, match_spec, 1))
  end

  test "select_by_key_range", %{table_name: t} do
    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}, {3, "d"}, {4, "e"}])
    assert_equal([{1, "b"}, {2, "c"}, {3, "d"}], DBKV.select_by_key_range(t, 1, 3))

    assert_equal(
      [{1, "b"}, {2, "c"}],
      DBKV.select_by_key_range(t, 1, 3, max_key_inclusive: false)
    )

    assert_equal([], DBKV.select_by_key_range(t, 10, 20))
  end

  test "select_by_min_key", %{table_name: t} do
    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}, {3, "d"}, {4, "e"}])
    assert_equal([{2, "c"}, {3, "d"}, {4, "e"}], DBKV.select_by_min_key(t, 2))
    assert_equal([], DBKV.select_by_min_key(t, 10))
  end

  test "select_by_max_key", %{table_name: t} do
    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}, {3, "d"}, {4, "e"}])
    assert_equal([{0, "a"}, {1, "b"}, {2, "c"}], DBKV.select_by_max_key(t, 2))
    assert_equal([{0, "a"}, {1, "b"}], DBKV.select_by_max_key(t, 2, false))
    assert_equal([], DBKV.select_by_max_key(t, -1))
  end

  test "select_by_value_range", %{table_name: t} do
    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}, {3, "d"}, {4, "e"}])

    assert_equal(
      [{1, "b"}, {2, "c"}, {3, "d"}],
      DBKV.select_by_value_range(t, "b", "d")
    )

    assert_equal(
      [{1, "b"}, {2, "c"}],
      DBKV.select_by_value_range(t, "b", "d", max_value_inclusive: false)
    )

    assert_equal([], DBKV.select_by_value_range(t, "v", "z"))
  end

  test "select_by_min_value", %{table_name: t} do
    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}, {3, "d"}, {4, "e"}])
    assert_equal([{2, "c"}, {3, "d"}, {4, "e"}], DBKV.select_by_min_value(t, "c"))
    assert_equal([], DBKV.select_by_min_value(t, "v"))
  end

  test "select_by_max_value", %{table_name: t} do
    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}, {3, "d"}, {4, "e"}])
    assert_equal([{0, "a"}, {1, "b"}, {2, "c"}], DBKV.select_by_max_value(t, "c"))

    assert_equal(
      [{0, "a"}, {1, "b"}],
      DBKV.select_by_max_value(t, "c", false)
    )

    assert_equal([], DBKV.select_by_max_value(t, "#"))
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
    assert 2 == DBKV.delete_by_key_range(t, 1, 3, max_inclusive: false)

    :ok = DBKV.init_table(t, [{0, "a"}, {1, "b"}, {2, "c"}, {3, "d"}, {4, "e"}])
    assert 1 == DBKV.delete_by_key_range(t, 1, 3, min_inclusive: false, max_inclusive: false)
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
    assert 1 == DBKV.delete_by_value_range(t, "b", "d", min_inclusive: false, max_inclusive: false)
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
end
