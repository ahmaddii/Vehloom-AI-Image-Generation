-- Create device_tokens table
CREATE TABLE IF NOT EXISTS public.device_tokens (
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    token text NOT NULL,
    platform text NOT NULL,
    updated_at timestamptz DEFAULT now(),
    PRIMARY KEY (user_id, token)
);

-- Enable RLS
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

-- Allow users to insert/update their own tokens
CREATE POLICY "Users can manage their own device tokens" 
ON public.device_tokens 
FOR ALL USING (auth.uid() = user_id);


