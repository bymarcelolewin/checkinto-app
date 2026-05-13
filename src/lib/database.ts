import { createClient } from '@supabase/supabase-js';
import { env } from './env.js';
import type {
	Event,
	AttendeeInput,
	CheckInResponse,
	CheckInFormData,
	FormErrors
} from './types.js';
import { VALIDATION_RULES } from './types.js';

// Initialize Supabase client
export const supabase = createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY);

// Database service functions
export class DatabaseService {
	/**
	 * Get event by URL ID and community profile name with related data
	 */
	static async getEventByUrlIdAndProfile(urlId: string, profileName: string): Promise<Event | null> {
		try {
			// First, get the basic event data including show_event_details flag
			const { data: eventData, error: eventError } = await supabase
				.from('event')
				.select(`
					*,
					community:community_id!inner (profilename, name, banner, donation_link, donation_message)
				`)
				.eq('url_id', urlId)
				.eq('active', true)
				.eq('community.profilename', profileName)
				.single();

			if (eventError) {
				if (eventError.code === 'PGRST116') {
					console.warn(`Event not found or inactive: ${urlId} for community: ${profileName}`);
				} else if (eventError.message?.includes('foreign key')) {
					console.error(`Foreign key constraint issue for event: ${urlId}`, eventError);
				} else {
					console.error('Error fetching event:', eventError);
				}
				return null;
			}

			// If show_event_details is false, return with basic community info (for banner display)
			if (!eventData.show_event_details) {
				return eventData as Event;
			}

			// If show_event_details is true, fetch the full event with all related data
			const { data, error } = await supabase
				.from('event')
				.select(`
					*,
					community:community_id!inner (*),
					venue:venue_id (*),
					presenter:presenter_id (*),
					workshop_lead:workshop_lead_id (*),
					community_host:community_host_id (*)
				`)
				.eq('url_id', urlId)
				.eq('active', true)
				.eq('community.profilename', profileName)
				.single();

			if (error) {
				console.error('Error fetching event with details:', error);
				return null;
			}

			return data as Event;
		} catch (err) {
			console.error('Unexpected error fetching event:', err);
			return null;
		}
	}

	/**
	 * Get event by URL ID with related data (legacy method - use getEventByUrlIdAndProfile instead)
	 */
	static async getEventByUrlId(urlId: string): Promise<Event | null> {
		try {
			const { data: eventData, error: eventError } = await supabase
				.from('event')
				.select(`
					*,
					community:community_id (name, banner, donation_link, donation_message)
				`)
				.eq('url_id', urlId)
				.eq('active', true)
				.single();

			if (eventError) {
				if (eventError.code === 'PGRST116') {
					console.warn(`Event not found or inactive: ${urlId}`);
				} else if (eventError.message?.includes('foreign key')) {
					console.error(`Foreign key constraint issue for event: ${urlId}`, eventError);
				} else {
					console.error('Error fetching event:', eventError);
				}
				return null;
			}

			if (!eventData.show_event_details) {
				return eventData as Event;
			}

			const { data, error } = await supabase
				.from('event')
				.select(`
					*,
					community:community_id (*),
					venue:venue_id (*),
					presenter:presenter_id (*),
					workshop_lead:workshop_lead_id (*),
					community_host:community_host_id (*)
				`)
				.eq('url_id', urlId)
				.eq('active', true)
				.single();

			if (error) {
				console.error('Error fetching event with details:', error);
				return null;
			}

			if (!data.community || !data.venue || !data.presenter || !data.workshop_lead || !data.community_host) {
				console.error(`Event ${urlId} is missing required relationships:`, {
					hasCommunity: !!data.community,
					hasVenue: !!data.venue,
					hasPresenter: !!data.presenter,
					hasWorkshopLead: !!data.workshop_lead,
					hasCommunityHost: !!data.community_host
				});
				return null;
			}

			return data;
		} catch (err) {
			console.error('Unexpected error in getEventByUrlId:', err);
			return null;
		}
	}

	/**
	 * Complete check-in via the check_in_attendee SECURITY DEFINER function.
	 * The function handles attendee upsert, community_attendee link, and
	 * event_attendee insert atomically. See database/functions/check-in-attendee.sql.
	 */
	static async checkInAttendee(
		eventId: string,
		attendeeData: AttendeeInput
	): Promise<CheckInResponse> {
		try {
			const { data, error } = await supabase.rpc('check_in_attendee', {
				p_email: attendeeData.email,
				p_first_name: attendeeData.first_name,
				p_last_name: attendeeData.last_name,
				p_interesting_fact: attendeeData.interesting_fact,
				p_event_id: eventId
			});

			if (error) {
				console.error('Error calling check_in_attendee:', error);
				return {
					success: false,
					error: 'An unexpected error occurred during check-in'
				};
			}

			if (!data?.success) {
				return {
					success: false,
					error: data?.error ?? 'Check-in failed'
				};
			}

			return {
				success: true,
				isExistingAttendee: !!data.already_checked_in
			};
		} catch (err) {
			console.error('Error in checkInAttendee:', err);
			return {
				success: false,
				error: 'An unexpected error occurred during check-in'
			};
		}
	}

	/**
	 * Validate check-in form data
	 */
	static validateCheckInForm(formData: CheckInFormData): FormErrors {
		const errors: FormErrors = {};

		if (!formData.first_name.trim()) {
			errors.first_name = 'First name is required';
		} else if (formData.first_name.length > VALIDATION_RULES.FIRST_NAME_MAX_LENGTH) {
			errors.first_name = `First name must be ${VALIDATION_RULES.FIRST_NAME_MAX_LENGTH} characters or less`;
		}

		if (!formData.last_name.trim()) {
			errors.last_name = 'Last name is required';
		} else if (formData.last_name.length > VALIDATION_RULES.LAST_NAME_MAX_LENGTH) {
			errors.last_name = `Last name must be ${VALIDATION_RULES.LAST_NAME_MAX_LENGTH} characters or less`;
		}

		if (!formData.email.trim()) {
			errors.email = 'Email is required';
		} else if (formData.email.length > VALIDATION_RULES.EMAIL_MAX_LENGTH) {
			errors.email = `Email must be ${VALIDATION_RULES.EMAIL_MAX_LENGTH} characters or less`;
		} else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)) {
			errors.email = 'Please enter a valid email address';
		}

		if (!formData.interesting_fact.trim()) {
			errors.interesting_fact = 'Interesting fact is required';
		} else if (formData.interesting_fact.length > VALIDATION_RULES.INTERESTING_FACT_MAX_LENGTH) {
			errors.interesting_fact = `Interesting fact must be ${VALIDATION_RULES.INTERESTING_FACT_MAX_LENGTH} characters or less`;
		}

		return errors;
	}

	/**
	 * Test database connection
	 */
	static async testConnection(): Promise<boolean> {
		try {
			const { error } = await supabase
				.from('event')
				.select('count')
				.limit(1);

			return !error;
		} catch (err) {
			console.error('Database connection test failed:', err);
			return false;
		}
	}
}
