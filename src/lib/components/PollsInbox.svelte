<script lang="ts">
	// PollsInbox — F138
	// The inbox card. Renders one row per poll with title, subtitle hint,
	// and a state-driven pill (red Vote / green Voted / amber Results).
	// Tapping any row invokes onSelect(pollId); the parent owns popup state.

	import type { Poll } from '$lib/types';

	interface Props {
		polls: Poll[];
		onSelect: (pollId: string) => void;
	}

	let { polls, onSelect }: Props = $props();

	type PollUiState = 'unvoted' | 'voted' | 'closed';

	function pollState(p: Poll): PollUiState {
		if (p.status === 'closed') return 'closed';
		if (p.my_vote_item_id) return 'voted';
		return 'unvoted';
	}

	function subtitleFor(p: Poll): string {
		const s = pollState(p);
		if (s === 'unvoted') {
			const count = p.items.length;
			return count === 0
				? 'Tap to view'
				: `${count} option${count === 1 ? '' : 's'} — tap to vote`;
		}
		if (s === 'voted') return 'Tap to view or change your vote';
		return 'Tap to see the winners';
	}

	function pillLabelFor(p: Poll): string {
		const s = pollState(p);
		if (s === 'unvoted') return 'Vote';
		if (s === 'voted') return 'Voted';
		return 'Results';
	}

	function pillClassFor(p: Poll): string {
		const s = pollState(p);
		if (s === 'unvoted') return 'inbox-pill inbox-pill-vote';
		if (s === 'voted') return 'inbox-pill inbox-pill-voted';
		return 'inbox-pill inbox-pill-closed';
	}
</script>

{#if polls.length > 0}
	<section class="polls-inbox" aria-label="Polls">
		<h3 class="inbox-title">Polls</h3>
		<div class="inbox-list">
			{#each polls as p (p.id)}
				<button
					type="button"
					class="inbox-row"
					onclick={() => onSelect(p.id)}
					aria-label="{p.title} — {pillLabelFor(p)}"
				>
					<div class="inbox-row-text">
						<div class="inbox-row-title">{p.title}</div>
						<div class="inbox-row-sub">{subtitleFor(p)}</div>
					</div>
					<div class="inbox-row-cta">
						<span class={pillClassFor(p)}>{pillLabelFor(p)}</span>
						<span class="inbox-chevron" aria-hidden="true">›</span>
					</div>
				</button>
			{/each}
		</div>
	</section>
{/if}

<style>
	.polls-inbox {
		background: var(--color-content-bg);
		border-radius: 1rem;
		padding: 1.25rem;
		box-shadow: 0 4px 8px var(--shadow-light);
	}

	.inbox-title {
		margin: 0 0 0.75rem;
		font-size: 1.125rem;
		font-weight: 700;
		color: var(--color-text-primary);
	}

	.inbox-list {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.inbox-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		width: 100%;
		min-height: 44px;
		padding: 0.75rem 0.875rem;
		background: var(--color-bg-white);
		border: 1px solid var(--color-input-border);
		border-radius: 0.625rem;
		text-align: left;
		cursor: pointer;
		font-family: inherit;
		transition: box-shadow 0.1s ease, transform 0.05s ease;
	}

	.inbox-row:hover {
		box-shadow: 0 2px 6px var(--shadow-light);
	}

	.inbox-row:active {
		transform: scale(0.99);
	}

	.inbox-row-text {
		flex: 1;
		min-width: 0;
	}

	.inbox-row-title {
		font-weight: 700;
		color: var(--color-text-primary);
		font-size: 0.9375rem;
		line-height: 1.3;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.inbox-row-sub {
		font-size: 0.75rem;
		color: var(--color-text-muted);
		margin-top: 0.125rem;
	}

	.inbox-row-cta {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		flex-shrink: 0;
		margin-left: 0.75rem;
	}

	.inbox-pill {
		font-size: 0.6875rem;
		font-weight: 700;
		padding: 0.25rem 0.625rem;
		border-radius: 0.75rem;
		text-transform: uppercase;
		letter-spacing: 0.03em;
	}

	.inbox-pill-vote {
		background: #dc2626;
		color: #fff;
	}

	.inbox-pill-voted {
		background: #d1fae5;
		color: #065f46;
	}

	.inbox-pill-closed {
		background: #fef3c7;
		color: #92400e;
	}

	.inbox-chevron {
		color: var(--color-text-muted);
		font-size: 1.125rem;
		line-height: 1;
	}
</style>
