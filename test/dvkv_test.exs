defmodule DBKVTest do
  # We cannot run this test async because the database file is global.
  use ExUnit.Case

  require Ex2ms

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

  test "basic use", %{table_name: dbkv} do
    assert %{
             file_size: _,
             filename: 'tmp/dbkv_test.db',
             keypos: _,
             size: _,
             type: :set
           } = DBKV.info(dbkv)

    assert DBKV.exist?(dbkv)

    # Insert
    :ok = DBKV.put(dbkv, :word, "Hi")
    assert "Hi" == DBKV.get(dbkv, :word)
    assert 1 == DBKV.size(dbkv)

    # Upsert
    :ok = DBKV.put(dbkv, :word, "Hello")
    assert "Hello" == DBKV.get(dbkv, :word)
    assert 1 == DBKV.size(dbkv)

    # Insert new
    {:error, :exists} = DBKV.put_new(dbkv, :word, "World")
    assert "Hello" == DBKV.get(dbkv, :word)
    :ok = DBKV.put_new(dbkv, :temp, 88)
    assert 88 == DBKV.get(dbkv, :temp)
    assert 2 == DBKV.size(dbkv)

    # Update
    :ok = DBKV.update(dbkv, :word, "default", &(&1 <> "!!!"))
    assert "Hello!!!" == DBKV.get(dbkv, :word)
    assert 2 == DBKV.size(dbkv)

    :ok = DBKV.update(dbkv, :lang, "Elixir", &(&1 <> "!!!"))
    assert "Elixir" == DBKV.get(dbkv, :lang)
    assert 3 == DBKV.size(dbkv)

    # Delete
    :ok = DBKV.delete(dbkv, :word)
    assert is_nil(DBKV.get(dbkv, :word))
    assert 2 == DBKV.size(dbkv)

    # Data persistence across restart
    :ok = DBKV.close(dbkv)
    refute DBKV.exist?(dbkv)
    DBKV.open(name: dbkv, data_dir: "tmp")
    assert "Elixir" == DBKV.get(dbkv, :lang)
  end

  test "delete_all", %{table_name: dbkv} do
    :ok = DBKV.put_new(dbkv, 0, "a")
    :ok = DBKV.put_new(dbkv, 1, "b")
    :ok = DBKV.put_new(dbkv, 2, "c")

    :ok = DBKV.delete_all(dbkv)
    assert 0 == DBKV.size(dbkv)
  end

  test "increment", %{table_name: dbkv} do
    :ok = DBKV.put_new(dbkv, "count", 0)

    assert 1 == DBKV.increment(dbkv, "count", 1)
    assert 2 == DBKV.increment(dbkv, "count", 1)
    assert 9 == DBKV.increment(dbkv, "count", 7)
  end

  test "decrement", %{table_name: dbkv} do
    :ok = DBKV.put_new(dbkv, "count", 9)

    assert 8 == DBKV.decrement(dbkv, "count", 1)
    assert 7 == DBKV.decrement(dbkv, "count", 1)
    assert 0 == DBKV.decrement(dbkv, "count", 7)
  end

  test "all", %{table_name: dbkv} do
    :ok = DBKV.put_new(dbkv, 0, "a")
    :ok = DBKV.put_new(dbkv, 1, "b")
    :ok = DBKV.put_new(dbkv, 2, "c")

    assert [{0, "a"}, {1, "b"}, {2, "c"}] == DBKV.all(dbkv)
  end

  test "keys", %{table_name: dbkv} do
    :ok = DBKV.put_new(dbkv, 0, "a")
    :ok = DBKV.put_new(dbkv, 1, "b")
    :ok = DBKV.put_new(dbkv, 2, "c")

    assert [0, 1, 2] == DBKV.keys(dbkv)
  end

  test "values", %{table_name: dbkv} do
    :ok = DBKV.put_new(dbkv, 0, "a")
    :ok = DBKV.put_new(dbkv, 1, "b")
    :ok = DBKV.put_new(dbkv, 2, "c")

    assert ["a", "b", "c"] == DBKV.values(dbkv)
  end

  test "select_by_match_spec", %{table_name: dbkv} do
    :ok = DBKV.put_new(dbkv, 0, "a")
    :ok = DBKV.put_new(dbkv, 1, "b")
    :ok = DBKV.put_new(dbkv, 2, "c")
    :ok = DBKV.put_new(dbkv, 3, "d")
    :ok = DBKV.put_new(dbkv, 4, "e")

    match_spec =
      Ex2ms.fun do
        {k, v} = kv when 1 <= k and k <= 3 -> kv
      end

    assert [{1, "b"}, {2, "c"}, {3, "d"}] == DBKV.select_by_match_spec(dbkv, match_spec)
  end

  test "select_by_key_range", %{table_name: dbkv} do
    :ok = DBKV.put_new(dbkv, 0, "a")
    :ok = DBKV.put_new(dbkv, 1, "b")
    :ok = DBKV.put_new(dbkv, 2, "c")
    :ok = DBKV.put_new(dbkv, 3, "d")
    :ok = DBKV.put_new(dbkv, 4, "e")

    assert [{1, "b"}, {2, "c"}, {3, "d"}] == DBKV.select_by_key_range(dbkv, 1, 3)
    assert [{1, "b"}, {2, "c"}] == DBKV.select_by_key_range(dbkv, 1, 3, max_key_inclusive: false)
    assert [] == DBKV.select_by_key_range(dbkv, 10, 20)
  end

  test "select_by_min_key", %{table_name: dbkv} do
    :ok = DBKV.put_new(dbkv, 0, "a")
    :ok = DBKV.put_new(dbkv, 1, "b")
    :ok = DBKV.put_new(dbkv, 2, "c")
    :ok = DBKV.put_new(dbkv, 3, "d")
    :ok = DBKV.put_new(dbkv, 4, "e")

    assert [{2, "c"}, {3, "d"}, {4, "e"}] == DBKV.select_by_min_key(dbkv, 2)
    assert [] == DBKV.select_by_min_key(dbkv, 10)
  end

  test "select_by_max_key", %{table_name: dbkv} do
    :ok = DBKV.put_new(dbkv, 0, "a")
    :ok = DBKV.put_new(dbkv, 1, "b")
    :ok = DBKV.put_new(dbkv, 2, "c")
    :ok = DBKV.put_new(dbkv, 3, "d")
    :ok = DBKV.put_new(dbkv, 4, "e")

    assert [{0, "a"}, {1, "b"}, {2, "c"}] == DBKV.select_by_max_key(dbkv, 2)
    assert [{0, "a"}, {1, "b"}] == DBKV.select_by_max_key(dbkv, 2, max_key_inclusive: false)
    assert [] == DBKV.select_by_max_key(dbkv, -1)
  end

  test "select_by_value_range", %{table_name: dbkv} do
    :ok = DBKV.put_new(dbkv, 0, "a")
    :ok = DBKV.put_new(dbkv, 1, "b")
    :ok = DBKV.put_new(dbkv, 2, "c")
    :ok = DBKV.put_new(dbkv, 3, "d")
    :ok = DBKV.put_new(dbkv, 4, "e")

    assert [{1, "b"}, {2, "c"}, {3, "d"}] == DBKV.select_by_value_range(dbkv, "b", "d")

    assert [{1, "b"}, {2, "c"}] ==
             DBKV.select_by_value_range(dbkv, "b", "d", max_value_inclusive: false)

    assert [] == DBKV.select_by_value_range(dbkv, "v", "z")
  end

  test "select_by_min_value", %{table_name: dbkv} do
    :ok = DBKV.put_new(dbkv, 0, "a")
    :ok = DBKV.put_new(dbkv, 1, "b")
    :ok = DBKV.put_new(dbkv, 2, "c")
    :ok = DBKV.put_new(dbkv, 3, "d")
    :ok = DBKV.put_new(dbkv, 4, "e")

    assert [{2, "c"}, {3, "d"}, {4, "e"}] == DBKV.select_by_min_value(dbkv, "c")
    assert [] == DBKV.select_by_min_value(dbkv, "v")
  end

  test "select_by_max_value", %{table_name: dbkv} do
    :ok = DBKV.put_new(dbkv, 0, "a")
    :ok = DBKV.put_new(dbkv, 1, "b")
    :ok = DBKV.put_new(dbkv, 2, "c")
    :ok = DBKV.put_new(dbkv, 3, "d")
    :ok = DBKV.put_new(dbkv, 4, "e")

    assert [{0, "a"}, {1, "b"}, {2, "c"}] == DBKV.select_by_max_value(dbkv, "c")

    assert [{0, "a"}, {1, "b"}] ==
             DBKV.select_by_max_value(dbkv, "c", max_value_inclusive: false)

    assert [] == DBKV.select_by_max_value(dbkv, "#")
  end

  test "delete_by_match_spec", %{table_name: dbkv} do
    :ok = DBKV.put_new(dbkv, 0, "a")
    :ok = DBKV.put_new(dbkv, 1, "b")
    :ok = DBKV.put_new(dbkv, 2, "c")
    :ok = DBKV.put_new(dbkv, 3, "d")
    :ok = DBKV.put_new(dbkv, 4, "e")

    match_spec =
      Ex2ms.fun do
        {k, v} = kv when 2 <= k and k <= 3 -> true
      end

    assert 2 == DBKV.delete_by_match_spec(dbkv, match_spec)
    assert 3 == DBKV.size(dbkv)
  end

  test "delete_by_key_range", %{table_name: dbkv} do
    :ok = DBKV.put_new(dbkv, 0, "a")
    :ok = DBKV.put_new(dbkv, 1, "b")
    :ok = DBKV.put_new(dbkv, 2, "c")
    :ok = DBKV.put_new(dbkv, 3, "d")
    :ok = DBKV.put_new(dbkv, 4, "e")

    assert 3 == DBKV.delete_by_key_range(dbkv, 1, 3)
    assert 2 == DBKV.size(dbkv)
  end

  test "delete_by_min_key", %{table_name: dbkv} do
    :ok = DBKV.put_new(dbkv, 0, "a")
    :ok = DBKV.put_new(dbkv, 1, "b")
    :ok = DBKV.put_new(dbkv, 2, "c")
    :ok = DBKV.put_new(dbkv, 3, "d")
    :ok = DBKV.put_new(dbkv, 4, "e")

    assert 2 == DBKV.delete_by_min_key(dbkv, 3)
    assert 3 == DBKV.size(dbkv)
  end

  test "delete_by_max_key", %{table_name: dbkv} do
    :ok = DBKV.put_new(dbkv, 0, "a")
    :ok = DBKV.put_new(dbkv, 1, "b")
    :ok = DBKV.put_new(dbkv, 2, "c")
    :ok = DBKV.put_new(dbkv, 3, "d")
    :ok = DBKV.put_new(dbkv, 4, "e")

    assert 3 == DBKV.delete_by_max_key(dbkv, 2)
    assert 2 == DBKV.size(dbkv)
  end

  test "delete_by_value_range", %{table_name: dbkv} do
    :ok = DBKV.put_new(dbkv, 0, "a")
    :ok = DBKV.put_new(dbkv, 1, "b")
    :ok = DBKV.put_new(dbkv, 2, "c")
    :ok = DBKV.put_new(dbkv, 3, "d")
    :ok = DBKV.put_new(dbkv, 4, "e")

    assert 2 == DBKV.delete_by_value_range(dbkv, "c", "d")
    assert 3 == DBKV.size(dbkv)
  end

  test "delete_by_min_value", %{table_name: dbkv} do
    :ok = DBKV.put_new(dbkv, 0, "a")
    :ok = DBKV.put_new(dbkv, 1, "b")
    :ok = DBKV.put_new(dbkv, 2, "c")
    :ok = DBKV.put_new(dbkv, 3, "d")
    :ok = DBKV.put_new(dbkv, 4, "e")

    assert 3 == DBKV.delete_by_min_value(dbkv, "c")
    assert 2 == DBKV.size(dbkv)
  end

  test "delete_by_max_value", %{table_name: dbkv} do
    :ok = DBKV.put_new(dbkv, 0, "a")
    :ok = DBKV.put_new(dbkv, 1, "b")
    :ok = DBKV.put_new(dbkv, 2, "c")
    :ok = DBKV.put_new(dbkv, 3, "d")
    :ok = DBKV.put_new(dbkv, 4, "e")

    assert 2 == DBKV.delete_by_max_value(dbkv, "b")
    assert 3 == DBKV.size(dbkv)
  end
end
