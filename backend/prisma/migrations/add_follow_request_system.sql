-- Add status column to user_followers table for follow request system
-- This enables pending/accepted/declined states for follow requests

-- Add status column with default 'accepted' for existing records
ALTER TABLE user_followers 
ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'accepted';

-- Update existing records to have 'accepted' status (maintain current behavior)
UPDATE user_followers 
SET status = 'accepted' 
WHERE status IS NULL;

-- Create index for better performance on status queries
CREATE INDEX IF NOT EXISTS idx_user_followers_status 
ON user_followers(following_id, status);

-- Create index for follower status queries
CREATE INDEX IF NOT EXISTS idx_user_followers_follower_status 
ON user_followers(follower_id, status);
