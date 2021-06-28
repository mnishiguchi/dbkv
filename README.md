# DubDB

`DubDB` is a disk-based embedded key-value store built on top of [`:dets`](https://erlang.org/doc/man/dets.html). Inspired by [CubDB](https://github.com/lucaong/cubdb)'s intuitive API.

## Usage

### Create a table with a table name atom

```elixir
iex> table_name = :my_table

iex> DubDB.create_table(name: table_name, data_dir: "tmp")
:ok

iex> DubDB.exist?(table_name)
true
```

### Upsert a key-value pair

```elixir
iex> DubDB.put(table_name, "greeting", "Hi")
:ok

iex> DubDB.get(table_name, "greeting")
"Hi"
```

### Insert a key-value pair if it does not exist

```elixir
iex> DubDB.put_new(table_name, "greeting", "Hello")
{:error, :exists}

iex> DubDB.get(table_name, "greeting")
"Hi"

iex> DubDB.put_new(table_name, "temperature", 32)
:ok

iex> DubDB.get(table_name, "temperature")
32
```

### Update a key-value pair with a function

```elixir
# Update
iex> DubDB.update(table_name, "greeting", "default", &(&1 <> "!!!"))
:ok

iex> DubDB.get(table_name, "greeting")
"Hi!!!"

iex> DubDB.update(table_name, "language", "default", &(&1 <> "!!!"))
:ok

iex> DubDB.get(table_name, "language")
"default"
```

### Delete a key-value pair

```elixir
iex> DubDB.delete(table_name, "greeting")
:ok

iex> DubDB.get(table_name, "greeting")
nil
```

### Data persistence across restart

```elixir
iex> DubDB.delete_table(table_name)
:ok

iex> DubDB.exist?(table_name)
false

iex> DubDB.create_table(name: table_name, data_dir: "tmp")
:ok

iex> DubDB.get(table_name, "temperature")
32
```

### Select records

```elixir
iex> DubDB.put_new(table_name, 0, "a")
iex> DubDB.put_new(table_name, 1, "b")
iex> DubDB.put_new(table_name, 2, "c")
iex> DubDB.put_new(table_name, 3, "d")
iex> DubDB.put_new(table_name, 4, "e")

# By key range
iex> DubDB.select_by_key_range(table_name, 1, 3)
[{1, "b"}, {2, "c"}, {3, "d"}]

# By match spec
iex> require Ex2ms
iex> match_spec = Ex2ms.fun do {k, v} = kv when 1 <= k and k <= 3 -> kv end
[{{:"$1", :"$2"}, [{:andalso, {:"=<", 1, :"$1"}, {:"=<", :"$1", 3}}], [:"$_"]}]
iex> DubDB.select_by_match_spec(table_name, match_spec)
[{1, "b"}, {2, "c"}, {3, "d"}]
```

## Installation

`DubDB` can be installed by adding `dubdb` to your list of dependencies in mix.exs:

```elixir
def deps do
  [
    {:dubdb, "~> 0.1"}
  ]
end
```

Documentation can be found at [https://hexdocs.pm/dubdb](https://hexdocs.pm/dubdb).

## Alternatives

- [CubDB](https://github.com/lucaong/cubdb)
- [`dets`](https://erlang.org/doc/man/dets.html)
