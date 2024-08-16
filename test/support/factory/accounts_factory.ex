defmodule Sequin.Factory.AccountsFactory do
  @moduledoc false
  import Sequin.Factory.Support

  alias Sequin.Accounts.Account
  alias Sequin.Factory
  alias Sequin.Repo

  def account(attrs \\ []) do
    merge_attributes(
      %Account{
        inserted_at: Factory.utc_datetime(),
        updated_at: Factory.utc_datetime()
      },
      attrs
    )
  end

  def account_attrs(attrs \\ []) do
    attrs
    |> account()
    |> Sequin.Map.from_ecto()
  end

  def insert_account!(attrs \\ []) do
    attrs
    |> account()
    |> Repo.insert!()
  end

  def api_key(attrs \\ []) do
    merge_attributes(
      %Sequin.Accounts.ApiKey{
        name: "API Key #{:rand.uniform(1000)}",
        value: Ecto.UUID.generate(),
        account_id: Factory.uuid(),
        inserted_at: Factory.utc_datetime(),
        updated_at: Factory.utc_datetime()
      },
      attrs
    )
  end

  def api_key_attrs(attrs \\ []) do
    attrs
    |> api_key()
    |> Sequin.Map.from_ecto()
  end

  def insert_api_key!(attrs \\ []) do
    attrs = Map.new(attrs)
    {account_id, attrs} = Map.pop_lazy(attrs, :account_id, fn -> insert_account!().id end)

    attrs
    |> Map.put(:account_id, account_id)
    |> api_key()
    |> Repo.insert!()
  end
end