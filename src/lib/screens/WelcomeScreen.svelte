<script lang="ts">
	import { onMount } from 'svelte';
	import { Button } from '$lib/components';
	import { navigationActions, formActions } from '$lib/stores';
	import { getImagePath, IMAGE_CATEGORIES } from '$lib/utils/imagePaths';
	import type { Event } from '$lib/types';

	interface Props {
		event: Event | null;
		isLoading?: boolean;
		error?: string | null;
	}

	let { event, isLoading = false, error = null }: Props = $props();

	// Reset form when arriving at welcome screen
	onMount(() => {
		formActions.reset();
	});

	const handleCheckIn = () => {
		navigationActions.startCheckin();
	};

	// Helper function to convert newlines to <br> tags
	const formatLineBreaks = (text: string | null | undefined): string => {
		if (!text) return '';
		return text.replace(/\n/g, '<br />');
	};
</script>

<div class="welcome-screen">
	{#if isLoading}
		<div class="loading-state">
			<div class="loading-spinner"></div>
			<p>Loading event...</p>
		</div>
	{:else if error}
		<div class="error-state">
			<h1>Event Not Available</h1>
			<p>{error}</p>
		</div>
	{:else if event}
		<div class="welcome-content">
			<header class="welcome-header">
				{#if event.community?.banner}
					<div class="logo-container">
						<img src={getImagePath(event.community.banner, IMAGE_CATEGORIES.COMMUNITY, event.community.profilename)} alt={event.community.name} class="community-banner" />
					</div>
				{/if}
				<h1 class="event-title">{@html formatLineBreaks(event.title)}</h1>
			</header>

			<main class="welcome-main">
				<div class="welcome-message">
					<p>{@html formatLineBreaks(event.welcome_message)}</p>
				</div>

				<div class="check-in-action">
					<Button
						variant="primary"
						size="large"
						onclick={handleCheckIn}
					>
						Check In
					</Button>
				</div>
			</main>
		</div>
	{:else}
		<div class="error-state">
			<h1>Event Not Found</h1>
			<p>This event can't be found or is no longer active.</p>
		</div>
	{/if}
</div>

<style>
	.welcome-screen {
		min-height: 100vh;
		display: flex;
		flex-direction: column;
		justify-content: flex-start;
		align-items: center;
		padding: 15px;
		background: linear-gradient(135deg, var(--color-primary-gradient-start) 0%, var(--color-primary-gradient-end) 100%);
		color: white;
		text-align: center;
		box-sizing: border-box;
	}

	.welcome-content {
		width: 100%;
		max-width: 500px;
		margin: 0 auto;
	}

	.welcome-header {
		margin-bottom: 2rem;
	}

	.logo-container {
		display: flex;
		justify-content: center;
		margin-bottom: 1.5rem;
	}

	.community-banner {
		width: 100%;
		height: auto;
		border-radius: 10px;
		box-shadow: 0 4px 12px var(--shadow-base);
	}

	.event-title {
		font-size: 2rem;
		font-weight: bold;
		margin: 0;
		line-height: 1.2;
		text-shadow: 0 2px 4px var(--shadow-text);
	}

	@media (min-width: 640px) {
		.event-title {
			font-size: 2.5rem;
		}
	}

	.welcome-main {
		display: flex;
		flex-direction: column;
		gap: 2.5rem;
	}

	.welcome-message {
		font-size: 1.125rem;
		line-height: 1.6;
		opacity: 0.95;
	}

	.welcome-message p {
		margin: 0;
	}

	.check-in-action {
		display: flex;
		justify-content: center;
	}

	/* Loading and error states */
	.loading-state,
	.error-state {
		text-align: center;
		max-width: 400px;
	}

	.loading-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 1rem;
	}

	.loading-spinner {
		width: 2rem;
		height: 2rem;
		border: 3px solid var(--overlay-white-border);
		border-top: 3px solid white;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.error-state h1 {
		font-size: 1.5rem;
		margin: 0 0 1rem 0;
		color: var(--color-error-text);
	}

	.error-state p {
		margin: 0;
		opacity: 0.9;
	}
</style>