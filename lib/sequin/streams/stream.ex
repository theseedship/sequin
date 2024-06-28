defmodule Sequin.Streams.Stream do
  @moduledoc false
  use Sequin.Schema

  import Ecto.Changeset

  alias Sequin.Accounts.Account
  alias Sequin.Streams.Stream

  typed_schema "streams" do
    field :idx, :integer, read_after_writes: true
    belongs_to :account, Account

    timestamps()
  end

  def changeset(%Stream{} = stream, attrs) do
    stream
    |> cast(attrs, [:account_id])
    |> validate_required([:account_id])
  end
end