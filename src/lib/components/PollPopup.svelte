<script lang="ts">
	// PollPopup — F139
	// Modal that hosts the per-poll states (ballot / voted / closed-results /
	// no-votes / empty-items). Pure presentational + local UI state. The actual
	// vote submission is delegated to the parent via onVote so DB access stays
	// in the orchestrator (EventScreen).
	//
	// Close affordances: top-right X, click on dim overlay, Escape key.

	import { onMount, onDestroy } from 'svelte';
	import type { Poll } from '$lib/types';

	interface Props {
		poll: Poll;
		onClose: () => void;
		// Called when the user submits a vote. Should return the new poll item id
		// on success or throw / return null on failure. Parent should refetch
		// polls after success and re-render this component with the updated poll.
		onVote: (pollItemId: string) => Promise<{ success: boolean; error?: string }>;
	}

	let { poll, onClose, onVote }: Props = $props();

	let selectedItemId = $state<string | null>(poll.my_vote_item_id);
	let isChangingVote = $state(false); // when true, render ballot even if already voted
	let isSubmitting = $state(false);
	let submitError = $state<string | null>(null);

	// Derived view state
	let view = $derived.by(() => {
		if (poll.status === 'closed') {
			if (!poll.results || poll.results.length === 0) return 'closed-empty';
			return 'closed-results';
		}
		if (poll.items.length === 0) return 'empty-items';
		if (poll.my_vote_item_id && !isChangingVote) return 'voted';
		return 'ballot';
	});

	function ordinal(n: number): string {
		const s = ['th', 'st', 'nd', 'rd'];
		const v = n % 100;
		return n + (s[(v - 20) % 10] || s[v] || s[0]) + ' Place';
	}

	function labelForRank(rank: number): string {
		return poll.winner_labels[String(rank)] || ordinal(rank);
	}

	// True if more than one item shares this rank (tie suffix logic)
	function isTied(rank: number): boolean {
		if (!poll.results) return false;
		let count = 0;
		for (const r of poll.results) if (r.rank === rank) count++;
		return count > 1;
	}

	async function handleVote() {
		if (!selectedItemId || isSubmitting) return;
		isSubmitting = true;
		submitError = null;
		try {
			const result = await onVote(selectedItemId);
			if (!result.success) {
				submitError = errorMessageFor(result.error);
				return;
			}
			// Parent will refetch and re-render with my_vote_item_id set; we drop
			// out of changing-vote mode locally so the new render shows the
			// 'voted' view.
			isChangingVote = false;
		} catch (err) {
			console.error('PollPopup vote error:', err);
			submitError = errorMessageFor('unexpected_error');
		} finally {
			isSubmitting = false;
		}
	}

	function errorMessageFor(code?: string): string {
		switch (code) {
			case 'poll_unavailable':
				return 'This poll just closed. Your vote was not recorded.';
			case 'not_checked_in':
				return 'You need to be checked into the event to vote.';
			case 'invalid_item':
				return 'That option is no longer available.';
			default:
				return 'Something went wrong submitting your vote. Please try again.';
		}
	}

	function handleOverlayClick(e: MouseEvent) {
		// Only close if the click was on the overlay itself, not the popup-card
		if (e.target === e.currentTarget) onClose();
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') onClose();
	}

	onMount(() => {
		window.addEventListener('keydown', handleKeydown);
	});

	onDestroy(() => {
		window.removeEventListener('keydown', handleKeydown);
	});
</script>

<div
	class="popup-overlay"
	role="presentation"
	onclick={handleOverlayClick}
