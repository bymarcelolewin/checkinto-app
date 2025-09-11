import { createClient } from '@supabase/supabase-js';
import { env } from './env.js';
import type {
	Event,
	Attendee,
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
					community:community_id!inner (profilename, name, banner)
				`)
				.eq('url_id', urlId)
				.eq('active', true)
				.eq('community.profilename', profileName)
				.single();

			if (eventError) {
				// Handle specific error cases
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
			// First, get the basic event data including show_event_details flag
			const { data: eventData, error: eventError } = await supabase
				.from('event')
				.select(`
					*,
					community:community_id (name, banner)
				`)
				.eq('url_id', urlId)
				.eq('active', true)
				.single();

			if (eventError) {
				// Handle specific error cases
				if (eventError.code === 'PGRST116') {
					console.warn(`Event not found or inactive: ${urlId}`);
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

			// Validate that required relationships exist when details are enabled
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
	 * Create new attendee (no upsert - security improvement)
	 */
	static async createAttendee(attendeeData: AttendeeInput): Promise<Attendee | null> {
		const { data, error } = await supabase
			.from('attendee')
			.insert(attendeeData)
			.select()
			.single();

		if (error) {
			console.error('Error creating attendee:', error);
			return null;
		}

		return data;
	}

	/**
	 * Create or update attendee (upsert) - DEPRECATED: Use createAttendee for security
	 */
	static async upsertAttendee(attendeeData: AttendeeInput): Promise<Attendee | null> {
		const { data, error } = await supabase
			.from('attendee')
			.upsert(attendeeData, { 
				onConflict: 'email',
				ignoreDuplicates: false 
			})
			.select()
			.single();

		if (error) {
			console.error('Error upserting attendee:', error);
			return null;
		}

		return data;
	}

	/**
	 * Link attendee to event
	 */
	static async linkAttendeeToEvent(eventId: string, attendeeId: string): Promise<boolean> {
		const { error } = await supabase
			.from('event_attendee')
			.upsert({ 
				event_id: eventId, 
				attendee_id: attendeeId 
			}, {
				onConflict: 'event_id,attendee_id',
				ignoreDuplicates: true
			});

		if (error) {
			console.error('Error linking attendee to event:', error);
			return false;
		}

		return true;
	}

	/**
	 * Get event by ID (simple fetch for community_id lookup)
	 */
	static async getEventById(eventId: string): Promise<Event | null> {
		try {
			const { data, error } = await supabase
				.from('event')
				.select('*')
				.eq('id', eventId)
				.single();

			if (error) {
				console.error('Error fetching event by ID:', error);
				return null;
			}

			return data as Event;
		} catch (err) {
			console.error('Unexpected error fetching event by ID:', err);
			return null;
		}
	}

	/**
	 * Complete check-in process (create or find attendee + link to event)
	 */
	static async checkInAttendee(
		eventId: string, 
		attendeeData: AttendeeInput
	): Promise<CheckInResponse> {
		try {
			// Get event to retrieve community_id
			const event = await this.getEventById(eventId);
			if (!event) {
				return {
					success: false,
					error: 'Event not found'
				};
			}

			// Check if attendee is already registered for this event
			const isAlreadyRegistered = await this.isEmailRegisteredForEvent(eventId, attendeeData.email);
			
			if (isAlreadyRegistered) {
				return {
					success: true,
					isExistingAttendee: true
				};
			}
			
			// Check if attendee already exists globally (by email)
			let attendee = await this.getAttendeeByEmail(attendeeData.email);
			let isExistingAttendee = !!attendee;
			
			if (!attendee) {
				// Add community_id to attendee data
				const attendeeDataWithCommunity = {
					...attendeeData,
					community_id: event.community_id
				};
				
				// Create new attendee
				attendee = await this.createAttendee(attendeeDataWithCommunity);
				
				if (!attendee) {
					return { 
						success: false, 
						error: 'Failed to save attendee information'
					};
				}
			} else {
				// Update existing attendee's information with new data
				attendee = await this.updateAttendee(attendee.id, {
					first_name: attendeeData.first_name,
					last_name: attendeeData.last_name,
					interesting_fact: attendeeData.interesting_fact
				});
				
				if (!attendee) {
					return { 
						success: false, 
						error: 'Failed to update attendee information'
					};
				}
			}

			// Link attendee to this event
			const linked = await this.linkAttendeeToEvent(eventId, attendee.id);
			
			if (!linked) {
				return { 
					success: false, 
					error: 'Failed to complete check-in process'
				};
			}
			
			return { 
				success: true, 
				attendee,
				isExistingAttendee
			};
		} catch (error) {
			console.error('Error in checkInAttendee:', error);
			return { 
				success: false, 
				error: 'An unexpected error occurred during check-in'
			};
		}
	}

	/**
	 * Get attendee by email address
	 */
	static async getAttendeeByEmail(email: string): Promise<Attendee | null> {
		try {
			const { data, error } = await supabase
				.from('attendee')
				.select('*')
				.eq('email', email)
				.single();

			if (error) {
				// If not found, that's expected behavior
				if (error.code === 'PGRST116') {
					return null;
				}
				console.error('Error fetching attendee by email:', error);
				return null;
			}

			return data as Attendee;
		} catch (err) {
			console.error('Unexpected error fetching attendee by email:', err);
			return null;
		}
	}

	/**
	 * Update existing attendee information
	 */
	static async updateAttendee(
		attendeeId: string, 
		updateData: Partial<AttendeeInput>
	): Promise<Attendee | null> {
		try {
			const { data, error } = await supabase
				.from('attendee')
				.update(updateData)
				.eq('id', attendeeId)
				.select()
				.single();

			if (error) {
				console.error('Error updating attendee:', error);
				return null;
			}

			return data as Attendee;
		} catch (err) {
			console.error('Unexpected error updating attendee:', err);
			return null;
		}
	}

	/**
	 * Validate check-in form data
	 */
	static validateCheckInForm(formData: CheckInFormData): FormErrors {
		const errors: FormErrors = {};

		// First name validation
		if (!formData.first_name.trim()) {
			errors.first_name = 'First name is required';
		} else if (formData.first_name.length > VALIDATION_RULES.FIRST_NAME_MAX_LENGTH) {
			errors.first_name = `First name must be ${VALIDATION_RULES.FIRST_NAME_MAX_LENGTH} characters or less`;
		}

		// Last name validation
		if (!formData.last_name.trim()) {
			errors.last_name = 'Last name is required';
		} else if (formData.last_name.length > VALIDATION_RULES.LAST_NAME_MAX_LENGTH) {
			errors.last_name = `Last name must be ${VALIDATION_RULES.LAST_NAME_MAX_LENGTH} characters or less`;
		}

		// Email validation
		if (!formData.email.trim()) {
			errors.email = 'Email is required';
		} else if (formData.email.length > VALIDATION_RULES.EMAIL_MAX_LENGTH) {
			errors.email = `Email must be ${VALIDATION_RULES.EMAIL_MAX_LENGTH} characters or less`;
		} else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)) {
			errors.email = 'Please enter a valid email address';
		}

		// Interesting fact validation
		if (!formData.interesting_fact.trim()) {
			errors.interesting_fact = 'Interesting fact is required';
		} else if (formData.interesting_fact.length > VALIDATION_RULES.INTERESTING_FACT_MAX_LENGTH) {
			errors.interesting_fact = `Interesting fact must be ${VALIDATION_RULES.INTERESTING_FACT_MAX_LENGTH} characters or less`;
		}

		return errors;
	}

	/**
	 * Check if email is already registered for this event
	 */
	static async isEmailRegisteredForEvent(eventId: string, email: string): Promise<boolean> {
		try {
			const { data, error } = await supabase
				.from('event_attendee')
				.select('attendee!inner(email)')
				.eq('event_id', eventId)
				.eq('attendee.email', email)
				.limit(1);

			if (error) {
				console.error('Error checking email registration:', error);
				return false; // Assume not registered on error to allow submission
			}

			return data && data.length > 0;
		} catch (err) {
			console.error('Error in email registration check:', err);
			return false; // Assume not registered on error to allow submission
		}
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