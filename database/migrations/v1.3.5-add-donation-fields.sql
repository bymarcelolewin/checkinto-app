-- Migration: v1.3.5-add-donation-fields
-- Description: Add donation_link and donation_message fields to community table
-- Date: 2026-01-28

-- Add donation_link field (optional URL to external donation platform)
ALTER TABLE public.community
ADD COLUMN IF NOT EXISTS donation_link text;

-- Add donation_message field (optional customizable message shown with donation box)
ALTER TABLE public.community
ADD COLUMN IF NOT EXISTS donation_message text;

-- Add comments for documentation
COMMENT ON COLUMN public.community.donation_link IS 'Optional URL to external donation platform (e.g., PayPal, Venmo, GoFundMe)';
COMMENT ON COLUMN public.community.donation_message IS 'Optional customizable message displayed above the Donate button. Supports \n for line breaks.';
