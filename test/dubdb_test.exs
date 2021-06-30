defmodule DBKVTest do
  # We cannot run this test async because the database file is global.
  use ExUnit.Case

  import DBKV

  require Ex2ms

  setup do
    table_name = :file_store_test
    :ok = create_table(name: table_name, data_dir: "tmp")

    on_exit(fn ->
      File.rm("tmp/file_store_test.db")
    end)

    %{table_name: table_name}
  end

  test "basic use", %{table_name: table_name} do
    assert %{
             file_size: _,
             filename: 'tmp/file_store_test.db',
             keypos: _,
             size: _,
             type: :set
           } = describe_table(table_name)

    assert exist?(table_name)

    # Insert
    :ok = put(table_name, :word, "Hi")
    assert "Hi" == get(table_name, :word)
    assert 1 == size(table_name)

    # Upsert
    :ok = put(table_name, :word, "Hello")
    assert "Hello" == get(table_name, :word)
    assert 1 == size(table_name)

    # Insert new
    {:error, :exists} = put_new(table_name, :word, "World")
    assert "Hello" == get(table_name, :word)
    :ok = put_new(table_name, :temp, 88)
    assert 88 == get(table_name, :temp)
    assert 2 == size(table_name)

    # Update
    :ok = update(table_name, :word, "default", &(&1 <> "!!!"))
    assert "Hello!!!" == get(table_name, :word)
    assert 2 == size(table_name)

    :ok = update(table_name, :lang, "Elixir", &(&1 <> "!!!"))
    assert "Elixir" == get(table_name, :lang)
    assert 3 == size(table_name)

    # Delete
    :ok = delete(table_name, :word)
    assert is_nil(get(table_name, :word))
    assert 2 == size(table_name)

    # Data persistence across restart
    :ok = delete_table(table_name)
    refute exist?(table_name)
    :ok = create_table(name: table_name, data_dir: "tmp")
    assert "Elixir" == get(table_name, :lang)
  end

  test "select_by_match_spec", %{table_name: table_name} do
    :ok = put_new(table_name, 0, "a")
    :ok = put_new(table_name, 1, "b")
    :ok = put_new(table_name, 2, "c")
    :ok = put_new(table_name, 3, "d")
    :ok = put_new(table_name, 4, "e")

    match_spec =
      Ex2ms.fun do
        {k, v} = kv when 1 <= k and k <= 3 -> kv
      end

    assert [{1, "b"}, {2, "c"}, {3, "d"}] == select_by_match_spec(table_name, match_spec)
  end

  test "select_by_key_range", %{table_name: table_name} do
    :ok = put_new(table_name, 0, "a")
    :ok = put_new(table_name, 1, "b")
    :ok = put_new(table_name, 2, "c")
    :ok = put_new(table_name, 3, "d")
    :ok = put_new(table_name, 4, "e")

    assert [{1, "b"}, {2, "c"}, {3, "d"}] == select_by_key_range(table_name, 1, 3)
    assert [{1, "b"}, {2, "c"}] == select_by_key_range(table_name, 1, 3, max_key_inclusive: false)
    assert [] == select_by_key_range(table_name, 10, 20)
  end

  test "select_by_min_key", %{table_name: table_name} do
    :ok = put_new(table_name, 0, "a")
    :ok = put_new(table_name, 1, "b")
    :ok = put_new(table_name, 2, "c")
    :ok = put_new(table_name, 3, "d")
    :ok = put_new(table_name, 4, "e")

    assert [{2, "c"}, {3, "d"}, {4, "e"}] == select_by_min_key(table_name, 2)
    assert [] == select_by_min_key(table_name, 10)
  end

  test "select_by_max_key", %{table_name: table_name} do
    :ok = put_new(table_name, 0, "a")
    :ok = put_new(table_name, 1, "b")
    :ok = put_new(table_name, 2, "c")
    :ok = put_new(table_name, 3, "d")
    :ok = put_new(table_name, 4, "e")

    assert [{0, "a"}, {1, "b"}, {2, "c"}] == select_by_max_key(table_name, 2)
    assert [{0, "a"}, {1, "b"}] == select_by_max_key(table_name, 2, max_key_inclusive: false)
    assert [] == select_by_max_key(table_name, -1)
  end

  test "select_by_value_range", %{table_name: table_name} do
    :ok = put_new(table_name, 0, "a")
    :ok = put_new(table_name, 1, "b")
    :ok = put_new(table_name, 2, "c")
    :ok = put_new(table_name, 3, "d")
    :ok = put_new(table_name, 4, "e")

    assert [{1, "b"}, {2, "c"}, {3, "d"}] == select_by_value_range(table_name, "b", "d")

    assert [{1, "b"}, {2, "c"}] ==
             select_by_value_range(table_name, "b", "d", max_value_inclusive: false)

    assert [] == select_by_value_range(table_name, "v", "z")
  end

  test "select_by_min_value", %{table_name: table_name} do
    :ok = put_new(table_name, 0, "a")
    :ok = put_new(table_name, 1, "b")
    :ok = put_new(table_name, 2, "c")
    :ok = put_new(table_name, 3, "d")
    :ok = put_new(table_name, 4, "e")

    assert [{2, "c"}, {3, "d"}, {4, "e"}] == select_by_min_value(table_name, "c")
    assert [] == select_by_min_value(table_name, "v")
  end

  test "select_by_max_value", %{table_name: table_name} do
    :ok = put_new(table_name, 0, "a")
    :ok = put_new(table_name, 1, "b")
    :ok = put_new(table_name, 2, "c")
    :ok = put_new(table_name, 3, "d")
    :ok = put_new(table_name, 4, "e")

    assert [{0, "a"}, {1, "b"}, {2, "c"}] == select_by_max_value(table_name, "c")

    assert [{0, "a"}, {1, "b"}] ==
             select_by_max_value(table_name, "c", max_value_inclusive: false)

    assert [] == select_by_max_value(table_name, "#")
  end
end
