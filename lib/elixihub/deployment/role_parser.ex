defmodule Elixihub.Deployment.RoleParser do
  @moduledoc """
  Parses role definitions from deployed applications.
  """

  @doc """
  Extracts role definitions from an application directory.
  
  Looks for role definitions in the following locations:
  - roles.json
  - config/roles.json
  - .elixihub/roles.json
  - package.json (for Node.js apps with elixihub.roles field)
  - mix.exs (for Elixir apps with elixihub_roles function)
  """
  def extract_roles(connection, app_path) do
    role_files = [
      "#{app_path}/roles.json",
      "#{app_path}/config/roles.json", 
      "#{app_path}/.elixihub/roles.json",
      "#{app_path}/package.json",
      "#{app_path}/mix.exs"
    ]

    extract_from_files(connection, role_files)
  end

  defp extract_from_files(connection, files) do
    Enum.reduce_while(files, [], fn file, acc ->
      case extract_from_file(connection, file) do
        {:ok, roles} when roles != [] -> {:halt, {:ok, roles}}
        {:ok, []} -> {:cont, acc}
        {:error, _} -> {:cont, acc}
      end
    end)
    |> case do
      {:ok, roles} -> {:ok, roles}
      [] -> {:ok, []}
    end
  end

  defp extract_from_file(connection, file_path) do
    case Elixihub.Deployment.SSHClient.execute_command(connection, "cat #{file_path}") do
      {:ok, {content, _stderr, 0}} ->
        parse_file_content(file_path, String.trim(content))
      
      {:ok, {_stdout, _stderr, _exit_code}} ->
        {:error, :file_not_found}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_file_content(file_path, content) do
    cond do
      String.ends_with?(file_path, "roles.json") ->
        parse_roles_json(content)
      
      String.ends_with?(file_path, "package.json") ->
        parse_package_json(content)
      
      String.ends_with?(file_path, "mix.exs") ->
        parse_mix_exs(content)
      
      true ->
        {:error, :unsupported_file_type}
    end
  end

  defp parse_roles_json(content) do
    case Jason.decode(content) do
      {:ok, %{"roles" => roles}} when is_list(roles) ->
        {:ok, validate_and_normalize_roles(roles)}
      
      {:ok, roles} when is_list(roles) ->
        {:ok, validate_and_normalize_roles(roles)}
      
      {:ok, _} ->
        {:error, :invalid_format}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_package_json(content) do
    case Jason.decode(content) do
      {:ok, %{"elixihub" => %{"roles" => roles}}} when is_list(roles) ->
        {:ok, validate_and_normalize_roles(roles)}
      
      {:ok, _} ->
        {:ok, []}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_mix_exs(content) do
    # Look for elixihub_roles function definition
    case Regex.run(~r/def elixihub_roles.*?do\s*(.*?)\s*end/s, content) do
      [_full, roles_code] ->
        # This is a simplified parser - in production you'd want a more robust Elixir parser
        case extract_roles_from_elixir_code(roles_code) do
          {:ok, roles} -> {:ok, validate_and_normalize_roles(roles)}
          {:error, reason} -> {:error, reason}
        end
      
      nil ->
        {:ok, []}
    end
  end

  defp extract_roles_from_elixir_code(code) do
    # Simple pattern matching for role definitions
    # This is a basic implementation - you might want to use Code.eval_string with safety
    case Regex.scan(~r/%\{[^}]*identifier:\s*"([^"]*)"[^}]*name:\s*"([^"]*)"[^}]*\}/, code) do
      matches when matches != [] ->
        roles = Enum.map(matches, fn [_full, identifier, name] ->
          %{
            "identifier" => identifier,
            "name" => name,
            "description" => "Role defined in mix.exs",
            "permissions" => %{},
            "metadata" => %{}
          }
        end)
        {:ok, roles}
      
      [] ->
        {:ok, []}
    end
  rescue
    _ -> {:error, :parse_error}
  end

  defp validate_and_normalize_roles(roles) do
    roles
    |> Enum.filter(&valid_role?/1)
    |> Enum.map(&normalize_role/1)
  end

  defp valid_role?(role) when is_map(role) do
    has_required_fields?(role) && valid_identifier?(role["identifier"])
  end
  defp valid_role?(_), do: false

  defp has_required_fields?(role) do
    role["identifier"] && role["name"] && 
    is_binary(role["identifier"]) && is_binary(role["name"])
  end

  defp valid_identifier?(identifier) do
    String.match?(identifier, ~r/^[a-z0-9_]+$/)
  end

  defp normalize_role(role) do
    %{
      identifier: role["identifier"],
      name: role["name"],
      description: role["description"] || "",
      permissions: role["permissions"] || %{},
      metadata: role["metadata"] || %{}
    }
  end
end