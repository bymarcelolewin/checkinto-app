import { writable } from 'svelte/store';
import { 
	storeConfirmationState, 
	getConfirmationState, 
	clearConfirmationState, 
	hasConfirmationState 
} from '$lib/utils/storage';
import { validateAndCleanupConfirmationState, canPersistConfirmationState } from '$lib/utils/state-validation';
import type { Event } from '$lib/types';

export type Screen = 'event' | 'checkin';

export interface NavigationState {
	currentScreen: Screen;
	eventId: string;
	isLoading: boolean;
	error: string | null;
}

const initialState: NavigationState = {
	currentScreen: 'event',
	eventId: '',
	isLoading: false,
	error: null
};

export const navigationStore = writable<NavigationState>(initialState);

// Navigation actions
export const navigationActions = {
	// Set the event ID - always start at event screen (checked-in state handled by component)
	setEvent: (eventId: string, event?: Event | null) => {
		// Validate and cleanup any existing confirmation state
		validateAndCleanupConfirmationState(eventId, event || null);

		// Always navigate to event screen - the component will handle checked-in state display
		navigationStore.update(state => ({
			...state,
			eventId,
			currentScreen: 'event',
			error: null,
			isLoading: false
		}));
	},

	// Navigate to a specific screen
	goToScreen: (screen: Screen) => {
		navigationStore.update(state => ({
			...state,
			currentScreen: screen,
			error: null,
			isLoading: false
		}));
	},

	// Navigate to check-in form
	startCheckin: () => {
		navigationStore.update(state => ({
			...state,
			currentScreen: 'checkin',
			error: null
		}));
	},

	// Complete check-in and return to event screen with confirmed state
	completeCheckin: (event?: Event | null, attendeeEmail?: string) => {
		navigationStore.update(state => {
			// Store confirmation state if persistence is allowed
			if (event && canPersistConfirmationState(event)) {
				storeConfirmationState(state.eventId, attendeeEmail);
			}

			return {
				...state,
				currentScreen: 'event',
				error: null
			};
		});
	},

	// Set loading state
	setLoading: (isLoading: boolean) => {
		navigationStore.update(state => ({
			...state,
			isLoading
		}));
	},

	// Set error state
	setError: (error: string | null) => {
		navigationStore.update(state => ({
			...state,
			error,
			isLoading: false
		}));
	},

	// Reset to initial state and clear persistent confirmation
	reset: () => {
		navigationStore.update(state => {
			// Clear any stored confirmation state for this event
			if (state.eventId) {
				clearConfirmationState(state.eventId);
			}
			return initialState;
		});
	},

	// Check if confirmation state exists for current event
	hasStoredConfirmation: (eventId: string): boolean => {
		return hasConfirmationState(eventId);
	},

	// Clear stored confirmation state for specific event
	clearStoredConfirmation: (eventId: string) => {
		clearConfirmationState(eventId);
	},

	// Validate stored confirmation state for an event
	validateStoredConfirmation: (eventId: string, event: Event | null) => {
		return validateAndCleanupConfirmationState(eventId, event);
	}
};