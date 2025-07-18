defmodule TaskManager.Auth.JWTVerifier do
  @moduledoc """
  JWT token verification using ElixiHub's JWKS endpoint.
  """
  
  use GenServer
  require Logger
  
  @refresh_interval 60_000 # 1 minute
  
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end
  
  def verify(token) do
    GenServer.call(__MODULE__, {:verify, token})
  end
  
  def init(_) do
    schedule_refresh()
    initial_state = %{keys: []}
    {:ok, fetch_keys(initial_state)}
  end
  
  def handle_call({:verify, token}, _from, state) do
    result = verify_token(token, state.keys)
    {:reply, result, state}
  end
  
  def handle_info(:refresh_keys, state) do
    schedule_refresh()
    {:noreply, fetch_keys(state)}
  end
  
  defp schedule_refresh do
    Process.send_after(self(), :refresh_keys, @refresh_interval)
  end
  
  defp fetch_keys(state) do
    jwks_url = Application.get_env(:task_manager, :elixihub)[:jwks_url]
    
    case HTTPoison.get(jwks_url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"keys" => keys}} ->
            parsed_keys = parse_jwks_keys(keys)
            Logger.info("Updated JWKS keys: #{length(parsed_keys)} keys loaded")
            %{state | keys: parsed_keys}
          _ ->
            Logger.error("Failed to parse JWKS response")
            state
        end
      {:error, error} ->
        Logger.error("Failed to fetch JWKS: #{inspect(error)}")
        state
    end
  end
  
  defp parse_jwks_keys(keys) do
    Enum.map(keys, fn key ->
      %{
        kid: key["kid"],
        kty: key["kty"],
        n: key["n"],
        e: key["e"],
        alg: key["alg"] || "RS256"
      }
    end)
  end
  
  defp verify_token(token, keys) do
    with {:ok, header} <- decode_header(token),
         {:ok, key} <- find_key(header["kid"], keys),
         {:ok, claims} <- verify_with_key(token, key) do
      {:ok, claims}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp decode_header(token) do
    case String.split(token, ".") do
      [header_b64, _payload_b64, _signature_b64] ->
        case Base.url_decode64(header_b64, padding: false) do
          {:ok, header_json} ->
            case Jason.decode(header_json) do
              {:ok, header} -> {:ok, header}
              _ -> {:error, :invalid_header}
            end
          _ -> {:error, :invalid_header}
        end
      _ -> {:error, :invalid_token_format}
    end
  end
  
  defp find_key(kid, keys) do
    case Enum.find(keys, fn key -> key.kid == kid end) do
      nil -> {:error, :key_not_found}
      key -> {:ok, key}
    end
  end
  
  defp verify_with_key(token, key) do
    issuer = Application.get_env(:task_manager, :elixihub)[:issuer]
    
    signer = Joken.Signer.create("RS256", %{
      "n" => key.n,
      "e" => key.e
    })
    
    config = %{
      "iss" => issuer,
      "aud" => "task_manager"
    }
    
    case Joken.verify(token, signer, config) do
      {:ok, claims} -> {:ok, claims}
      {:error, reason} -> {:error, reason}
    end
  end
end