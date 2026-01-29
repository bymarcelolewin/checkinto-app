-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.attendee (
  first_name text NOT NULL,
  last_name text NOT NULL,
  email text NOT NULL UNIQUE,
  interesting_fact text NOT NULL,
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  community_id uuid NOT NULL,
  CONSTRAINT attendee_pkey PRIMARY KEY (id),
  CONSTRAINT fk_attendee_community FOREIGN KEY (community_id) REFERENCES public.community(id)
);
CREATE TABLE public.community (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  name text NOT NULL,
  description text NOT NULL,
  learn_more_link text,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  banner text NOT NULL CHECK (banner IS NULL OR length(banner) > 0 AND length(banner) <= 255),
  raffle_winners_to_display integer NOT NULL DEFAULT 1 CHECK (raffle_winners_to_display > 0),
  profilename text NOT NULL UNIQUE,
  favicon text NOT NULL CHECK (favicon IS NULL OR length(favicon) > 0 AND length(favicon) <= 255),
  donation_link text,
  donation_message text,
  CONSTRAINT community_pkey PRIMARY KEY (id)
);
CREATE TABLE public.event (
  show_event_details boolean NOT NULL DEFAULT true,
  url_id text NOT NULL,
  title text NOT NULL,
  welcome_message text NOT NULL,
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  community_id uuid NOT NULL,
  about_presentation text,
  community_host_id uuid NOT NULL,
  venue_id uuid NOT NULL,
  presenter_id uuid NOT NULL,
  about_workshop text,
  workshop_lead_id uuid NOT NULL,
  CONSTRAINT event_pkey PRIMARY KEY (id),
  CONSTRAINT fk_event_community FOREIGN KEY (community_id) REFERENCES public.community(id),
  CONSTRAINT fk_event_community_host FOREIGN KEY (community_host_id) REFERENCES public.talent(id),
  CONSTRAINT fk_event_workshop_lead FOREIGN KEY (workshop_lead_id) REFERENCES public.talent(id),
  CONSTRAINT fk_event_presenter FOREIGN KEY (presenter_id) REFERENCES public.talent(id),
  CONSTRAINT fk_event_venue FOREIGN KEY (venue_id) REFERENCES public.venue(id)
);
CREATE TABLE public.event_attendee (
  event_id uuid NOT NULL,
  attendee_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  raffle_winner boolean NOT NULL DEFAULT false,
  raffle_round integer CHECK (raffle_round IS NULL OR raffle_round > 0),
  CONSTRAINT event_attendee_pkey PRIMARY KEY (event_id, attendee_id),
  CONSTRAINT event_attendee_attendee_id_fkey FOREIGN KEY (attendee_id) REFERENCES public.attendee(id),
  CONSTRAINT event_attendee_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.event(id)
);
CREATE TABLE public.talent (
  first_name text NOT NULL,
  last_name text NOT NULL,
  email text NOT NULL,
  learn_more_link text,
  profile_photo text CHECK (profile_photo IS NULL OR length(profile_photo) > 0 AND length(profile_photo) <= 255),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  bio text,
  community_id uuid NOT NULL,
  CONSTRAINT talent_pkey PRIMARY KEY (id),
  CONSTRAINT fk_talent_community FOREIGN KEY (community_id) REFERENCES public.community(id)
);
CREATE TABLE public.venue (
  name text NOT NULL,
  description text NOT NULL,
  learn_more_link text,
  wifi_access text,
  restroom_details text,
  food_details text,
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  community_id uuid NOT NULL,
  CONSTRAINT venue_pkey PRIMARY KEY (id),
  CONSTRAINT fk_venue_community FOREIGN KEY (community_id) REFERENCES public.community(id)
);