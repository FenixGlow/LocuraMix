/*
# Add administrator user directory data

1. Profile changes
- Add `customer_profiles.email` so the administrator directory can search and display the account email.
- Backfill existing profiles from the corresponding authenticated account when available.
- Add lookup indexes for name, email, identification number, and phone.

2. Security changes
- Customers can continue reading only their own profile.
- Administrators with immutable `app_metadata.role = 'admin'` can read all customer profiles for support and order management.
- No anonymous role receives access to customer profiles.

3. Important notes
- Existing profile records are preserved.
- The directory is a read-only administration feature; it does not grant customers access to other accounts.
*/

ALTER TABLE public.customer_profiles
  ADD COLUMN IF NOT EXISTS email text;

UPDATE public.customer_profiles AS profiles
SET email = accounts.email
FROM auth.users AS accounts
WHERE accounts.id = profiles.user_id
  AND (profiles.email IS NULL OR profiles.email = '');

CREATE INDEX IF NOT EXISTS customer_profiles_name_idx
  ON public.customer_profiles (lower(first_name), lower(last_name));
CREATE INDEX IF NOT EXISTS customer_profiles_email_idx
  ON public.customer_profiles (lower(email));
CREATE INDEX IF NOT EXISTS customer_profiles_national_id_idx
  ON public.customer_profiles (national_id);
CREATE INDEX IF NOT EXISTS customer_profiles_phone_idx
  ON public.customer_profiles (phone);

DROP POLICY IF EXISTS "Users can read their profile" ON public.customer_profiles;
CREATE POLICY "Users and admins can read profiles"
ON public.customer_profiles FOR SELECT
TO authenticated
USING (
  auth.uid() = user_id
  OR (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
);