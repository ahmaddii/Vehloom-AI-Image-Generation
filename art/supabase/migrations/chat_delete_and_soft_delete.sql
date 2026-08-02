-- WhatsApp-style message deletion + RLS fixes
-- Run in Supabase SQL editor if not applied via migrations.

-- Soft-delete columns
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS "deletedFor" TEXT[] DEFAULT '{}';
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS "deletedForEveryone" BOOLEAN DEFAULT false;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS "deletedAt" TIMESTAMPTZ NULL;

-- Fix DELETE policy (senderId is stored as TEXT)
DROP POLICY IF EXISTS "Users can delete their own messages" ON public.messages;
CREATE POLICY "Users can delete their own messages"
  ON public.messages
  FOR DELETE
  USING (auth.uid()::text = "senderId");

-- Allow participants to update messages (reactions, soft delete)
DROP POLICY IF EXISTS "Participants can update messages" ON public.messages;
CREATE POLICY "Participants can update messages"
  ON public.messages
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM "chatRooms" cr
      WHERE cr.id = messages."roomId"
        AND cr.participants @> ARRAY[auth.uid()::text]
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM "chatRooms" cr
      WHERE cr.id = messages."roomId"
        AND cr.participants @> ARRAY[auth.uid()::text]
    )
  );
