defmodule Sequin.Cache do
  @moduledoc false
  def get(key), do: ConCache.get(__MODULE__, key)

  def put(key, value, ttl \\ :infinity), do: ConCache.put(__MODULE__, key, %ConCache.Item{value: value, ttl: ttl})

  def delete(key), do: ConCache.delete(__MODULE__, key)

  def get_or_store(key, fun, ttl \\ :infinity) do
    ConCache.get_or_store(__MODULE__, key, fn ->
      %ConCache.Item{value: fun.(), ttl: ttl}
    end)
  end
end