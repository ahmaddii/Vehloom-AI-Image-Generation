-- 1. Fix DELETE permissions so users can delete their own messages
DROP POLICY IF EXISTS "Users can delete their own messages" ON public.messages;
CREATE POLICY "Users can delete their own messages"
  ON public.messages
  FOR DELETE
  USING (auth.uid() = uuid("senderId"));
  -- If senderId is stored as UUID in the DB, this works. If text, use auth.uid()::text = "senderId"
  -- Fallback to a looser one if needed:
  -- USING (true); -- Use cautiously

-- 2. Add columns for Phase 2 (Replies)
ALTER TABLE public.messages ADD COLUMN "replyToId" TEXT NULL;
ALTER TABLE public.messages ADD COLUMN "replyToContent" TEXT NULL;
