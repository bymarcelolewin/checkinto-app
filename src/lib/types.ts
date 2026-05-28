// Database Types
export interface Community {
	id: string;
	name: string;
	description: string;
	learn_more_link: string | null;
	banner: string | null;
	profilename: string;
	favicon: string | null;
	raffle_winners_to_display: number;
	donation_link: string | null;
	donation_message: string | null;
	created_at: string;
	updated_at: string;
}

export interface Venue {
	id: string;
	name: string;
	description: string;
	learn_more_link: string | null;
	wifi_access: string | null;
	restroom_details: string | null;
	food_details: string | null;
	community_id: string;
	created_at: string;
	updated_at: string;
}

export interface Talent {
	id: string;
	first_name: string;
	last_name: string;
	email: string;
	learn_more_link: string | null;
	bio: string | null;
	profile_photo: string | null;
	community_id: string;
	created_at: string;
	updated_at: string;
}

export interface Event {
	id: string;
	url_id: string;
	title: string;
	welcome_message: string;
	checkedin_message: string | null;
	about_presentation: string | null;
	about_workshop: string | null;
	presenter_id: string;
	community_id: string;
	venue_id: string;
	workshop_lead_id: string;
	community_host_id: string;
	active: boolean;
	show_event_details: boolean;
	created_at: string;
	updated_at: string;
	// Related data (populated via JOIN queries)
	community?: Community;
	venue?: Venue;
	presenter?: Talent;
	workshop_lead?: Talent;
	community_host?: Talent;
}

// Type alias for component compatibility
export type MeetupEvent = Event;
export type CommunityEvent = Event;

// Raffle Winner Types
export interface RaffleWinner {
	attendee_id: string;
	first_name: string;
	last_name: string;
	email: string;
	raffle_round: number;
}

export interface RaffleAnnouncementData {
	winners: RaffleWinner[];
	total_winners_to_display: number;
	event_id: string;
}

export interface Attendee {
	id: string;
	first_name: string;
	last_name: string;
	email: string;
	created_at: string;
	updated_at: string;
}

export interface EventAttendee {
	event_id: string;
	attendee_id: string;
	interesting_fact: string;
	raffle_winner: boolean;
	raffle_round: number | null;
	created_at: string;
}

// Poll Types (v1.6.0-event-voting)
// Direct DB rows are never read by the frontend — all access goes through the
// get_polls_for_event() RPC, which returns the hydrated Poll shape below.
// PollWinnerLabel is included for completeness / admin tooling.

export interface PollItem {
	id: string;
	name: string;
	display_order: number;
}

export interface PollResult {
	poll_item_id: string;
	name: string;
	vote_count: number;
	rank: number;
	is_my_vote: boolean;
}

export interface PollWinnerLabel {
	poll_id: string;
	rank: number;
	label: string;
}

export interface Poll {
	id: string;
	title: string;
	status: 'open' | 'closed';
	top_n_winners: number;
	show_vote_count: boolean;
	thanks_message: string;
	closed_message: string;
	no_votes_message: string;
	display_order: number;
	items: PollItem[];
	my_vote_item_id: string | null;
	// rank (as string key) → custom label, e.g. { "1": "Grand Prize", "4": "Honorable Mention" }
	winner_labels: Record<string, string>;
	// null when status === 'open'; populated when status === 'closed'
	results: PollResult[] | null;
}

export interface SubmitVoteResponse {
	success: boolean;
	poll_item_id?: string;
	// Server-side error codes: 'poll_unavailable' | 'invalid_item' | 'not_checked_in'
	// plus the client-side fallback 'unexpected_error'.
	error?: string;
}

// Form Types
export interface CheckInFormData {
	first_name: string;
	last_name: string;
	email: string;
	interesting_fact: string;
}

// API Response Types
export interface CheckInResponse {
	success: boolean;
	attendee?: Attendee;
	attendee_id?: string;
	error?: string;
	isExistingAttendee?: boolean;
}

// Database Input Types (for creating records)
export type CommunityInput = Omit<Community, 'id' | 'created_at' | 'updated_at'>;
export type GroupInput = CommunityInput; // Legacy alias
export type MeetupInput = CommunityInput; // Legacy alias
export type VenueInput = Omit<Venue, 'id' | 'created_at' | 'updated_at'>;
export type TalentInput = Omit<Talent, 'id' | 'created_at' | 'updated_at'>;
export type EventInput = Omit<Event, 'id' | 'created_at' | 'updated_at' | 'community' | 'venue' | 'presenter'>;
export type AttendeeInput = Omit<Attendee, 'id' | 'created_at' | 'updated_at'> & {
	interesting_fact: string;
};
export type EventAttendeeInput = Omit<EventAttendee, 'created_at' | 'raffle_winner' | 'raffle_round'>;

