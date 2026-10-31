/*
# Add product reviews and image storage

1. New Tables
- `product_reviews`: stores customer reviews and ratings for products.
  - `id` (uuid, primary key)
  - `product_id` (uuid, references store_products)
  - `user_id` (uuid, references auth.users, defaults to auth.uid())
  - `rating` (integer 1-5)
  - `comment` (text)
  - `created_at` (timestamptz)
  - `user_name` (text, denormalized for display)
2. Storage
- Create a public storage bucket `product-images` for uploading product photos.
- Allow public read; allow authenticated users to upload.
3. Security
- Enable RLS on product_reviews.
- SELECT is public (anyone can read reviews).
- INSERT only for authenticated users (user_id defaults to auth.uid()).
- UPDATE/DELETE only for the review owner.
- Grant SELECT to anon+authenticated; INSERT/UPDATE/DELETE to authenticated.
- Storage policies: public read, authenticated upload to product-images bucket.
4. Notes
- Reviews can only be written by authenticated users who purchased the product.
  The frontend enforces this check; the RLS ensures only authenticated users can insert.
- The `user_name` column stores the display name so reviews show names without joining auth.users.
- The storage bucket is public so product images load without signed URLs.
*/

CREATE TABLE IF NOT EXISTS public.product_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES public.store_products(id) ON DELETE CASCADE,
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  rating integer NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment text NOT NULL DEFAULT '',
  user_name text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.product_reviews ENABLE ROW LEVEL SECURITY;

GRANT SELECT ON public.product_reviews TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.product_reviews TO authenticated;

DROP POLICY IF EXISTS "Public can read reviews" ON public.product_reviews;
CREATE POLICY "Public can read reviews" ON public.product_reviews
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Authenticated can insert reviews" ON public.product_reviews;
CREATE POLICY "Authenticated can insert reviews" ON public.product_reviews
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own reviews" ON public.product_reviews;
CREATE POLICY "Users can update own reviews" ON public.product_reviews
  FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own reviews" ON public.product_reviews;
CREATE POLICY "Users can delete own reviews" ON public.product_reviews
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS product_reviews_product_id_idx ON public.product_reviews(product_id);

INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Public read product-images" ON storage.objects;
CREATE POLICY "Public read product-images" ON storage.objects
  FOR SELECT TO anon, authenticated
  USING (bucket_id = 'product-images');

DROP POLICY IF EXISTS "Authenticated upload product-images" ON storage.objects;
CREATE POLICY "Authenticated upload product-images" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'product-images');

DROP POLICY IF EXISTS "Authenticated update own product-images" ON storage.objects;
CREATE POLICY "Authenticated update own product-images" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'product-images' AND owner = auth.uid())
  WITH CHECK (bucket_id = 'product-images' AND owner = auth.uid());

DROP POLICY IF EXISTS "Authenticated delete own product-images" ON storage.objects;
CREATE POLICY "Authenticated delete own product-images" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'product-images' AND owner = auth.uid());
