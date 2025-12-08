-- Create OneSignal subscriptions table
CREATE TABLE IF NOT EXISTS onesignal_subscriptions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  player_id TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios', 'web')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, player_id)
);

-- Enable RLS
ALTER TABLE onesignal_subscriptions ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can manage their own subscriptions" 
  ON onesignal_subscriptions
  FOR ALL 
  USING (auth.uid() = user_id);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_onesignal_subscriptions_user_id 
  ON onesignal_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_onesignal_subscriptions_player_id 
  ON onesignal_subscriptions(player_id);
CREATE INDEX IF NOT EXISTS idx_onesignal_subscriptions_platform 
  ON onesignal_subscriptions(platform);

-- Add updated_at trigger
CREATE OR REPLACE FUNCTION update_onesignal_subscriptions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_onesignal_subscriptions_updated_at 
  BEFORE UPDATE ON onesignal_subscriptions 
  FOR EACH ROW 
  EXECUTE FUNCTION update_onesignal_subscriptions_updated_at();

