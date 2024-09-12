defmodule Sequin.ConsumersRuntime.TableProducerServerTest do
  use Sequin.DataCase, async: true
  use ExUnit.Case

  alias Sequin.ConsumersRuntime.TableProducerServer
  alias Sequin.Databases
  alias Sequin.Factory.CharacterFactory
  alias Sequin.Factory.ConsumersFactory
  alias Sequin.Factory.DatabasesFactory
  alias Sequin.Factory.ReplicationFactory
  alias Sequin.Mocks.ConsumersRuntime.RecordHandlerMock
  alias Sequin.Test.Support.Models.Character

  @moduletag :uses_characters

  setup do
    # Set up the database and consumer
    database = DatabasesFactory.insert_configured_postgres_database!()

    replication =
      ReplicationFactory.insert_postgres_replication!(
        account_id: database.account_id,
        postgres_database_id: database.id
      )

    {:ok, database} = Databases.update_tables(database)

    table = Sequin.Enum.find!(database.tables, &(&1.oid == Character.table_oid()))
    column = Sequin.Enum.find!(table.columns, &(&1.name == "updated_at"))

    consumer =
      ConsumersFactory.insert_http_pull_consumer!(
        replication_slot_id: replication.id,
        message_kind: :record,
        record_consumer_state: ConsumersFactory.record_consumer_state_attrs(sort_column_attnum: column.attnum),
        account_id: database.account_id
      )

    {:ok, consumer: consumer, table: table}
  end

  describe "TableProducerServer" do
    test "initializes, fetches, and paginates records correctly", %{
      consumer: consumer,
      table: table
    } do
      test_pid = self()
      page_size = 3

      # Mock the RecordHandlerMock to send messages back to the test process
      expect(RecordHandlerMock, :handle_records, 3, fn _ctx, messages ->
        send(test_pid, {:records_handled, messages})
        :ok
      end)

      # Insert initial 8 records
      characters =
        1..8 |> Enum.map(fn _ -> CharacterFactory.insert_character!() end) |> Enum.sort_by(& &1.updated_at, NaiveDateTime)

      pid =
        start_supervised!(
          {TableProducerServer,
           [
             consumer: consumer,
             record_handler_ctx: nil,
             record_handler_module: RecordHandlerMock,
             page_size: page_size,
             table_oid: table.oid,
             test_pid: self()
           ]}
        )

      Process.monitor(pid)

      # Check if the mock was called with the correct data for the first 3 pages
      for i <- 0..2 do
        assert_receive {:records_handled, messages}, 1000
        assert length(messages) == min(page_size, 8 - i * page_size)

        expected_characters = Enum.slice(characters, i * page_size, page_size)
        assert_records_match(messages, expected_characters)
      end

      assert_receive {:DOWN, _ref, :process, ^pid, :normal}
    end
  end

  defp assert_records_match(messages, characters) do
    assert_lists_equal(messages, characters, fn msg, character ->
      assert_maps_equal(msg, Map.from_struct(character), ["id", "name"], indifferent_keys: true)
    end)
  end
end