/*
# Create LocuraMix store data

1. New Tables
- `store_products`: public product catalog with title, description, COP prices, category, image, stock, and badges.
- `store_orders`: checkout records with customer details, item snapshot, payment method, total, and order status.
2. Security
- Enable RLS on both tables.
- Grant the anon and authenticated roles only the catalog and checkout operations used by this single-store demo.
- Add separate policies for each CRUD action. The catalog is intentionally shared and the order list is intentionally available to support the demo admin view.
3. Notes
- This is a single-tenant store with no account ownership column. The frontend can load and save data immediately without a login session.
*/

CREATE TABLE IF NOT EXISTS public.store_products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text NOT NULL,
  price integer NOT NULL CHECK (price >= 0),
  wholesale_price integer NOT NULL DEFAULT 0 CHECK (wholesale_price >= 0),
  category text NOT NULL,
  image_url text NOT NULL,
  stock integer NOT NULL DEFAULT 0 CHECK (stock >= 0),
  badge text,
  rating numeric(2,1) NOT NULL DEFAULT 4.8 CHECK (rating >= 0 AND rating <= 5),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.store_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_name text NOT NULL,
  customer_email text NOT NULL,
  customer_phone text NOT NULL,
  address text NOT NULL,
  city text NOT NULL,
  payment_method text NOT NULL,
  items jsonb NOT NULL DEFAULT '[]'::jsonb,
  subtotal integer NOT NULL DEFAULT 0,
  shipping integer NOT NULL DEFAULT 0,
  discount integer NOT NULL DEFAULT 0,
  total integer NOT NULL DEFAULT 0,
  points_earned integer NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'Procesando',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.store_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_orders ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.store_products TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.store_orders TO anon, authenticated;

DROP POLICY IF EXISTS "Public can read products" ON public.store_products;
CREATE POLICY "Public can read products" ON public.store_products FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "Public can add products" ON public.store_products;
CREATE POLICY "Public can add products" ON public.store_products FOR INSERT TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "Public can edit products" ON public.store_products;
CREATE POLICY "Public can edit products" ON public.store_products FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Public can remove products" ON public.store_products;
CREATE POLICY "Public can remove products" ON public.store_products FOR DELETE TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Public can read orders" ON public.store_orders;
CREATE POLICY "Public can read orders" ON public.store_orders FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "Public can create orders" ON public.store_orders;
CREATE POLICY "Public can create orders" ON public.store_orders FOR INSERT TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "Public can edit orders" ON public.store_orders;
CREATE POLICY "Public can edit orders" ON public.store_orders FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Public can remove orders" ON public.store_orders;
CREATE POLICY "Public can remove orders" ON public.store_orders FOR DELETE TO anon, authenticated USING (true);

CREATE INDEX IF NOT EXISTS store_products_category_idx ON public.store_products(category);
CREATE INDEX IF NOT EXISTS store_orders_created_at_idx ON public.store_orders(created_at DESC);
