/*
# Add product colors and sizes

1. Modified Tables
- `store_products`: add `available_colors` (jsonb array of color names) and `available_sizes` (jsonb array of size names).
- Both default to an empty array, meaning the product has no color/size variants.
2. Security
- No changes to existing RLS policies or grants. The new columns inherit the existing public CRUD access for this single-store app.
3. Notes
- Colors are stored as an array of common color names (e.g. ["Blanco", "Negro", "Rojo"]).
- Sizes are stored as an array of size names (e.g. ["S", "M", "L", "XL"]).
- When the arrays are empty, the product detail view hides the color/size selectors.
*/

ALTER TABLE public.store_products
  ADD COLUMN IF NOT EXISTS available_colors jsonb NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE public.store_products
  ADD COLUMN IF NOT EXISTS available_sizes jsonb NOT NULL DEFAULT '[]'::jsonb;
