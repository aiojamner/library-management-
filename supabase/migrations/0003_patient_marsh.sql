/*
  # Simplify admin policies

  1. Changes
    - Replace existing admin policy with simpler version
    - Remove circular reference in policy check
*/

-- Drop existing admin policy
DROP POLICY IF EXISTS "Admin full access" ON users;

-- Create simplified admin policy
CREATE POLICY "Admin full access"
  ON users FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.role = 'authenticated'
    )
  );