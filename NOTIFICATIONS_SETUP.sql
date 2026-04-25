-- ============================================================
-- Run this ONCE in Supabase SQL Editor to enable notifications
-- ============================================================

-- Table to store each device's OneSignal Player ID
CREATE TABLE IF NOT EXISTS user_push_tokens (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  player_id text NOT NULL,
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id)
);

-- RLS: users can only manage their own token
ALTER TABLE user_push_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own token" ON user_push_tokens
  FOR ALL USING (auth.uid() = user_id);

-- Allow Edge Function (service role) full access
CREATE POLICY "Service role full access" ON user_push_tokens
  FOR ALL TO service_role USING (true);
