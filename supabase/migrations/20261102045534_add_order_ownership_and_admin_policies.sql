/*
# Separate orders by customer account

1. Database changes
- Add `user_id` to `store_orders` as an optional reference to the authenticated customer.
- Existing guest orders remain unassigned instead of being attached to a new account.
- New signed-in orders can only store the active authenticated user's ID.

2. Security changes
- Remove the previous public order read, update, and delete policies.
- Authenticated customers can read only their own orders.
- Administrators identified by immutable `app_metadata.role = 'admin'` can read and update all orders.
- Guests can still create orders, but cannot read, update, or delete orders.
- Keep only the minimum Data API grants needed by each role.

3. Important notes
- No existing order data is deleted or reassigned.
- Orders created before this change remain visible to administrators and remain outside customer accounts.
*/

ALTER TABLE public.store_orders
  ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL;

DROP POLICY IF EXISTS "Public can read orders" ON public.store_orders;
DROP POLICY IF EXISTS "Public can create orders" ON public.store_orders;
DROP POLICY IF EXISTS "Public can edit orders" ON public.store_orders;
DROP POLICY IF EXISTS "Public can remove orders" ON public.store_orders;

REVOKE SELECT, UPDATE, DELETE ON public.store_orders FROM anon;
REVOKE SELECT, INSERT, UPDATE, DELETE ON public.store_orders FROM authenticated;
GRANT INSERT ON public.store_orders TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.store_orders TO authenticated;

CREATE POLICY "Customers read own orders or admins read all"
ON public.store_orders FOR SELECT
TO authenticated
USING (
  user_id = auth.uid()
  OR (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
);

CREATE POLICY "Guests and customers create valid orders"
ON public.store_orders FOR INSERT
TO anon, authenticated
WITH CHECK (user_id IS NULL OR user_id = auth.uid());

CREATE POLICY "Admins update orders"
ON public.store_orders FOR UPDATE
TO authenticated
USING ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
WITH CHECK ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

CREATE POLICY "Admins delete orders"
ON public.store_orders FOR DELETE
TO authenticated
USING ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');