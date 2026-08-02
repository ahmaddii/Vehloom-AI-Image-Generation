-- Advanced Chat Features Migration
-- Adds columns for Image Sharing, Post/Profile Sharing, and Emoji Reactions

ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS "imageUrl" TEXT NULL;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS "sharedArtworkId" TEXT NULL;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS "sharedProfileId" TEXT NULL;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS "reactions" JSONB DEFAULT '{}'::jsonb;
