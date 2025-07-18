defmodule ElixihubWeb.MaydayController do
  use ElixihubWeb, :controller
  
  alias Elixihub.Mayday.TwilioService
  
  def voice_webhook(conn, params) do
    response = TwilioService.process_voice_call(params)
    
    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, response)
  end
  
  def recording_webhook(conn, params) do
    TwilioService.process_recording(params)
    
    # Return empty TwiML response
    response = """
    <?xml version="1.0" encoding="UTF-8"?>
    <Response>
    </Response>
    """
    
    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, response)
  end
end