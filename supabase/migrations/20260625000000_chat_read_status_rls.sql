-- HARDENING: sec-agent 2026-06-25
-- Migration to allow participants to update read status and edit messages in their rooms

CREATE POLICY "messages_update" ON public.messages FOR UPDATE
  USING (is_room_participant(room_id, auth.uid()))
  WITH CHECK (is_room_participant(room_id, auth.uid()));
