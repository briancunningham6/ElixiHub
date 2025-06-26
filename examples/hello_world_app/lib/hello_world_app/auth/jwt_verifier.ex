defmodule HelloWorldApp.Auth.JWTVerifier do
  @moduledoc """
  JWT verification module that uses ElixiHub's JWKS endpoint for token validation.
  """

  use Joken.Config

  @elixihub_base_url Application.compile_env(:hello_world_app, :elixihub_base_url, "http://localhost:4005")
  @jwks_url "#{@elixihub_base_url}/.well-known/jwks.json"

  # Cache JWKS for 5 minutes to avoid frequent requests
  @jwks_cache_ttl 5 * 60 * 1000

  @doc """
  Verify a JWT token using ElixiHub's JWKS.
  """
  def verify_token(token) do
    with {:ok, jwks} <- fetch_jwks(),
         {:ok, claims} <- verify_token_with_jwks(token, jwks) do
      # Enhance claims with user permissions from ElixiHub
      enhance_claims_with_permissions(claims)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Fetch JWKS from ElixiHub with caching.
  """
  def fetch_jwks do
    case get_cached_jwks() do
      nil ->
        fetch_and_cache_jwks()
      jwks ->
        {:ok, jwks}
    end
  end

  defp get_cached_jwks do
    case :ets.lookup(:jwks_cache, :jwks) do
      [{:jwks, jwks, timestamp}] ->
        if System.system_time(:millisecond) - timestamp < @jwks_cache_ttl do
          jwks
        else
          :ets.delete(:jwks_cache, :jwks)
          nil
        end
      [] ->
        nil
    end
  end

  defp fetch_and_cache_jwks do
    # Ensure ETS table exists
    ensure_ets_table()

    case HTTPoison.get(@jwks_url, [], timeout: 10_000, recv_timeout: 10_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, jwks} ->
            timestamp = System.system_time(:millisecond)
            :ets.insert(:jwks_cache, {:jwks, jwks, timestamp})
            {:ok, jwks}
          {:error, reason} ->
            {:error, {:json_decode_error, reason}}
        end

      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, {:network_error, reason}}
    end
  end

  defp ensure_ets_table do
    unless :ets.whereis(:jwks_cache) != :undefined do
      :ets.new(:jwks_cache, [:set, :public, :named_table])
    end
  end

  defp verify_token_with_jwks(token, jwks) do
    with {:ok, %{"keys" => keys}} <- {:ok, jwks},
         {:ok, header} <- Joken.peek_header(token),
         {:ok, key_data} <- find_key(keys, header["kid"]),
         {:ok, signer} <- create_signer(key_data) do
      
      # Use Joken directly with the signer
      case Joken.verify_and_validate(token, signer) do
        {:ok, claims} -> {:ok, claims}
        {:error, reason} -> {:error, {:verification_failed, reason}}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp find_key(keys, kid) do
    case Enum.find(keys, fn key -> key["kid"] == kid end) do
      nil -> {:error, {:key_not_found, kid}}
      key -> {:ok, key}
    end
  end

  defp create_signer(key_data) do
    case key_data do
      %{"kty" => "RSA", "n" => n, "e" => e} ->
        # Create RSA signer from JWK
        jwk = %{
          "kty" => "RSA",
          "n" => n,
          "e" => e
        }
        {:ok, Joken.Signer.create("RS256", jwk)}

      %{"kty" => "oct", "k" => k} ->
        # Create HMAC signer from shared secret
        {:ok, Joken.Signer.create("HS256", k)}

      _ ->
        {:error, :unsupported_key_type}
    end
  end

  defp enhance_claims_with_permissions(claims) do
    # Fetch user permissions from ElixiHub API
    case fetch_user_permissions(claims["sub"]) do
      {:ok, permissions} ->
        enhanced_claims = Map.put(claims, "permissions", permissions)
        {:ok, enhanced_claims}
      
      {:error, _reason} ->
        # Continue without permissions if fetch fails
        {:ok, Map.put(claims, "permissions", [])}
    end
  end

  defp fetch_user_permissions(_user_id) do
    url = "#{@elixihub_base_url}/api/permissions"
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{get_service_token()}"}
    ]

    case HTTPoison.get(url, headers, timeout: 5_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"permissions" => permissions}} -> {:ok, permissions}
          _ -> {:error, :invalid_response}
        end

      _ ->
        {:error, :permissions_fetch_failed}
    end
  end

  # For service-to-service communication, you might want to use a service token
  # This is a simplified implementation - in production, you'd want proper service authentication
  defp get_service_token do
    Application.get_env(:hello_world_app, :service_token, "")
  end
end