/*
# Add product image galleries

1. Modified Tables
- `store_products`: add `image_urls` as a JSON array containing one to ten gallery image URLs.
- Existing `image_url` remains as the primary image for compatibility with current products.
2. Security
- Existing public CRUD grants and RLS policies remain unchanged because this only adds a catalog field to the existing single-store table.
3. Important Notes
- The frontend uses the first gallery image as the cover and falls back to `image_url` for older records.
- New products can provide between one and ten image URLs from the administration view.
*/

ALTER TABLE public.store_products
  ADD COLUMN IF NOT EXISTS image_urls jsonb NOT NULL DEFAULT '[]'::jsonb;
