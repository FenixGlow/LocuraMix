/*
# Add catalog management controls

1. Modified Tables
- `store_products`: add `is_visible` to control whether a product appears in the public store.
2. New Tables
- `store_categories`: reusable category names managed from the admin panel.
3. Security
- Enable RLS on `store_categories`.
- Grant public catalog CRUD access to both anon and authenticated roles for this single-store experience.
- Add separate policies for each catalog action.
4. Notes
- Existing products remain visible by default.
- Initial categories match the current store sections and are inserted only when missing.
*/

ALTER TABLE public.store_products
  ADD COLUMN IF NOT EXISTS is_visible boolean NOT NULL DEFAULT true;

CREATE TABLE IF NOT EXISTS public.store_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.store_categories ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.store_categories TO anon, authenticated;

DROP POLICY IF EXISTS "Public can read categories" ON public.store_categories;
CREATE POLICY "Public can read categories" ON public.store_categories FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "Public can add categories" ON public.store_categories;
CREATE POLICY "Public can add categories" ON public.store_categories FOR INSERT TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "Public can edit categories" ON public.store_categories;
CREATE POLICY "Public can edit categories" ON public.store_categories FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Public can remove categories" ON public.store_categories;
CREATE POLICY "Public can remove categories" ON public.store_categories FOR DELETE TO anon, authenticated USING (true);

INSERT INTO public.store_categories (name)
VALUES ('Tecnología'), ('Hogar'), ('Moda')
ON CONFLICT (name) DO NOTHING;
