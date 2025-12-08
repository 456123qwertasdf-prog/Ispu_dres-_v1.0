-- Create notifications_subscriptions table for web push notifications
CREATE TABLE IF NOT EXISTS notifications_subscriptions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  endpoint TEXT NOT NULL,
  p256dh_key TEXT NOT NULL,
  auth_key TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, endpoint)
);

-- Enable RLS
ALTER TABLE notifications_subscriptions ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can manage their own subscriptions" ON notifications_subscriptions
  FOR ALL USING (auth.uid() = user_id);

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_notifications_subscriptions_user_id ON notifications_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_subscriptions_endpoint ON notifications_subscriptions(endpoint);

-- Add updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_notifications_subscriptions_updated_at 
  BEFORE UPDATE ON notifications_subscriptions 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
