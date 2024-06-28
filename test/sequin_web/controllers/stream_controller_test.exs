defmodule SequinWeb.StreamControllerTest do
  use SequinWeb.ConnCase

  alias Sequin.Factory.AccountsFactory
  alias Sequin.Factory.StreamsFactory
  alias Sequin.Streams

  setup :authenticated_conn

  setup %{account: account} do
    other_account = AccountsFactory.insert_account!()
    stream = StreamsFactory.insert_stream!(account_id: account.id)
    other_stream = StreamsFactory.insert_stream!(account_id: other_account.id)
    %{stream: stream, other_stream: other_stream, other_account: other_account}
  end

  describe "index" do
    test "lists streams in the given account", %{conn: conn, account: account, stream: stream} do
      another_stream = StreamsFactory.insert_stream!(account_id: account.id)

      conn = get(conn, ~p"/api/streams")
      assert %{"data" => streams} = json_response(conn, 200)
      assert length(streams) == 2
      atomized_streams = Enum.map(streams, &Sequin.Map.atomize_keys/1)
      assert_lists_equal([stream, another_stream], atomized_streams, &(&1.id == &2.id))
    end

    test "does not list streams from another account", %{conn: conn, other_stream: other_stream} do
      conn = get(conn, ~p"/api/streams")
      assert %{"data" => streams} = json_response(conn, 200)
      refute Enum.any?(streams, &(&1["id"] == other_stream.id))
    end
  end

  describe "show" do
    test "shows stream details", %{conn: conn, stream: stream} do
      conn = get(conn, ~p"/api/streams/#{stream.id}")
      assert json_response = json_response(conn, 200)
      atomized_response = Sequin.Map.atomize_keys(json_response)

      assert_maps_equal(stream, atomized_response, [:id, :idx, :account_id])
    end

    test "returns 404 if stream belongs to another account", %{conn: conn, other_stream: other_stream} do
      conn = get(conn, ~p"/api/streams/#{other_stream.id}")
      assert json_response(conn, 404)
    end
  end

  describe "create" do
    test "creates a stream under the authenticated account", %{conn: conn, account: account} do
      conn = post(conn, ~p"/api/streams", %{})
      assert %{"id" => id} = json_response(conn, 200)

      {:ok, stream} = Streams.get_stream_for_account(account.id, id)
      assert stream.account_id == account.id
    end

    # test "returns validation error for invalid attributes", %{conn: conn} do
    #   # Assuming there's a validation on the Stream schema that we can trigger
    #   invalid_attrs = %{idx: "invalid"}
    #   conn = post(conn, ~p"/api/streams", invalid_attrs)
    #   assert json_response(conn, 422)["errors"] != %{}
    # end

    test "ignores provided account_id and uses authenticated account", %{
      conn: conn,
      account: account,
      other_account: other_account
    } do
      conn = post(conn, ~p"/api/streams", %{account_id: other_account.id})
      assert %{"id" => id} = json_response(conn, 200)

      {:ok, stream} = Streams.get_stream_for_account(account.id, id)
      assert stream.account_id == account.id
      assert stream.account_id != other_account.id
    end
  end

  describe "delete" do
    test "deletes the stream", %{conn: conn, stream: stream} do
      conn = delete(conn, ~p"/api/streams/#{stream.id}")
      assert %{"id" => id, "deleted" => true} = json_response(conn, 200)

      assert {:error, _} = Streams.get_stream_for_account(stream.account_id, id)
    end

    test "returns 404 if stream belongs to another account", %{conn: conn, other_stream: other_stream} do
      conn = delete(conn, ~p"/api/streams/#{other_stream.id}")
      assert json_response(conn, 404)
    end
  end
end