# DBKV

[![Hex version](https://img.shields.io/hexpm/v/dbkv.svg "Hex version")](https://hex.pm/packages/dbkv)
[![API docs](https://img.shields.io/hexpm/v/dbkv.svg?label=docs "API docs")](https://hexdocs.pm/dbkv)
[![CI](https://github.com/mnishiguchi/dbkv/actions/workflows/ci.yml/badge.svg)](https://github.com/mnishiguchi/dbkv/actions/workflows/ci.yml)
[![Hex](https://github.com/mnishiguchi/dbkv/actions/workflows/hex.yml/badge.svg)](https://github.com/mnishiguchi/dbkv/actions/workflows/hex.yml)

A disk-based embedded key-value storage built on top of [dets](https://erlang.org/doc/man/dets.html) set.
Inspired by [CubDB](https://github.com/lucaong/cubdb)'s intuitive API.

A table has at most one entry with a given key. If an entry with a key already present in the table
is inserted, the existing entry is overwritten by the new entry. The entries are not ordered. See
[dets manual](https://erlang.org/doc/man/dets.html) for more info.

## Usage

Documentation can be found at [https://hexdocs.pm/dbkv](https://hexdocs.pm/dbkv).

### Open a table

```elixir
iex> {:ok, t} = DBKV.open(name: :my_table, data_dir: "tmp")
{:ok, :my_table}

iex> DBKV.open?(t)
true
```

You could omit `name` and `data_dir` options. In such a case, they will default to `DBKV` and `"tmp"` respectively.

```elixir
iex> DBKV.open()
```

### Upsert an entry

```elixir
iex> DBKV.put(t, "greeting", "Hi")
:ok

iex> DBKV.get(t, "greeting")
"Hi"
```

### Insert an entry unless the entry key already exists in the table

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

### Update an entry in the table with a function

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

### Delete an entry

```elixir
iex> DBKV.delete(t, "greeting")
:ok

iex> DBKV.get(t, "greeting")
nil
```

### Initialize a table with a specific dataset

A table can be initialized with a list of two-element tulpes.

```elixir
iex> DBKV.init_table(t, [{:a, 0}, {:b, 1}, {:c, 2}, {:d, 3}, {:e, 4}])
```

### Select a range of entries from the table

**By key ranges**

```elixir
iex> DBKV.select_by_key_range(t, :b, :d)
[b: 1, c: 2, d: 3]
```

**By [match spec](https://erlang.org/doc/apps/erts/match_spec.html)**

The [Ex2ms.fun/2](https://hexdocs.pm/ex2ms/Ex2ms.html#fun/1) macro is useful to build a match specification.

```elixir
iex> require Ex2ms

iex> match_spec = Ex2ms.fun do {k, v} = kv when :b <= k and k <= :d -> kv end
[{{:"$1", :"$2"}, [{:andalso, {:"=<", :b, :"$1"}, {:"=<", :"$1", :d}}], [:"$_"]}]

iex> DBKV.select_by_match_spec(t, match_spec)
[b: 1, c: 2, d: 3]
```

### Use `:dets` functions

`DBKV` is a thin wrapper of dets. You could mix and match with any
[dets functions](https://erlang.org/doc/man/dets.html) if you wish.

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

## Troubleshooting

### `ArgumentError`

When a table is not open, a function call results in `ArgumentError`.
Make sure that the table is opened with a correct name.

```elixir
iex> DBKV.get(:nonexistent_table, "temperature")
** (ArgumentError) argument error
    (stdlib 3.15.1) dets.erl:1259: :dets.lookup(:nonexistent_table, "temperature")
    (dbkv 0.2.0) lib/dvkv.ex:131: DBKV.get/3
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

Using `Mix.install/2` in IEx:

```elixir
❯ iex

iex> Mix.install([{:dbkv, "~> 0.2"}])
```

## Alternatives

- [CubDB](https://github.com/lucaong/cubdb)
- [dets](https://erlang.org/doc/man/dets.html)
