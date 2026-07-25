CREATE EXTENSION IF NOT EXISTS pg_net;

CREATE OR REPLACE FUNCTION public.handle_new_message_notification()
RETURNS trigger AS $$
DECLARE
  auth_header text;
BEGIN
  -- Safely try to get the authorization header, do not crash if it doesn't exist
  BEGIN
    auth_header := current_setting('request.headers', true)::json->>'authorization';
  EXCEPTION WHEN OTHERS THEN
    auth_header := null;
  END;

  -- Only send the web request if we found an auth header, this prevents blocking the chat message insert
  IF auth_header IS NOT NULL THEN
    perform net.http_post(
        url := 'https://azswpzjhjnzhsfbzhluq.supabase.co/functions/v1/send-message-notification',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', auth_header
        ),
        body := jsonb_build_object(
            'record', row_to_json(NEW)
        )
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate the trigger
DROP TRIGGER IF EXISTS on_message_inserted_send_notification ON public.messages;
CREATE TRIGGER on_message_inserted_send_notification
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_message_notification();
