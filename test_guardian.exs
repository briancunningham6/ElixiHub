#!/usr/bin/env elixir

Mix.install([
  {:guardian, "~> 2.3"}
])

# Simple test to verify Guardian API works
defmodule TestGuardian do
  use Guardian, otp_app: :test_app

  def subject_for_token(user, _claims) do
    {:ok, to_string(user.id)}
  end

  def resource_from_claims(%{"sub" => id}) do
    {:ok, %{id: String.to_integer(id), email: "test@example.com"}}
  end
end

# Test user
user = %{id: 1, email: "test@example.com"}

case TestGuardian.encode_and_sign(user) do
  {:ok, token, _claims} ->
    IO.puts("✅ Guardian encode_and_sign works correctly")
    IO.puts("Token: #{String.slice(token, 0, 50)}...")
  {:error, reason} ->
    IO.puts("❌ Guardian encode_and_sign failed: #{inspect(reason)}")
end