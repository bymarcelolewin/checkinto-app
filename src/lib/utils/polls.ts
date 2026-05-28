// Poll utilities — F140
// Auto-popup-on-load logic + localStorage tracking of "seen" poll ids so
// dismissing an auto-popup doesn't make it re-pop on every refresh.

import type { Poll } from '$lib/types';

const SEEN_KEY_PREFIX = 'polls-seen';

function seenKey(eventId: string): string {
	return `${SEEN_KEY_PREFIX}-${eventId}`;
}

function isStorageAvailable(): boolean {
	try {
		if (typeof window === 'undefined') return false;
		const test = '__polls_storage_test__';
		window.localStorage.setItem(test, test);
		window.localStorage.removeItem(test);
		return true;
	} catch {
		return false;
	}
}

/**
 * Read the set of poll ids already seen (auto-popped) for an event.
 * Tolerates missing / corrupted localStorage by returning an empty set.
 */
export function getSeenPollIds(eventId: string): Set<string> {
	if (!isStorageAvailable()) return new Set();
	try {
		const raw = window.localStorage.getItem(seenKey(eventId));
		if (!raw) return new Set();
		const parsed = JSON.parse(raw);
		if (!Array.isArray(parsed)) return new Set();
		return new Set(parsed.filter((v): v is string => typeof v === 'string'));
	} catch {
		return new Set();
	}
}

/**
 * Mark a poll id as seen (auto-popped) for an event. No-op on storage error.
 */
export function markPollSeen(eventId: string, pollId: string): void {
	if (!isStorageAvailable()) return;
	try {
		const seen = getSeenPollIds(eventId);
		seen.add(pollId);
		window.localStorage.setItem(seenKey(eventId), JSON.stringify([...seen]));
	} catch {
		// best-effort; if it fails the poll will re-pop next load — acceptable
	}
}

/**
 * Pick the first poll the attendee should be auto-popped with on page load.
 * Returns null if there's nothing to pop (no open un-voted poll, or every
 * candidate has already been seen this session/event).
 */
export function pickAutoPopupPoll(polls: Poll[], eventId: string): Poll | null {
	const seen = getSeenPollIds(eventId);
	for (const p of polls) {
		if (p.status === 'open' && !p.my_vote_item_id && !seen.has(p.id)) {
			return p;
		}
	}
	return null;
}

/**
 * Clear all "seen" entries for an event. Used when the attendee clears their
 * check-in so a re-check-in starts the auto-popup flow fresh.
 */
export function clearSeenPollIds(eventId: string): void {
	if (!isStorageAvailable()) return;
	try {
		window.localStorage.removeItem(seenKey(eventId));
	} catch {
		// no-op
	}
}
