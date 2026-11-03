/*
# Persist customer points from registered orders

1. New profile data
- Add `customer_profiles.points`, the durable points balance for each registered customer.
- Existing profiles start at zero, then receive a safe backfill from their already-owned orders.

2. Order behavior
- Calculate `points_earned` in the database from the order total for registered orders.
- Guest orders always receive zero points.
- After a registered order is created, automatically add its points to that customer's profile.

3. Security
- Customers can read their points through their own profile row.
- Customers cannot directly edit the points balance.
- Profile editing permissions remain limited to personal information fields.
- The points trigger runs with a fixed search path and cannot be called directly by anonymous or authenticated clients.

4. Important notes
- No orders or profiles are deleted.
- Existing owned orders are included in the initial balance when possible.
- Points are awarded once when the order is inserted and are not re-awarded when its status changes.
*/

ALTER TABLE public.customer_profiles
  ADD COLUMN IF NOT EXISTS points integer NOT NULL DEFAULT 0;

UPDATE public.customer_profiles AS profiles
SET points = COALESCE((
  SELECT SUM(GREATEST(orders.total, 0) / 10000)
  FROM public.store_orders AS orders
  WHERE orders.user_id = profiles.user_id
), 0);

REVOKE UPDATE ON public.customer_profiles FROM authenticated;
GRANT UPDATE (first_name, last_name, national_id, phone, phone_country_code, department, city, address, updated_at) ON public.customer_profiles TO authenticated;

CREATE OR REPLACE FUNCTION public.award_customer_order_points()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.points_earned := CASE
    WHEN NEW.user_id IS NULL THEN 0
    ELSE GREATEST(NEW.total, 0) / 10000
  END;

  IF NEW.user_id IS NOT NULL AND NEW.points_earned > 0 THEN
    UPDATE public.customer_profiles
    SET points = points + NEW.points_earned,
        updated_at = now()
    WHERE user_id = NEW.user_id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS award_customer_order_points_on_insert ON public.store_orders;
CREATE TRIGGER award_customer_order_points_on_insert
BEFORE INSERT ON public.store_orders
FOR EACH ROW
EXECUTE FUNCTION public.award_customer_order_points();

REVOKE EXECUTE ON FUNCTION public.award_customer_order_points() FROM PUBLIC, anon, authenticated;