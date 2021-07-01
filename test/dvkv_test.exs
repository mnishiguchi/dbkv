defmodule DBKVTest do
  # We cannot run this test async because the database file is global.
  use ExUnit.Case

  import DBKV

  require Ex2ms

  setup do
    table_name = :dbkv_test
    :ok = create_table(name: table_name, data_dir: "tmp")

    on_exit(fn ->
      File.rm("tmp/dbkv_test.db")
    end)

    %{table_name: table_name}
  end

  test "when table not exists" do
    assert_raise ArgumentError, fn -> get(:non_existent_table, 0) end
    assert_raise ArgumentError, fn -> put(:non_existent_table, 0, 0) end
  end

  test "basic use", %{table_name: dbkv} do
    assert %{
             file_size: _,
             filename: 'tmp/dbkv_test.db',
             keypos: _,
             size: _,
             type: :set
           } = describe_table(dbkv)

    assert exist?(dbkv)

    # Insert
    :ok = put(dbkv, :word, "Hi")
    assert "Hi" == get(dbkv, :word)
    assert 1 == size(dbkv)

    # Upsert
    :ok = put(dbkv, :word, "Hello")
    assert "Hello" == get(dbkv, :word)
    assert 1 == size(dbkv)

    # Insert new
    {:error, :exists} = put_new(dbkv, :word, "World")
    assert "Hello" == get(dbkv, :word)
    :ok = put_new(dbkv, :temp, 88)
    assert 88 == get(dbkv, :temp)
    assert 2 == size(dbkv)

    # Update
    :ok = update(dbkv, :word, "default", &(&1 <> "!!!"))
    assert "Hello!!!" == get(dbkv, :word)
    assert 2 == size(dbkv)

    :ok = update(dbkv, :lang, "Elixir", &(&1 <> "!!!"))
    assert "Elixir" == get(dbkv, :lang)
    assert 3 == size(dbkv)

    # Delete
    :ok = delete(dbkv, :word)
    assert is_nil(get(dbkv, :word))
    assert 2 == size(dbkv)

    # Data persistence across restart
    :ok = delete_table(dbkv)
    refute exist?(dbkv)
    :ok = create_table(name: dbkv, data_dir: "tmp")
    assert "Elixir" == get(dbkv, :lang)
  end

  test "delete_all", %{table_name: dbkv} do
    :ok = put_new(dbkv, 0, "a")
    :ok = put_new(dbkv, 1, "b")
    :ok = put_new(dbkv, 2, "c")

    :ok = delete_all(dbkv)
    assert 0 == size(dbkv)
  end

  test "all", %{table_name: dbkv} do
    :ok = put_new(dbkv, 0, "a")
    :ok = put_new(dbkv, 1, "b")
    :ok = put_new(dbkv, 2, "c")

    assert [{0, "a"}, {1, "b"}, {2, "c"}] == all(dbkv)
  end

  test "keys", %{table_name: dbkv} do
    :ok = put_new(dbkv, 0, "a")
    :ok = put_new(dbkv, 1, "b")
    :ok = put_new(dbkv, 2, "c")

    assert [0, 1, 2] == keys(dbkv)
  end

  test "values", %{table_name: dbkv} do
    :ok = put_new(dbkv, 0, "a")
    :ok = put_new(dbkv, 1, "b")
    :ok = put_new(dbkv, 2, "c")

    assert ["a", "b", "c"] == values(dbkv)
  end

  test "select_by_match_spec", %{table_name: dbkv} do
    :ok = put_new(dbkv, 0, "a")
    :ok = put_new(dbkv, 1, "b")
    :ok = put_new(dbkv, 2, "c")
    :ok = put_new(dbkv, 3, "d")
    :ok = put_new(dbkv, 4, "e")

    match_spec =
      Ex2ms.fun do
        {k, v} = kv when 1 <= k and k <= 3 -> kv
      end

    assert [{1, "b"}, {2, "c"}, {3, "d"}] == select_by_match_spec(dbkv, match_spec)
  end

  test "select_by_key_range", %{table_name: dbkv} do
    :ok = put_new(dbkv, 0, "a")
    :ok = put_new(dbkv, 1, "b")
    :ok = put_new(dbkv, 2, "c")
    :ok = put_new(dbkv, 3, "d")
    :ok = put_new(dbkv, 4, "e")

    assert [{1, "b"}, {2, "c"}, {3, "d"}] == select_by_key_range(dbkv, 1, 3)
    assert [{1, "b"}, {2, "c"}] == select_by_key_range(dbkv, 1, 3, max_key_inclusive: false)
    assert [] == select_by_key_range(dbkv, 10, 20)
  end

  test "select_by_min_key", %{table_name: dbkv} do
    :ok = put_new(dbkv, 0, "a")
    :ok = put_new(dbkv, 1, "b")
    :ok = put_new(dbkv, 2, "c")
    :ok = put_new(dbkv, 3, "d")
    :ok = put_new(dbkv, 4, "e")

    assert [{2, "c"}, {3, "d"}, {4, "e"}] == select_by_min_key(dbkv, 2)
    assert [] == select_by_min_key(dbkv, 10)
  end

  test "select_by_max_key", %{table_name: dbkv} do
    :ok = put_new(dbkv, 0, "a")
    :ok = put_new(dbkv, 1, "b")
    :ok = put_new(dbkv, 2, "c")
    :ok = put_new(dbkv, 3, "d")
    :ok = put_new(dbkv, 4, "e")

    assert [{0, "a"}, {1, "b"}, {2, "c"}] == select_by_max_key(dbkv, 2)
    assert [{0, "a"}, {1, "b"}] == select_by_max_key(dbkv, 2, max_key_inclusive: false)
    assert [] == select_by_max_key(dbkv, -1)
  end

  test "select_by_value_range", %{table_name: dbkv} do
    :ok = put_new(dbkv, 0, "a")
    :ok = put_new(dbkv, 1, "b")
    :ok = put_new(dbkv, 2, "c")
    :ok = put_new(dbkv, 3, "d")
    :ok = put_new(dbkv, 4, "e")

    assert [{1, "b"}, {2, "c"}, {3, "d"}] == select_by_value_range(dbkv, "b", "d")

    assert [{1, "b"}, {2, "c"}] ==
             select_by_value_range(dbkv, "b", "d", max_value_inclusive: false)

    assert [] == select_by_value_range(dbkv, "v", "z")
  end

  test "select_by_min_value", %{table_name: dbkv} do
    :ok = put_new(dbkv, 0, "a")
    :ok = put_new(dbkv, 1, "b")
    :ok = put_new(dbkv, 2, "c")
    :ok = put_new(dbkv, 3, "d")
    :ok = put_new(dbkv, 4, "e")

    assert [{2, "c"}, {3, "d"}, {4, "e"}] == select_by_min_value(dbkv, "c")
    assert [] == select_by_min_value(dbkv, "v")
  end

  test "select_by_max_value", %{table_name: dbkv} do
    :ok = put_new(dbkv, 0, "a")
    :ok = put_new(dbkv, 1, "b")
    :ok = put_new(dbkv, 2, "c")
    :ok = put_new(dbkv, 3, "d")
    :ok = put_new(dbkv, 4, "e")

    assert [{0, "a"}, {1, "b"}, {2, "c"}] == select_by_max_value(dbkv, "c")

    assert [{0, "a"}, {1, "b"}] ==
             select_by_max_value(dbkv, "c", max_value_inclusive: false)

    assert [] == select_by_max_value(dbkv, "#")
  end

  test "increment", %{table_name: dbkv} do
    :ok = put_new(dbkv, "count", 0)

    assert 1 == increment(dbkv, "count", 1)
    assert 2 == increment(dbkv, "count", 1)
    assert 9 == increment(dbkv, "count", 7)
  end
end
