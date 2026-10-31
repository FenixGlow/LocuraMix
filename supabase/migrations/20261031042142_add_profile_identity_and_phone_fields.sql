/*
# Add profile identity and phone metadata

1. New columns
- `customer_profiles.national_id`: optional government identification number requested during registration.
- `customer_profiles.phone_country_code`: international phone prefix, defaulting to Colombia (+57).

2. Modified table
- Extends `customer_profiles` without removing or changing existing customer data.
- Existing profiles remain valid because both new fields are nullable and the phone prefix has a meaningful default.

3. Security
- Existing row-level security policies on `customer_profiles` remain in force.
- No new public tables, roles, grants, or policies are introduced.

4. Important notes
- The application collects the new values during registration and allows authenticated users to edit them from configuration.
- The country prefix is stored separately from the local phone number for future international contact formatting.
*/

ALTER TABLE public.customer_profiles
  ADD COLUMN IF NOT EXISTS national_id text,
  ADD COLUMN IF NOT EXISTS phone_country_code text NOT NULL DEFAULT '+57';