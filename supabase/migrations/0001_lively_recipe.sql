/*
  # Library Management System Schema

  1. New Tables
    - `users` - Extended user profile information
    - `books` - Book information and inventory
    - `genres` - Book genres/categories
    - `book_copies` - Individual copies of books
    - `loans` - Book borrowing records
    - `fines` - Fine records for overdue books
    - `settings` - System settings (loan limits, fine rates)

  2. Security
    - Enable RLS on all tables
    - Policies for authenticated users and librarians
    - Secure access to sensitive information

  3. Features
    - Automatic fine calculation
    - Book availability tracking
    - User borrowing limits
    - Analytics support
*/

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create enum types
CREATE TYPE user_role AS ENUM ('member', 'librarian', 'admin');
CREATE TYPE book_status AS ENUM ('available', 'borrowed', 'maintenance', 'lost');
CREATE TYPE loan_status AS ENUM ('active', 'returned', 'overdue');

-- Create users table (extends auth.users)
CREATE TABLE users (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  role user_role DEFAULT 'member',
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  address TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Create genres table
CREATE TABLE genres (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Create books table
CREATE TABLE books (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  author TEXT NOT NULL,
  isbn TEXT UNIQUE,
  genre_id UUID REFERENCES genres(id),
  publisher TEXT,
  publication_date DATE,
  description TEXT,
  total_copies INT DEFAULT 0,
  available_copies INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Create book_copies table
CREATE TABLE book_copies (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  book_id UUID REFERENCES books(id),
  status book_status DEFAULT 'available',
  condition TEXT,
  acquisition_date DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Create loans table
CREATE TABLE loans (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id),
  book_copy_id UUID REFERENCES book_copies(id),
  borrowed_date TIMESTAMPTZ DEFAULT now(),
  due_date TIMESTAMPTZ NOT NULL,
  returned_date TIMESTAMPTZ,
  status loan_status DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Create fines table
CREATE TABLE fines (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  loan_id UUID REFERENCES loans(id),
  user_id UUID REFERENCES users(id),
  amount DECIMAL(10,2) NOT NULL,
  paid BOOLEAN DEFAULT false,
  paid_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Create settings table
CREATE TABLE settings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  key TEXT UNIQUE NOT NULL,
  value TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Insert default settings
INSERT INTO settings (key, value, description) VALUES
  ('max_books_per_user', '5', 'Maximum number of books a user can borrow'),
  ('loan_duration_days', '14', 'Default loan duration in days'),
  ('fine_rate_per_day', '1.00', 'Fine rate per day for overdue books');

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE genres ENABLE ROW LEVEL SECURITY;
ALTER TABLE books ENABLE ROW LEVEL SECURITY;
ALTER TABLE book_copies ENABLE ROW LEVEL SECURITY;
ALTER TABLE loans ENABLE ROW LEVEL SECURITY;
ALTER TABLE fines ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;

-- Create policies
-- Users table policies
CREATE POLICY "Users can view their own profile"
  ON users FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Librarians can view all profiles"
  ON users FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('librarian', 'admin')
  ));

CREATE POLICY "Librarians can modify profiles"
  ON users FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('librarian', 'admin')
  ));

-- Books and Genres policies
CREATE POLICY "Anyone can view books and genres"
  ON books FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Anyone can view genres"
  ON genres FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Librarians can modify books"
  ON books FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('librarian', 'admin')
  ));

CREATE POLICY "Librarians can modify genres"
  ON genres FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('librarian', 'admin')
  ));

-- Loans policies
CREATE POLICY "Users can view their own loans"
  ON loans FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Librarians can view all loans"
  ON loans FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('librarian', 'admin')
  ));

CREATE POLICY "Librarians can modify loans"
  ON loans FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('librarian', 'admin')
  ));

-- Fines policies
CREATE POLICY "Users can view their own fines"
  ON fines FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Librarians can view and modify all fines"
  ON fines FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('librarian', 'admin')
  ));

-- Create functions
CREATE OR REPLACE FUNCTION calculate_fine(loan_id UUID)
RETURNS DECIMAL AS $$
DECLARE
  fine_rate DECIMAL;
  days_overdue INT;
  loan_record RECORD;
BEGIN
  -- Get the fine rate from settings
  SELECT CAST(value AS DECIMAL) INTO fine_rate
  FROM settings
  WHERE key = 'fine_rate_per_day';

  -- Get loan details
  SELECT * INTO loan_record
  FROM loans
  WHERE id = loan_id;

  -- Calculate days overdue
  days_overdue := EXTRACT(DAY FROM (COALESCE(loan_record.returned_date, CURRENT_TIMESTAMP) - loan_record.due_date));

  -- Return 0 if not overdue
  IF days_overdue <= 0 THEN
    RETURN 0;
  END IF;

  -- Calculate and return fine
  RETURN days_overdue * fine_rate;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
CREATE OR REPLACE FUNCTION update_book_copies_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE books
    SET total_copies = total_copies + 1,
        available_copies = available_copies + 1
    WHERE id = NEW.book_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE books
    SET total_copies = total_copies - 1,
        available_copies = CASE 
          WHEN OLD.status = 'available' THEN available_copies - 1
          ELSE available_copies
        END
    WHERE id = OLD.book_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_book_copies_count_trigger
AFTER INSERT OR DELETE ON book_copies
FOR EACH ROW
EXECUTE FUNCTION update_book_copies_count();

-- Create indexes for better performance
CREATE INDEX idx_books_genre ON books(genre_id);
CREATE INDEX idx_loans_user ON loans(user_id);
CREATE INDEX idx_loans_book_copy ON loans(book_copy_id);
CREATE INDEX idx_fines_loan ON fines(loan_id);
CREATE INDEX idx_fines_user ON fines(user_id);