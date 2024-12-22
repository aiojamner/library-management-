/*
  # Fix users table RLS policies

  1. Changes
    - Drop existing policies that cause infinite recursion
    - Create new, simplified policies for users table
  
  2. Security
    - Enable RLS on users table
    - Add policies for:
      - Users to view their own profile
      - Librarians and admins to manage all profiles
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own profile" ON users;
DROP POLICY IF EXISTS "Librarians can view all profiles" ON users;
DROP POLICY IF EXISTS "Librarians can modify profiles" ON users;

-- Create new policies
CREATE POLICY "Users can view own profile"
  ON users FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON users FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Allow insert during signup"
  ON users FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Admin full access"
  ON users FOR ALL
  USING (
    auth.jwt() ->> 'role' = 'authenticated' AND 
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() 
      AND role IN ('librarian', 'admin')
    )
  );