// Update Types (for updating records)
export type CommunityUpdate = Partial<Omit<Community, 'id' | 'created_at' | 'updated_at'>>;
export type GroupUpdate = CommunityUpdate; // Legacy alias  
export type MeetupUpdate = CommunityUpdate; // Legacy alias
export type VenueUpdate = Partial<Omit<Venue, 'id' | 'created_at' | 'updated_at'>>;
export type TalentUpdate = Partial<Omit<Talent, 'id' | 'created_at' | 'updated_at'>>;
export type EventUpdate = Partial<Omit<Event, 'id' | 'created_at' | 'updated_at' | 'community' | 'venue' | 'presenter'>>;
export type AttendeeUpdate = Partial<Omit<Attendee, 'id' | 'created_at' | 'updated_at'>>;

// Form Validation Types
export interface FormErrors {
	first_name?: string;
	last_name?: string;
	email?: string;
	interesting_fact?: string;
	general?: string;
}

// Application State Types
export interface AppState {
	currentEvent: Event | null;
	loading: boolean;
	error: string | null;
}

// Page Data Types
export interface EventPageData {
	event: Event;
}

// Component Props Types
export interface WelcomeScreenProps {
	event: Event;
	onCheckIn: () => void;
}

export interface CheckInFormProps {
	event: Event;
	onSubmit: (data: CheckInFormData) => Promise<void>;
	onBack: () => void;
	loading?: boolean;
	errors?: FormErrors;
}

export interface ConfirmationScreenProps {
	event: Event;
	attendee: Attendee;
}

// Persistent State Types
export interface ConfirmationState {
	isConfirmed: boolean;
	timestamp: number;
	eventId: string;
}

// Utility Types
export type LoadingState = 'idle' | 'loading' | 'success' | 'error';

// Constants
export const VALIDATION_RULES = {
	FIRST_NAME_MAX_LENGTH: 50,
	LAST_NAME_MAX_LENGTH: 50,
	EMAIL_MAX_LENGTH: 254,
	INTERESTING_FACT_MAX_LENGTH: 255
} as const;

// Type Guards
export function isCommunity(obj: unknown): obj is Community {
	return (
		typeof obj === 'object' &&
		obj !== null &&
		typeof (obj as Community).id === 'string' &&
		typeof (obj as Community).name === 'string' &&
		typeof (obj as Community).description === 'string'
	);
}

// Legacy aliases for backward compatibility
export const isGroup = isCommunity;
export const isMeetup = isCommunity;

export function isVenue(obj: unknown): obj is Venue {
	return (
		typeof obj === 'object' &&
		obj !== null &&
		typeof (obj as Venue).id === 'string' &&
		typeof (obj as Venue).name === 'string' &&
		typeof (obj as Venue).description === 'string'
	);
}

export function isTalent(obj: unknown): obj is Talent {
	return (
		typeof obj === 'object' &&
		obj !== null &&
		typeof (obj as Talent).id === 'string' &&
		typeof (obj as Talent).first_name === 'string' &&
		typeof (obj as Talent).last_name === 'string' &&
		typeof (obj as Talent).email === 'string'
	);
}

export function isEvent(obj: unknown): obj is Event {
	return (
		typeof obj === 'object' &&
		obj !== null &&
		typeof (obj as Event).id === 'string' &&
		typeof (obj as Event).url_id === 'string' &&
		typeof (obj as Event).title === 'string' &&
		typeof (obj as Event).welcome_message === 'string' &&
		typeof (obj as Event).presenter_id === 'string' &&
		typeof (obj as Event).community_id === 'string' &&
		typeof (obj as Event).venue_id === 'string' &&
		typeof (obj as Event).active === 'boolean' &&
		typeof (obj as Event).show_event_details === 'boolean'
	);
}

export function isAttendee(obj: unknown): obj is Attendee {
	return (
		typeof obj === 'object' &&
		obj !== null &&
		typeof (obj as Attendee).id === 'string' &&
		typeof (obj as Attendee).first_name === 'string' &&
		typeof (obj as Attendee).last_name === 'string' &&
		typeof (obj as Attendee).email === 'string'
	);
}

export function isPoll(obj: unknown): obj is Poll {
	return (
		typeof obj === 'object' &&
		obj !== null &&
		typeof (obj as Poll).id === 'string' &&
		typeof (obj as Poll).title === 'string' &&
		((obj as Poll).status === 'open' || (obj as Poll).status === 'closed') &&
		typeof (obj as Poll).top_n_winners === 'number' &&
		Array.isArray((obj as Poll).items)
	);
}

export function isCheckInFormData(obj: unknown): obj is CheckInFormData {
	return (
		typeof obj === 'object' &&
		obj !== null &&
		typeof (obj as CheckInFormData).first_name === 'string' &&
		typeof (obj as CheckInFormData).last_name === 'string' &&
		typeof (obj as CheckInFormData).email === 'string' &&
		typeof (obj as CheckInFormData).interesting_fact === 'string'
	);
}