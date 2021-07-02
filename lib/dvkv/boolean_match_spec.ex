defmodule DBKV.BooleanMatchSpec do
  @moduledoc false

  require Ex2ms

  def key_range(min_key, max_key, opts \\ []) do
    min_inclusive = Keyword.get(opts, :min_inclusive, true)
    max_inclusive = Keyword.get(opts, :max_inclusive, true)

    cond do
      min_inclusive && max_inclusive ->
        Ex2ms.fun do
          {k, v} = kv when ^min_key <= k and k <= ^max_key -> true
        end

      min_inclusive ->
        Ex2ms.fun do
          {k, v} = kv when ^min_key <= k and k < ^max_key -> true
        end

      max_inclusive ->
        Ex2ms.fun do
          {k, v} = kv when ^min_key < k and k <= ^max_key -> true
        end

      true ->
        Ex2ms.fun do
          {k, v} = kv when ^min_key < k and k < ^max_key -> true
        end
    end
  end

  def value_range(min_value, max_value, opts \\ []) do
    min_inclusive = Keyword.get(opts, :min_inclusive, true)
    max_inclusive = Keyword.get(opts, :max_inclusive, true)

    cond do
      min_inclusive && max_inclusive ->
        Ex2ms.fun do
          {k, v} = kv when ^min_value <= v and v <= ^max_value -> true
        end

      min_inclusive ->
        Ex2ms.fun do
          {k, v} = kv when ^min_value <= v and v < ^max_value -> true
        end

      max_inclusive ->
        Ex2ms.fun do
          {k, v} = kv when ^min_value < v and v <= ^max_value -> true
        end

      true ->
        Ex2ms.fun do
          {k, v} = kv when ^min_value < v and v < ^max_value -> true
        end
    end
  end

  def min_key(min_key, inclusive \\ true) do
    if inclusive do
      Ex2ms.fun do
        {k, v} = kv when ^min_key <= k -> true
      end
    else
      Ex2ms.fun do
        {k, v} = kv when ^min_key < k -> true
      end
    end
  end

  def max_key(max_key, inclusive \\ true) do
    if inclusive do
      Ex2ms.fun do
        {k, v} = kv when k <= ^max_key -> true
      end
    else
      Ex2ms.fun do
        {k, v} = kv when k < ^max_key -> true
      end
    end
  end

  def min_value(min_value, inclusive \\ true) do
    if inclusive do
      Ex2ms.fun do
        {k, v} = kv when ^min_value <= v -> true
      end
    else
      Ex2ms.fun do
        {k, v} = kv when ^min_value < v -> true
      end
    end
  end

  def max_value(max_value, inclusive \\ true) do
    if inclusive do
      Ex2ms.fun do
        {k, v} = kv when v <= ^max_value -> true
      end
    else
      Ex2ms.fun do
        {k, v} = kv when v < ^max_value -> true
      end
    end
  end
end
