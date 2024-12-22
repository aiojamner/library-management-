export interface Profile {
  id: string;
  first_name: string;
  last_name: string;
  email: string;
  role: string;
}

export interface Book {
  id: string;
  title: string;
  author: string;
  isbn?: string;
  available_copies: number;
  total_copies: number;
  description?: string;
  publisher?: string;
  publication_date?: string;
}