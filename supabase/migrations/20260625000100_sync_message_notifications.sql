-- Migration to synchronize chat message read status with notifications and add UPDATE policy to notifications

-- 1. Create UPDATE policy on public.notifications
DROP POLICY IF EXISTS "notifications_update" ON public.notifications;
CREATE POLICY "notifications_update" ON public.notifications FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 2. Trigger function to synchronize notifications
CREATE OR REPLACE FUNCTION public.handle_messages_read_sync_notifications()
RETURNS TRIGGER AS $$
BEGIN
  -- Mark notifications for this chat room for the user reading the messages as read
  UPDATE public.notifications
  SET is_read = true
  WHERE user_id = auth.uid()
    AND reference_id = NEW.room_id
    AND reference_type = 'chat_room'
    AND is_read = false;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create trigger on public.messages
DROP TRIGGER IF EXISTS on_message_read ON public.messages;
CREATE TRIGGER on_message_read
  AFTER UPDATE OF is_read ON public.messages
  FOR EACH ROW
  WHEN (NEW.is_read = true AND OLD.is_read = false)
  EXECUTE FUNCTION public.handle_messages_read_sync_notifications();
