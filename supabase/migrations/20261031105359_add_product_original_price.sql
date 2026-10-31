/*
# Add original_price column to store_products

1. Modified Tables
- `store_products`
  - Added `original_price` (numeric, nullable) — optional previous price used to display a discount with strikethrough in product details.
2. Security
- No policy changes. RLS already enabled on store_products. The new column inherits existing grants.
3. Notes
- The column is nullable so existing products are unaffected. When `original_price` is set and greater than `price`, the frontend shows the old price struck through next to the current price, plus a discount percentage badge.
*/

ALTER TABLE store_products ADD COLUMN IF NOT EXISTS original_price numeric;
