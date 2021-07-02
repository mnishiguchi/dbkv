# DBKV

[![Hex version](https://img.shields.io/hexpm/v/dbkv.svg "Hex version")](https://hex.pm/packages/dbkv)
[![API docs](https://img.shields.io/hexpm/v/dbkv.svg?label=docs "API docs")](https://hexdocs.pm/dbkv)
[![CI](https://github.com/mnishiguchi/dbkv/actions/workflows/ci.yml/badge.svg)](https://github.com/mnishiguchi/dbkv/actions/workflows/ci.yml)
[![Hex](https://github.com/mnishiguchi/dbkv/actions/workflows/hex.yml/badge.svg)](https://github.com/mnishiguchi/dbkv/actions/workflows/hex.yml)

`DBKV` is a disk-based embedded key-value storage built on top of [`:dets`](https://erlang.org/doc/man/dets.html). Inspired by [CubDB](https://github.com/lucaong/cubdb)'s intuitive API.

## Usage

### Open a database

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

### Initialize the table

```elixir
iex> DBKV.init_table(t, [a: 0, b: 1, c: 2, d: 3, e: 4])
```

### Select records

By key range

```elixir
iex> DBKV.select_by_key_range(t, :b, :d)
[b: 1, c: 2, d: 3]
```

By match spec

```elixir
iex> require Ex2ms

iex> match_spec = Ex2ms.fun do {k, v} = kv when :b <= k and k <= :d -> kv end
[{{:"$1", :"$2"}, [{:andalso, {:"=<", :b, :"$1"}, {:"=<", :"$1", :d}}], [:"$_"]}]

iex> DBKV.select_by_match_spec(t, match_spec)
[b: 1, c: 2, d: 3]
```

## Troubleshooting

### Argument Error

When a table is not open, underlying `:dets` will raise `ArgumentError`. Please make sure that the table is opened with a correct name.

```elixir
iex> DBKV.get(:nonexistent_table, "temperature")
** (ArgumentError) argument error
    (stdlib 3.15.1) dets.erl:1259: :dets.lookup(:nonexistent_table, "temperature")
    (dbkv 0.2.0) lib/dvkv.ex:131: DBKV.get/3
```

### Use `:dets` functions

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

### `:invalid_objects_list` error

When a table is initialized inappropriately, the table may return `{:error, :invalid_objects_list}`.
In such a case, re-opening the table will fix it.

```elixir
iex> DBKV.init_table(t, ["invalid object list"])
{:error, :invalid_objects_list}

iex> DBKV.get(t, :a)
** (CaseClauseError) no case clause matching: {:error, :invalid_objects_list}
    (dbkv 0.2.0) lib/dvkv.ex:131: DBKV.get/3

iex> DBKV.close(t)
{:error, :invalid_objects_list}

iex> {:ok, t} = DBKV.open(name: :my_table, data_dir: "tmp")
dets: file "tmp/Elixir.DBKV.db" not properly closed, repairing ...
{:ok, :my_table}

iex> DBKV.all(t)
[]
```

## Installation

`DBKV` can be installed by adding `dbkv` to your list of dependencies in mix.exs:

```elixir
def deps do
  [
    {:dbkv, "~> 0.2"}
  ]
end
```

Documentation can be found at [https://hexdocs.pm/dbkv](https://hexdocs.pm/dbkv).

## Alternativess

- [CubDB](https://github.com/lucaong/cubdb)
- [`dets`](https://erlang.org/doc/man/dets.html)
