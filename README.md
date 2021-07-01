# DBKV

[![Hex version](https://img.shields.io/hexpm/v/dbkv.svg "Hex version")](https://hex.pm/packages/dbkv)
[![API docs](https://img.shields.io/hexpm/v/dbkv.svg?label=docs "API docs")](https://hexdocs.pm/dbkv)
[![CI](https://github.com/mnishiguchi/dbkv/actions/workflows/ci.yml/badge.svg)](https://github.com/mnishiguchi/dbkv/actions/workflows/ci.yml)
[![Hex](https://github.com/mnishiguchi/dbkv/actions/workflows/hex.yml/badge.svg)](https://github.com/mnishiguchi/dbkv/actions/workflows/hex.yml)

`DBKV` is a disk-based embedded key-value store built on top of [`:dets`](https://erlang.org/doc/man/dets.html). Inspired by [CubDB](https://github.com/lucaong/cubdb)'s intuitive API.

## Usage

### Open a file

```elixir
iex> {:ok, t} = DBKV.open(name: :my_table, data_dir: "tmp")
{:ok, :my_table}

iex> DBKV.open?(t)
true
```

### Upsert a key-value pair

```elixir
iex> DBKV.put(t, "greeting", "Hi")
:ok

iex> DBKV.get(t, "greeting")
"Hi"
```

### Insert a key-value pair if it does not exist

```elixir
iex> DBKV.put_new(t, "greeting", "Hello")
{:error, :exists}

iex> DBKV.get(t, "greeting")
"Hi"

iex> DBKV.put_new(t, "temperature", 32)
:ok

iex> DBKV.get(t, "temperature")
32
```

### Update a key-value pair with a function

```elixir
iex> DBKV.update(t, "greeting", "default", &(&1 <> "!!!"))
:ok

iex> DBKV.get(t, "greeting")
"Hi!!!"

iex> DBKV.update(t, "language", "default", &(&1 <> "!!!"))
:ok

iex> DBKV.get(t, "language")
"default"
```

### Delete a key-value pair

```elixir
iex> DBKV.delete(t, "greeting")
:ok

iex> DBKV.get(t, "greeting")
nil
```

### Persistence across restart

```elixir
iex> DBKV.close(t)
:ok

iex> DBKV.open?(t)
false

iex> DBKV.open(name: t, data_dir: "tmp")
{:ok, :my_table}

iex> DBKV.get(t, "temperature")
32
```

### Select records

```elixir
iex> DBKV.put_new(t, 0, "a")
iex> DBKV.put_new(t, 1, "b")
iex> DBKV.put_new(t, 2, "c")
iex> DBKV.put_new(t, 3, "d")
iex> DBKV.put_new(t, 4, "e")
```

By key range

```elixir
iex> DBKV.select_by_key_range(t, 1, 3)
[{1, "b"}, {2, "c"}, {3, "d"}]
```

By match spec

```elixir
iex> require Ex2ms

iex> match_spec = Ex2ms.fun do {k, v} = kv when 1 <= k and k <= 3 -> kv end
[{{:"$1", :"$2"}, [{:andalso, {:"=<", 1, :"$1"}, {:"=<", :"$1", 3}}], [:"$_"]}]

iex> DBKV.select_by_match_spec(t, match_spec)
[{1, "b"}, {2, "c"}, {3, "d"}]
```

### Argument Error

When a table is not started, underlying `:dets` will raise an argument error. Please make sure that the table is started with a correct name.

```elixir
iex> DBKV.get(:nonexistent_table, "temperature")
** (ArgumentError) argument error
    (stdlib 3.15.1) dets.erl:1259: :dets.lookup(:nonexistent_table, "temperature")
    (dbkv 0.1.2) lib/dvkv.ex:78: DBKV.get/3
```

### Using `:dets` functions

`DBKV` is a thin wrapper of `:dets`. You can mix and match with any [`:dets` functions](https://erlang.org/doc/man/dets.html) if you wish.

```elixir
iex> :dets.info(t)
[
  type: :set,
  keypos: 1,
  size: 0,
  file_size: 5464,
  filename: 'tmp/my_table.db'
]
```

## Installation

`DBKV` can be installed by adding `dbkv` to your list of dependencies in mix.exs:

```elixir
def deps do
  [
    {:dbkv, "~> 0.1"}
  ]
end
```

Documentation can be found at [https://hexdocs.pm/dbkv](https://hexdocs.pm/dbkv).

## Alternatives

- [CubDB](https://github.com/lucaong/cubdb)
- [`dets`](https://erlang.org/doc/man/dets.html)
