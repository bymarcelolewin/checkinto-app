/**
 * localStorage utilities for managing persistent confirmation state
 * Event-scoped storage to isolate states between different events
 */

export interface ConfirmationState {
	isConfirmed: boolean;
	timestamp: number;
	eventId: string;
	attendeeEmail?: string;
	// v1.6.0+: persisted so polls feature can identify the checked-in
	// attendee server-side. Optional because attendees who checked in
	// before v1.6.0 won't have it; they'll need to re-check-in to get it.
	attendeeId?: string;
}

const STORAGE_KEY_PREFIX = 'group-checkin';

/**
 * Generate storage key for a specific event
 */
export function getStorageKey(eventId: string): string {
	return `${STORAGE_KEY_PREFIX}-${eventId}-confirmation-state`;
}

/**
 * Check if localStorage is available
 */
export function isStorageAvailable(): boolean {
	try {
		if (typeof window === 'undefined') return false;
		
		const test = '__storage_test__';
		window.localStorage.setItem(test, test);
		window.localStorage.removeItem(test);
		return true;
	} catch {
		return false;
	}
}

/**
 * Store confirmation state for an event
 */
export function storeConfirmationState(
	eventId: string,
	attendeeEmail?: string,
	attendeeId?: string
): boolean {
	if (!isStorageAvailable()) return false;

	try {
		const state: ConfirmationState = {
			isConfirmed: true,
			timestamp: Date.now(),
			eventId,
			attendeeEmail,
			attendeeId
		};

		const key = getStorageKey(eventId);
		window.localStorage.setItem(key, JSON.stringify(state));
		return true;
	} catch (error) {
		console.warn('Failed to store confirmation state:', error);
		return false;
	}
}

/**
 * Retrieve confirmation state for an event
 */
export function getConfirmationState(eventId: string): ConfirmationState | null {
	if (!isStorageAvailable()) return null;

	try {
		const key = getStorageKey(eventId);
		const stored = window.localStorage.getItem(key);
		
		if (!stored) return null;

		const state = JSON.parse(stored) as ConfirmationState;
		
		// Validate the state structure
		if (
			typeof state.isConfirmed === 'boolean' &&
			typeof state.timestamp === 'number' &&
			typeof state.eventId === 'string' &&
			state.eventId === eventId
		) {
			return state;
		}

		// Invalid state structure, remove it
		clearConfirmationState(eventId);
		return null;
	} catch (error) {
		console.warn('Failed to retrieve confirmation state:', error);
		// Clear corrupted data
		clearConfirmationState(eventId);
		return null;
	}
}

/**
 * Clear confirmation state for a specific event
 */
export function clearConfirmationState(eventId: string): boolean {
	if (!isStorageAvailable()) return false;

	try {
		const key = getStorageKey(eventId);
		window.localStorage.removeItem(key);
		return true;
	} catch (error) {
		console.warn('Failed to clear confirmation state:', error);
		return false;
	}
}

/**
 * Check if confirmation state exists for an event
 */
export function hasConfirmationState(eventId: string): boolean {
	const state = getConfirmationState(eventId);
	return state !== null && state.isConfirmed === true;
}

/**
 * Clear all confirmation states (useful for debugging)
 */
export function clearAllConfirmationStates(): number {
	if (!isStorageAvailable()) return 0;

	try {
		let cleared = 0;
		const keys = Object.keys(window.localStorage);
		
		for (const key of keys) {
			if (key.startsWith(`${STORAGE_KEY_PREFIX}-`) && key.endsWith('-confirmation-state')) {
				window.localStorage.removeItem(key);
				cleared++;
			}
		}
		
		return cleared;
	} catch (error) {
		console.warn('Failed to clear all confirmation states:', error);
		return 0;
	}
}