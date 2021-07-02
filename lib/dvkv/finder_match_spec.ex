defmodule DBKV.FinderMatchSpec do
  @moduledoc false

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

  def key_range(min_key, max_key, opts \\ []) do
    min_inclusive = Keyword.get(opts, :min_inclusive, true)
    max_inclusive = Keyword.get(opts, :max_inclusive, true)

    cond do
      min_inclusive && max_inclusive ->
        Ex2ms.fun do
          {k, v} = kv when ^min_key <= k and k <= ^max_key -> kv
        end

      min_inclusive ->
        Ex2ms.fun do
          {k, v} = kv when ^min_key <= k and k < ^max_key -> kv
        end

      max_inclusive ->
        Ex2ms.fun do
          {k, v} = kv when ^min_key < k and k <= ^max_key -> kv
        end

      true ->
        Ex2ms.fun do
          {k, v} = kv when ^min_key < k and k < ^max_key -> kv
        end
    end
  end

  def value_range(min_value, max_value, opts \\ []) do
    min_inclusive = Keyword.get(opts, :min_inclusive, true)
    max_inclusive = Keyword.get(opts, :max_inclusive, true)

    cond do
      min_inclusive && max_inclusive ->
        Ex2ms.fun do
          {k, v} = kv when ^min_value <= v and v <= ^max_value -> kv
        end

      min_inclusive ->
        Ex2ms.fun do
          {k, v} = kv when ^min_value <= v and v < ^max_value -> kv
        end

      max_inclusive ->
        Ex2ms.fun do
          {k, v} = kv when ^min_value < v and v <= ^max_value -> kv
        end

      true ->
        Ex2ms.fun do
          {k, v} = kv when ^min_value < v and v < ^max_value -> kv
        end
    end
  end

  def min_key(min_key, inclusive \\ true) do
    if inclusive do
      Ex2ms.fun do
        {k, v} = kv when ^min_key <= k -> kv
      end
    else
      Ex2ms.fun do
        {k, v} = kv when ^min_key < k -> kv
      end
    end
  end

  def max_key(max_key, inclusive \\ true) do
    if inclusive do
      Ex2ms.fun do
        {k, v} = kv when k <= ^max_key -> kv
      end
    else
      Ex2ms.fun do
        {k, v} = kv when k < ^max_key -> kv
      end
    end
  end

  def min_value(min_value, inclusive \\ true) do
    if inclusive do
      Ex2ms.fun do
        {k, v} = kv when ^min_value <= v -> kv
      end
    else
      Ex2ms.fun do
        {k, v} = kv when ^min_value < v -> kv
      end
    end
  end

  def max_value(max_value, inclusive \\ true) do
    if inclusive do
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