>
	<div
		class="popup-card"
		role="dialog"
		aria-modal="true"
		aria-labelledby="poll-popup-title"
	>
		<button
			type="button"
			class="popup-close"
			aria-label="Close"
			onclick={onClose}
		>
			×
		</button>

		<h2 id="poll-popup-title" class="popup-title">{poll.title}</h2>

		{#if view === 'empty-items'}
			<p class="popup-msg muted">Voting items coming soon.</p>

		{:else if view === 'ballot'}
			<div class="ballot-items">
				{#each poll.items as item (item.id)}
					<label class="ballot-item">
						<input
							type="radio"
							name="ballot-{poll.id}"
							value={item.id}
							checked={selectedItemId === item.id}
							onchange={() => (selectedItemId = item.id)}
							disabled={isSubmitting}
						/>
						<span class="ballot-item-name">{item.name}</span>
					</label>
				{/each}
			</div>
			{#if submitError}
				<p class="popup-error">{submitError}</p>
			{/if}
			<button
				type="button"
				class="popup-vote-btn"
				disabled={!selectedItemId || isSubmitting}
				onclick={handleVote}
			>
				{isSubmitting ? 'Submitting…' : 'Vote'}
			</button>

		{:else if view === 'voted'}
			<p class="popup-msg">{poll.thanks_message}</p>
			<div class="popup-list">
				{#each poll.items as item (item.id)}
					<div class="result-row" class:your-pick={item.id === poll.my_vote_item_id}>
						<div class="result-name">
							{item.name}
							{#if item.id === poll.my_vote_item_id}
								<span class="your-pick-badge">Your pick</span>
							{/if}
						</div>
					</div>
				{/each}
			</div>
			<button
				type="button"
				class="popup-change-link"
				onclick={() => {
					isChangingVote = true;
					submitError = null;
				}}
			>
				Change your vote
			</button>

		{:else if view === 'closed-empty'}
			<p class="popup-msg muted">{poll.no_votes_message}</p>

		{:else if view === 'closed-results'}
			<div class="popup-list">
				{#each poll.results ?? [] as r (r.poll_item_id)}
					<div class="result-row" class:your-pick={r.is_my_vote}>
						<div class="result-rank">
							{labelForRank(r.rank)}{isTied(r.rank) ? ' — Tie' : ''}
						</div>
						<div class="result-name">
							{r.name}
							{#if r.is_my_vote}
								<span class="your-pick-badge">Your pick</span>
							{/if}
						</div>
						{#if poll.show_vote_count}
							<div class="result-count">{r.vote_count} {r.vote_count === 1 ? 'vote' : 'votes'}</div>
						{/if}
					</div>
				{/each}
			</div>
		{/if}
	</div>
</div>

<style>
	.popup-overlay {
		position: fixed;
		inset: 0;
		background: rgba(15, 23, 42, 0.55);
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 1.25rem;
		z-index: 1000;
	}

	.popup-card {
		background: var(--color-bg-white);
		border-radius: 1rem;
		width: 100%;
		max-width: 420px;
		max-height: 90vh;
		overflow-y: auto;
		padding: 1.5rem 1.25rem 1.25rem;
		position: relative;
		box-shadow: 0 20px 60px var(--shadow-text);
	}

	.popup-close {
		position: absolute;
		top: 0.5rem;
		right: 0.5rem;
		width: 36px;
		height: 36px;
		min-height: 36px;
		border-radius: 50%;
		background: var(--color-bg-alt);
		border: 1px solid var(--color-input-border);
		color: var(--color-text-secondary);
		font-size: 1.5rem;
		line-height: 1;
		cursor: pointer;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		z-index: 2;
	}

	.popup-close:hover {
		background: var(--color-button-hover-bg);
		color: var(--color-text-primary);
	}

	.popup-title {
		margin: 0 2.5rem 1rem 0;
		font-size: 1.125rem;
		font-weight: 800;
		color: var(--color-text-primary);
	}

	.popup-msg {
		margin: 0 0 1rem;
		font-size: 0.9375rem;
		color: var(--color-text-secondary);
	}

	.popup-msg.muted {
		color: var(--color-text-muted);
		text-align: center;
		padding: 1rem 0;
	}

	.popup-error {
		margin: 0.5rem 0;
		font-size: 0.875rem;
		color: #b91c1c;
	}

	.ballot-items {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		margin-bottom: 0.75rem;
	}

	.ballot-item {
		display: flex;
		align-items: center;
		gap: 0.625rem;
		padding: 0.625rem 0.75rem;
		border: 1px solid var(--color-input-border);
		border-radius: 0.5rem;
		background: var(--color-bg-alt);
		cursor: pointer;
		font-size: 0.875rem;
	}

	.ballot-item:hover {
		background: var(--color-button-hover-bg);
	}

	.ballot-item input {
		margin: 0;
	}

	.popup-vote-btn {
		width: 100%;
		background: var(--color-accent-dark);
		color: #fff;
		border: none;
		border-radius: 0.5rem;
		padding: 0.75rem 1rem;
		font-size: 0.9375rem;
		font-weight: 700;
		cursor: pointer;
		min-height: 44px;
	}

	.popup-vote-btn:hover:not(:disabled) {
		background: var(--color-accent);
	}

	.popup-vote-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.popup-list {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		margin-bottom: 0.75rem;
	}

	.result-row {
		padding: 0.625rem 0.75rem;
		border: 1px solid var(--color-input-border);
		border-radius: 0.5rem;
		background: var(--color-bg-alt);
		font-size: 0.875rem;
	}

	.result-row.your-pick {
		border: 2px solid var(--color-accent-dark);
		background: #ecfdf5;
	}

	.result-rank {
		font-size: 0.6875rem;
		font-weight: 800;
		color: var(--color-accent-dark);
		text-transform: uppercase;
		letter-spacing: 0.03em;
		margin-bottom: 0.125rem;
	}

	.result-name {
		font-weight: 700;
		color: var(--color-text-primary);
	}

	.your-pick-badge {
		display: inline-block;
		background: var(--color-accent-dark);
		color: #fff;
		font-size: 0.625rem;
		padding: 0.125rem 0.375rem;
		border-radius: 0.5rem;
		margin-left: 0.375rem;
		vertical-align: middle;
		text-transform: uppercase;
		letter-spacing: 0.03em;
		font-weight: 700;
	}

	.result-count {
		font-size: 0.75rem;
		color: var(--color-text-muted);
		margin-top: 0.25rem;
		font-variant-numeric: tabular-nums;
	}

	.popup-change-link {
		display: inline-block;
		background: none;
		border: none;
		color: var(--color-accent-dark);
		font-size: 0.8125rem;
		font-weight: 600;
		text-decoration: underline;
		cursor: pointer;
		padding: 0.25rem 0;
		min-height: 32px;
	}
</style>
