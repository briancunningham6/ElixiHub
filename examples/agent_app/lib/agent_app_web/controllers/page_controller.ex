defmodule AgentAppWeb.PageController do
  use Phoenix.Controller,
    formats: [:html, :json],
    layouts: [html: AgentAppWeb.Layouts]
    
  import Plug.Conn

  def home(conn, _params) do
    current_user = conn.assigns[:current_user]
    
    if current_user do
      # User is authenticated, redirect to chat
      redirect(conn, to: "/chat")
    else
      # User is not authenticated, show SSO login page
      elixihub_config = Application.get_env(:agent_app, :elixihub)
      elixihub_url = elixihub_config[:elixihub_url] || "http://localhost:4005"
      
      # Hardcode the Agent app URL for now since endpoint URL is not working correctly
      agent_url = "http://192.168.0.188:4003"
      return_url = "#{agent_url}/auth/sso_callback"
      sso_url = "#{elixihub_url}/sso/auth?return_to=#{URI.encode(return_url)}"
      
      html(conn, """
      <!DOCTYPE html>
      <html>
      <head>
        <title>ElixiHub Agent</title>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          body { font-family: system-ui, sans-serif; margin: 0; padding: 2rem; background: #f3f4f6; }
          .container { max-width: 600px; margin: 0 auto; background: white; padding: 2rem; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
          .title { color: #1f2937; margin-bottom: 1rem; }
          .description { color: #6b7280; margin-bottom: 2rem; line-height: 1.6; }
          .login-btn { display: inline-block; background: #3b82f6; color: white; padding: 0.75rem 1.5rem; text-decoration: none; border-radius: 6px; font-weight: 500; }
          .login-btn:hover { background: #2563eb; }
        </style>
      </head>
      <body>
        <div class="container">
          <h1 class="title">Welcome to ElixiHub Agent</h1>
          <p class="description">
            The ElixiHub Agent is an AI-powered chat interface that can interact with applications deployed on your ElixiHub platform.
            Click below to sign in with your ElixiHub account - you'll be seamlessly authenticated!
          </p>
          <div style="margin-bottom: 1rem;">
            <a href="#{sso_url}" class="login-btn">Sign in with ElixiHub</a>
          </div>
          
          <div style="border-top: 1px solid #e5e7eb; padding-top: 1rem; margin-top: 1rem;">
            <p style="color: #6b7280; margin-bottom: 1rem; font-size: 0.875rem;">
              <strong>Seamless Single Sign-On:</strong><br>
              • If you're already logged in to ElixiHub, you'll be authenticated instantly<br>
              • If not, you'll be redirected to ElixiHub login and then back here automatically<br>
              • No need to copy and paste tokens!
            </p>
            
            <details style="margin-top: 1rem;">
              <summary style="cursor: pointer; color: #6b7280; font-size: 0.875rem;">Advanced: Manual Token Entry</summary>
              <div style="margin-top: 1rem; padding: 1rem; background: #f9fafb; border-radius: 4px;">
                <p style="color: #6b7280; margin-bottom: 1rem; font-size: 0.875rem;">
                  For testing or advanced use, you can manually enter a JWT token from: 
                  <a href="#{elixihub_url}/api/auth/token" target="_blank" style="color: #3b82f6; text-decoration: underline;">
                    #{elixihub_url}/api/auth/token
                  </a>
                </p>
                <form action="/auth/callback" method="get" style="display: flex; gap: 0.5rem;">
                  <input type="text" name="token" placeholder="Paste your JWT token here..." 
                         style="flex: 1; padding: 0.5rem; border: 1px solid #d1d5db; border-radius: 4px;" required>
                  <button type="submit" style="background: #10b981; color: white; padding: 0.5rem 1rem; border: none; border-radius: 4px; cursor: pointer;">
                    Authenticate
                  </button>
                </form>
              </div>
            </details>
          </div>
        </div>
      </body>
      </html>
      """)
    end
  end

  def health(conn, _params) do
    # Simple health check endpoint
    openai_config = Application.get_env(:agent_app, :openai)
    api_key_configured = openai_config[:api_key] && openai_config[:api_key] != "your_openai_api_key_here"
    
    mcp_status = try do
      case AgentApp.MCPManager.list_available_tools() do
        {:ok, tools} -> "ok (#{length(tools)} tools)"
        {:error, reason} -> "error: #{inspect(reason)}"
      end
    catch
      kind, reason -> "error: #{kind} - #{inspect(reason)}"
    end

    status = %{
      status: "ok",
      timestamp: DateTime.utc_now(),
      openai_configured: api_key_configured,
      mcp_manager: mcp_status,
      application: "agent_app",
      version: "0.1.0"
    }

    json(conn, status)
  end
end