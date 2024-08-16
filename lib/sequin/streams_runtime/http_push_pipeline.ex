defmodule Sequin.StreamsRuntime.HttpPushPipeline do
  @moduledoc false
  use Broadway

  alias Sequin.Error
  alias Sequin.Repo
  alias Sequin.Streams.Consumer
  alias Sequin.Streams.HttpEndpoint
  alias Sequin.Streams.Message

  require Logger

  def start_link(opts) do
    %Consumer{} = consumer = Keyword.fetch!(opts, :consumer)
    consumer = Repo.preload(consumer, :http_endpoint)
    producer = Keyword.get(opts, :producer, Sequin.StreamsRuntime.ConsumerProducer)
    req_opts = Keyword.get(opts, :req_opts, [])

    Broadway.start_link(__MODULE__,
      name: via_tuple(consumer.id),
      producer: [
        module: {producer, [consumer: consumer]}
      ],
      processors: [
        default: [
          concurrency: consumer.max_waiting,
          max_demand: 10
        ]
      ],
      context: %{
        consumer: consumer,
        http_endpoint: consumer.http_endpoint,
        req_opts: req_opts
      }
    )
  end

  def via_tuple(consumer_id) do
    Sequin.Registry.via_tuple({__MODULE__, consumer_id})
  end

  # Used by Broadway to name processes in topology according to our registry
  @impl Broadway
  def process_name({:via, Registry, {Sequin.Registry, {__MODULE__, id}}}, base_name) do
    Sequin.Registry.via_tuple({__MODULE__, {base_name, id}})
  end

  @impl Broadway
  def handle_message(_, %Broadway.Message{data: %Message{} = m} = message, %{
        consumer: consumer,
        http_endpoint: http_endpoint,
        req_opts: req_opts
      }) do
    Logger.metadata(consumer_id: consumer.id, http_endpoint_id: http_endpoint.id)

    case push_message(http_endpoint, m, req_opts) do
      :ok ->
        message

      {:error, reason} ->
        Logger.error("Failed to push message: #{inspect(reason)}")
        Broadway.Message.failed(message, reason)
    end
  end

  defp push_message(%HttpEndpoint{} = http_endpoint, %Message{} = message, req_opts) do
    req =
      [
        base_url: http_endpoint.base_url,
        headers: http_endpoint.headers,
        json: %{data: message.data, key: message.key}
      ]
      |> Keyword.merge(req_opts)
      |> Req.new()

    case Req.post(req) do
      {:ok, response} ->
        ensure_status(response)

      {:error, %Mint.TransportError{reason: reason}} ->
        {:error,
         Error.service(
           service: :http_endpoint,
           code: "transport_error",
           message: "POST to webhook endpoint failed",
           details: reason
         )}

      {:error, reason} ->
        {:error,
         Error.service(service: :http_endpoint, code: "unknown_error", message: "Request failed", details: reason)}
    end
  end

  defp ensure_status(%Req.Response{} = response) do
    if response.status in 200..299 do
      :ok
    else
      {:error,
       Error.service(
         service: :http_endpoint,
         code: "bad_status",
         message: "Unexpected status code",
         details: %{status: response.status, body: response.body}
       )}
    end
  end
end