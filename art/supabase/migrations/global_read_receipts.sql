-- Add columns for global read receipts
ALTER TABLE public."chatRooms" ADD COLUMN IF NOT EXISTS "lastMessageRead" boolean DEFAULT false;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS "isRead" boolean DEFAULT false;
