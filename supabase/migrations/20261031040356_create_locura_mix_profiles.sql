/*
# Create customer profiles

1. New Tables
- `customer_profiles`: one private profile per signed-in customer.
- `user_id`: authenticated owner, filled automatically from the active session.
- `first_name`, `last_name`: customer name fields.
- `phone`: Colombian contact number.
- `department`, `city`, `address`: saved delivery information reused at checkout.
- `created_at`, `updated_at`: profile timestamps.
2. Security
- Enable RLS on `customer_profiles`.
- Grant authenticated users CRUD access.
- Add separate owner-only policies for SELECT, INSERT, UPDATE, and DELETE.
3. Notes
- Guest checkout remains available without a profile.
- Profile updates are only accepted for the current signed-in user.
*/

CREATE TABLE IF NOT EXISTS public.customer_profiles (
  user_id uuid PRIMARY KEY DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  first_name text NOT NULL,
  last_name text NOT NULL,
  phone text NOT NULL,
  department text NOT NULL,
  city text NOT NULL,
  address text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_profiles ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.customer_profiles TO authenticated;

DROP POLICY IF EXISTS "Users can read their profile" ON public.customer_profiles;
CREATE POLICY "Users can read their profile" ON public.customer_profiles FOR SELECT TO authenticated USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can create their profile" ON public.customer_profiles;
CREATE POLICY "Users can create their profile" ON public.customer_profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can update their profile" ON public.customer_profiles;
CREATE POLICY "Users can update their profile" ON public.customer_profiles FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can delete their profile" ON public.customer_profiles;
CREATE POLICY "Users can delete their profile" ON public.customer_profiles FOR DELETE TO authenticated USING (auth.uid() = user_id);
