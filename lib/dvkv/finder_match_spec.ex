defmodule DBKV.FinderMatchSpec do
  @moduledoc """
  A collection of convenient match spec generators.
  """

  require Ex2ms

  def all() do
    Ex2ms.fun do
      {k, v} -> {k, v}
    end
  end

  def keys() do
    Ex2ms.fun do
      {k, v} -> k
    end
  end

  def values() do
    Ex2ms.fun do
      {k, v} -> v
    end
  end

  def key_range(min_key, max_key, opts) do
    max_key_inclusive = Keyword.get(opts, :max_key_inclusive, true)

    if max_key_inclusive do
      Ex2ms.fun do
        {k, v} = kv when ^min_key <= k and k <= ^max_key -> kv
      end
    else
      Ex2ms.fun do
        {k, v} = kv when ^min_key <= k and k < ^max_key -> kv
      end
    end
  end

  def value_range(min_value, max_value, opts) do
    max_value_inclusive = Keyword.get(opts, :max_value_inclusive, true)

    if max_value_inclusive do
      Ex2ms.fun do
        {k, v} = kv when ^min_value <= v and v <= ^max_value -> kv
      end
    else
      Ex2ms.fun do
        {k, v} = kv when ^min_value <= v and v < ^max_value -> kv
      end
    end
  end

  def min_key(min_key) do
    Ex2ms.fun do
      {k, v} = kv when ^min_key <= k -> kv
    end
  end

  def max_key(max_key, opts) do
    max_key_inclusive = Keyword.get(opts, :max_key_inclusive, true)

    if max_key_inclusive do
      Ex2ms.fun do
        {k, v} = kv when k <= ^max_key -> kv
      end
    else
      Ex2ms.fun do
        {k, v} = kv when k < ^max_key -> kv
      end
    end
  end

  def min_value(min_value) do
    Ex2ms.fun do
      {k, v} = kv when ^min_value <= v -> kv
    end
  end

  def max_value(max_value, opts) do
    max_value_inclusive = Keyword.get(opts, :max_value_inclusive, true)

    if max_value_inclusive do
      Ex2ms.fun do
        {k, v} = kv when v <= ^max_value -> kv
      end
    else
      Ex2ms.fun do
        {k, v} = kv when v < ^max_value -> kv
      end
    end
  end
end
