/*
# Create store vouchers and secure redemption

1. New table
- `store_vouchers.code`: unique customer-facing voucher code.
- `store_vouchers.discount_type`: percentage or fixed COP discount.
- `store_vouchers.discount_value`: discount amount or percentage.
- `store_vouchers.minimum_subtotal`: minimum cart subtotal required.
- `store_vouchers.max_uses` and `uses_count`: optional usage limit and atomic usage counter.
- `store_vouchers.expires_at` and `active`: availability controls.

2. Order changes
- Add `store_orders.voucher_code` to preserve the voucher used on each purchase.
- The database recalculates the voucher discount and total when an order is inserted.
- Voucher usage is incremented under row lock, so two simultaneous redemptions cannot exceed the limit.

3. Security
- Only administrators can create, edit, activate, or deactivate vouchers.
- Customers can call the limited validation function without seeing the voucher catalog.
- The order trigger is not directly callable by browser roles and uses a fixed search path.

4. Important notes
- Invalid, inactive, expired, below-minimum, or exhausted vouchers are rejected by the database.
- No existing orders are changed.
- Existing order ownership can still be reconciled in the administration view using the stored customer email and phone.
*/

CREATE TABLE IF NOT EXISTS public.store_vouchers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL,
  discount_type text NOT NULL CHECK (discount_type IN ('percentage', 'fixed')),
  discount_value integer NOT NULL CHECK (discount_value > 0),
  minimum_subtotal integer NOT NULL DEFAULT 0 CHECK (minimum_subtotal >= 0),
  max_uses integer CHECK (max_uses IS NULL OR max_uses > 0),
  uses_count integer NOT NULL DEFAULT 0 CHECK (uses_count >= 0),
  active boolean NOT NULL DEFAULT true,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS store_vouchers_code_key ON public.store_vouchers (upper(code));
ALTER TABLE public.store_vouchers ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON public.store_vouchers TO authenticated;

DROP POLICY IF EXISTS "Admins can read vouchers" ON public.store_vouchers;
CREATE POLICY "Admins can read vouchers" ON public.store_vouchers FOR SELECT TO authenticated
USING ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');
DROP POLICY IF EXISTS "Admins can create vouchers" ON public.store_vouchers;
CREATE POLICY "Admins can create vouchers" ON public.store_vouchers FOR INSERT TO authenticated
WITH CHECK ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');
DROP POLICY IF EXISTS "Admins can update vouchers" ON public.store_vouchers;
CREATE POLICY "Admins can update vouchers" ON public.store_vouchers FOR UPDATE TO authenticated
USING ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
WITH CHECK ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

ALTER TABLE public.store_orders
  ADD COLUMN IF NOT EXISTS voucher_code text;

CREATE OR REPLACE FUNCTION public.validate_voucher(p_code text, p_subtotal integer)
RETURNS TABLE (code text, discount integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  voucher public.store_vouchers%ROWTYPE;
BEGIN
  SELECT * INTO voucher
  FROM public.store_vouchers
  WHERE upper(code) = upper(trim(p_code))
    AND active = true
    AND (expires_at IS NULL OR expires_at > now())
    AND (max_uses IS NULL OR uses_count < max_uses)
    AND p_subtotal >= minimum_subtotal;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  RETURN QUERY SELECT voucher.code,
    LEAST(GREATEST(p_subtotal, 0), CASE
      WHEN voucher.discount_type = 'percentage' THEN floor(p_subtotal * voucher.discount_value / 100.0)::integer
      ELSE voucher.discount_value
    END);
END;
$$;

GRANT EXECUTE ON FUNCTION public.validate_voucher(text, integer) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.apply_order_voucher_and_points()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  voucher public.store_vouchers%ROWTYPE;
  voucher_discount integer := 0;
BEGIN
  IF NEW.voucher_code IS NOT NULL AND length(trim(NEW.voucher_code)) > 0 THEN
    SELECT * INTO voucher
    FROM public.store_vouchers
    WHERE upper(code) = upper(trim(NEW.voucher_code))
    FOR UPDATE;

    IF NOT FOUND
      OR voucher.active = false
      OR (voucher.expires_at IS NOT NULL AND voucher.expires_at <= now())
      OR (voucher.max_uses IS NOT NULL AND voucher.uses_count >= voucher.max_uses)
      OR NEW.subtotal < voucher.minimum_subtotal THEN
      RAISE EXCEPTION 'Invalid voucher';
    END IF;

    voucher_discount := LEAST(GREATEST(NEW.subtotal, 0), CASE
      WHEN voucher.discount_type = 'percentage' THEN floor(NEW.subtotal * voucher.discount_value / 100.0)::integer
      ELSE voucher.discount_value
    END);
    UPDATE public.store_vouchers SET uses_count = uses_count + 1 WHERE id = voucher.id;
    NEW.voucher_code := upper(trim(NEW.voucher_code));
  ELSE
    NEW.voucher_code := NULL;
  END IF;

  NEW.discount := voucher_discount;
  NEW.total := GREATEST(0, NEW.subtotal + NEW.shipping - NEW.discount);
  NEW.points_earned := CASE WHEN NEW.user_id IS NULL THEN 0 ELSE GREATEST(NEW.total, 0) / 10000 END;

  IF NEW.user_id IS NOT NULL AND NEW.points_earned > 0 THEN
    UPDATE public.customer_profiles
    SET points = points + NEW.points_earned, updated_at = now()
    WHERE user_id = NEW.user_id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS award_customer_order_points_on_insert ON public.store_orders;
DROP TRIGGER IF EXISTS apply_order_voucher_and_points_on_insert ON public.store_orders;
CREATE TRIGGER apply_order_voucher_and_points_on_insert
BEFORE INSERT ON public.store_orders
FOR EACH ROW
EXECUTE FUNCTION public.apply_order_voucher_and_points();

REVOKE EXECUTE ON FUNCTION public.apply_order_voucher_and_points() FROM PUBLIC, anon, authenticated;