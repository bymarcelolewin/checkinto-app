<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { Button } from '$lib/components';
	import { navigationActions } from '$lib/stores';
	import { fetchRaffleWinners, getOrdinal, isWinner } from '$lib/utils/raffle';
	import { getConfirmationState, hasConfirmationState, clearConfirmationState } from '$lib/utils/storage';
	import { getImagePath, IMAGE_CATEGORIES } from '$lib/utils/imagePaths';
	import type { Event, RaffleWinner } from '$lib/types';

	interface Props {
		event: Event | null;
		isLoading?: boolean;
		error?: string | null;
	}

	let { event, isLoading = false, error = null }: Props = $props();

	// Check if user is already checked in (from localStorage)
	let isCheckedIn = $state(false);

	// Raffle state
	let raffleWinners = $state<RaffleWinner[]>([]);
	let currentUserEmail = $state<string>('');
	let pollingInterval: ReturnType<typeof setInterval> | null = null;

	const handleCheckIn = () => {
		navigationActions.startCheckin();
	};

	const handleClearStorage = () => {
		if (event?.url_id) {
			clearConfirmationState(event.url_id);
			isCheckedIn = false;
			currentUserEmail = '';
			raffleWinners = [];
			// Stop raffle polling
			if (pollingInterval) {
				clearInterval(pollingInterval);
				pollingInterval = null;
			}
		}
	};

	// Get current user's email from localStorage and check confirmation status
	onMount(() => {
		if (event?.url_id) {
			// Check if user is checked in
			isCheckedIn = hasConfirmationState(event.url_id);

			// Get the email from the stored confirmation state
			if (isCheckedIn) {
				const confirmationState = getConfirmationState(event.url_id);
				if (confirmationState?.attendeeEmail) {
					currentUserEmail = confirmationState.attendeeEmail;
				}

				// Start polling for raffle winners only if checked in
				if (event?.id) {
					startPollingForWinners();
				}
			}
		}
	});

	onDestroy(() => {
		// Clean up polling interval
		if (pollingInterval) {
			clearInterval(pollingInterval);
		}
	});

	// Poll for raffle winners every 5 seconds
	const startPollingForWinners = () => {
		// Initial check
		checkForWinners();

		// Set up polling interval
		pollingInterval = setInterval(() => {
			checkForWinners();
		}, 5000); // 5 seconds
	};

	// Check for raffle winners
	const checkForWinners = async () => {
		if (!event?.id) return;

		const winners = await fetchRaffleWinners(event.id);
		raffleWinners = winners;
	};

	// Check if current user is a winner
	const isCurrentUserWinner = (winner: RaffleWinner): boolean => {
		return isWinner(winner.email, currentUserEmail);
	};

	// Helper function to convert newlines to <br> tags
	const formatLineBreaks = (text: string | null | undefined): string => {
		if (!text) return '';
		return text.replace(/\n/g, '<br />');
	};
</script>

<div class="event-screen">
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
		<div class="event-content">
			{#if isCheckedIn && raffleWinners.length > 0}
				<div class="raffle-winner-announcement">
					<h2 class="raffle-title">
						<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M12 2L15.09 8.26L22 9.27L17 14.14L18.18 21.02L12 17.77L5.82 21.02L7 14.14L2 9.27L8.91 8.26L12 2Z"/>
						</svg>
						{raffleWinners.length === 1 ? 'Raffle Winner!' : 'Raffle Winners!'}
						<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M12 2L15.09 8.26L22 9.27L17 14.14L18.18 21.02L12 17.77L5.82 21.02L7 14.14L2 9.27L8.91 8.26L12 2Z"/>
						</svg>
					</h2>
					<div class="winners-list">
						{#each raffleWinners as winner, index}
							<div class="winner-item" class:is-you={isCurrentUserWinner(winner)}>
								<div class="winner-place">{getOrdinal(raffleWinners.length - index)} Place</div>
								<div class="winner-name">
									{winner.first_name} {winner.last_name}
								</div>
								{#if isCurrentUserWinner(winner)}
									<div class="winner-message">
										🎉 Hey! That's you! You won! 🎉
									</div>
								{/if}
							</div>
						{/each}
					</div>
				</div>
			{/if}

			<header class="event-header">
				{#if event.community?.banner}
					<div class="logo-container">
						<img src={getImagePath(event.community.banner, IMAGE_CATEGORIES.COMMUNITY, event.community.profilename)} alt={event.community.name} class="community-banner" />
					</div>
				{/if}

				{#if isCheckedIn}
					<h1 class="status-title checked-in">
						<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="status-icon">
							<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/>
							<polyline points="22,4 12,14.01 9,11.01"/>
						</svg>
						You're checked in!
					</h1>
				{/if}
			</header>

			<main class="event-main">
				{#if !isCheckedIn}
					<div class="welcome-box">
						{#if event.welcome_message}
							<div class="welcome-message">
								<p>{@html formatLineBreaks(event.welcome_message)}</p>
							</div>
						{/if}
						<div class="check-in-action">
							<Button
								variant="primary"
								size="medium"
								onclick={handleCheckIn}
							>
								Check In
							</Button>
						</div>
					</div>
				{/if}

				{#if event.community?.donation_link}
					<div class="donation-box">
						{#if event.community.donation_message}
							<div class="donation-message">
								<p>{@html formatLineBreaks(event.community.donation_message)}</p>
							</div>
						{/if}
						<div class="donation-action">
							<a
								href={event.community.donation_link}
								target="_blank"
								rel="noopener noreferrer"
								class="btn-base btn-primary btn-medium donate-button"
							>
								Donate
							</a>
						</div>
					</div>
				{/if}

				{#if event.show_event_details}
					<div class="event-info-grid">
						<!-- Event -->
						<div class="info-item">
							<div class="info-icon">
								<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
									<line x1="16" y1="2" x2="16" y2="6"/>
									<line x1="8" y1="2" x2="8" y2="6"/>
									<line x1="3" y1="10" x2="21" y2="10"/>
								</svg>
							</div>
							<div class="info-content">
								<h4>Event</h4>
								{#if event.community}
									<p class="community-link">
										{#if event.community.learn_more_link}
											<a href={event.community.learn_more_link} target="_blank" rel="noopener noreferrer">{event.community.name}</a>
										{:else}
											{event.community.name}
										{/if}
									</p>
								{/if}
								<p>{@html formatLineBreaks(event.title)}</p>
							</div>
						</div>

						<!-- Combined Talent Section -->
						{#if event.community_host || event.presenter || event.workshop_lead}
							<div class="info-item">
								<div class="info-icon">
									<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/>
										<circle cx="9" cy="7" r="4"/>
										<path d="M22 21v-2a4 4 0 0 0-3-3.87"/>
										<path d="M16 3.13a4 4 0 0 1 0 7.75"/>
									</svg>
								</div>
								<div class="info-content">
									{#if event.community_host}
										<div class="talent-section">
											<h4>Hosted By</h4>
											{#if event.community_host.learn_more_link}
												<p><a href={event.community_host.learn_more_link} target="_blank" rel="noopener noreferrer">{event.community_host.first_name} {event.community_host.last_name}</a></p>
											{:else}
												<p>{event.community_host.first_name} {event.community_host.last_name}</p>
											{/if}
										</div>
									{/if}

									{#if event.presenter}
										<div class="talent-section">
											<h4>Presented By</h4>
											{#if event.presenter.learn_more_link}
												<p><a href={event.presenter.learn_more_link} target="_blank" rel="noopener noreferrer">{event.presenter.first_name} {event.presenter.last_name}</a></p>
											{:else}
												<p>{event.presenter.first_name} {event.presenter.last_name}</p>
											{/if}
										</div>
									{/if}

									{#if event.workshop_lead}
										<div class="talent-section">
											<h4>Workshop By</h4>
											{#if event.workshop_lead.learn_more_link}
												<p><a href={event.workshop_lead.learn_more_link} target="_blank" rel="noopener noreferrer">{event.workshop_lead.first_name} {event.workshop_lead.last_name}</a></p>
											{:else}
												<p>{event.workshop_lead.first_name} {event.workshop_lead.last_name}</p>
											{/if}
										</div>
									{/if}
								</div>
							</div>
						{/if}

						<!-- Venue -->
						{#if event.venue}
							<div class="info-item">
								<div class="info-icon">
									<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<!-- Building base -->
										<rect x="4" y="6" width="16" height="16" rx="1"/>
										<!-- Windows -->
										<rect x="7" y="9" width="2" height="2"/>
										<rect x="11" y="9" width="2" height="2"/>
										<rect x="15" y="9" width="2" height="2"/>
										<rect x="7" y="13" width="2" height="2"/>
										<rect x="11" y="13" width="2" height="2"/>
										<rect x="15" y="13" width="2" height="2"/>
										<!-- Door -->
										<rect x="10" y="17" width="4" height="5"/>
										<!-- Roof -->
										<path d="M4 6l8-4 8 4"/>
									</svg>
								</div>
								<div class="info-content">
									<h4>Venue</h4>
									{#if event.venue.learn_more_link}
										<p class="venue-name"><a href={event.venue.learn_more_link} target="_blank" rel="noopener noreferrer">{event.venue.name}</a></p>
									{:else}
										<p class="venue-name">{event.venue.name}</p>
									{/if}
									<p class="venue-description">{@html formatLineBreaks(event.venue.description)}</p>
								</div>
							</div>
						{/if}

						<!-- WiFi Access -->
						{#if event.venue?.wifi_access}
							<div class="info-item">
								<div class="info-icon">
									<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3">
										<path d="M1 10c6.63-6.63 17.37-6.63 24 0"/>
										<path d="M5 14c4.42-4.42 11.58-4.42 16 0"/>
										<path d="M9 18c2.21-2.21 5.79-2.21 8 0"/>
									</svg>
								</div>
								<div class="info-content">
									<h4>WiFi Access</h4>
									<p>{@html formatLineBreaks(event.venue.wifi_access)}</p>
								</div>
							</div>
						{/if}

						<!-- Restrooms -->
						{#if event.venue?.restroom_details}
							<div class="info-item">
								<div class="info-icon">
									<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<!-- Toilet tank (taller) -->
										<rect x="7" y="2" width="10" height="8" rx="1"/>
										<!-- Toilet bowl rim -->
										<ellipse cx="12" cy="10" rx="8" ry="2.5"/>
										<!-- Toilet bowl -->
										<path d="M4 10v8c0 3 3.5 5 8 5s8-2 8-5v-8"/>
										<!-- Toilet seat (closed) -->
										<ellipse cx="12" cy="10" rx="6" ry="1.5" fill="none"/>
										<!-- Tank handle -->
										<circle cx="16" cy="6" r="1"/>
									</svg>
								</div>
								<div class="info-content">
									<h4>Restrooms</h4>
									<p>{@html formatLineBreaks(event.venue.restroom_details)}</p>
								</div>
							</div>
						{/if}

						<!-- Refreshments -->
						{#if event.venue?.food_details}
							<div class="info-item">
								<div class="info-icon">
									<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<path d="M18 8h1a4 4 0 0 1 0 8h-1"/>
										<path d="M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8z"/>
										<line x1="6" y1="1" x2="6" y2="4"/>
										<line x1="10" y1="1" x2="10" y2="4"/>
										<line x1="14" y1="1" x2="14" y2="4"/>
									</svg>
								</div>
								<div class="info-content">
									<h4>Refreshments</h4>
									<p>{@html formatLineBreaks(event.venue.food_details)}</p>
								</div>
							</div>
						{/if}
					</div>
				{/if}
			</main>

			{#if isCheckedIn}
				<footer class="clear-storage-footer">
					<button type="button" class="clear-storage-link" onclick={handleClearStorage}>
						Clear check-in
					</button>
				</footer>
			{/if}
		</div>
	{:else}
		<div class="error-state">
			<h1>Event Not Found</h1>
			<p>This event can't be found or is no longer active.</p>
		</div>
	{/if}
</div>

<style>
	.event-screen {
		min-height: 100vh;
		background: linear-gradient(135deg, var(--color-primary-gradient-start) 0%, var(--color-primary-gradient-end) 100%);
		padding: 15px;
		display: flex;
		flex-direction: column;
		justify-content: flex-start;
		align-items: center;
		color: white;
		box-sizing: border-box;
	}

	.event-content {
		width: 100%;
		max-width: 500px;
		margin: 0 auto;
		text-align: center;
	}

	.event-header {
		margin-bottom: 2rem;
	}

	.logo-container {
		display: flex;
		justify-content: center;
		margin-bottom: 1.5rem;
	}

	.community-banner {
		width: 100%;
		max-width: 500px;
		height: auto;
		border-radius: 10px;
		box-shadow: 0 4px 12px var(--shadow-base);
	}

	.status-title {
		font-size: 2.5rem;
		font-weight: bold;
		margin: 0;
		text-shadow: 0 2px 4px var(--shadow-text);
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.75rem;
	}

	.status-title.checked-in {
		color: white;
	}

	.status-icon {
		color: white;
		filter: drop-shadow(0 4px 8px var(--shadow-base));
		flex-shrink: 0;
	}

	.event-main {
		display: flex;
		flex-direction: column;
		gap: 2rem;
	}

	.welcome-box {
		background: var(--color-content-bg);
		border-radius: 1rem;
		padding: 1.5rem;
		text-align: center;
		box-shadow: 0 10px 25px var(--shadow-light);
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.welcome-message {
		font-size: 1.125rem;
		line-height: 1.6;
		color: var(--color-text-secondary);
	}

	/* Green button with gray text for welcome box */
	.welcome-box :global(.btn-primary) {
		background: linear-gradient(135deg, var(--color-primary-gradient-start) 0%, var(--color-primary-gradient-end) 100%);
		color: white;
	}

	.welcome-box :global(.btn-primary:hover:not(:disabled)) {
		background: linear-gradient(135deg, var(--color-primary-gradient-end) 0%, var(--color-primary-gradient-start) 100%);
		color: white;
	}

	.welcome-message p {
		margin: 0;
	}

	.check-in-action {
		display: flex;
		justify-content: center;
	}

	.donation-box {
		background: var(--color-content-bg);
		border-radius: 1rem;
		padding: 1.5rem;
		text-align: center;
		box-shadow: 0 10px 25px var(--shadow-light);
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.donation-message {
		font-size: 1.125rem;
		line-height: 1.6;
		color: var(--color-text-secondary);
	}

	.donation-message p {
		margin: 0;
	}

	.donation-action {
		display: flex;
		justify-content: center;
	}

	.donate-button {
		background: linear-gradient(135deg, var(--color-primary-gradient-start) 0%, var(--color-primary-gradient-end) 100%);
		color: white;
		text-decoration: none;
	}

	.donate-button:hover {
		background: linear-gradient(135deg, var(--color-primary-gradient-end) 0%, var(--color-primary-gradient-start) 100%);
		color: white;
	}

	.clear-storage-footer {
		margin-top: 2rem;
		text-align: center;
	}

	.clear-storage-link {
		background: none;
		border: none;
		color: rgba(255, 255, 255, 0.5);
		font-size: 0.625rem;
		cursor: pointer;
		padding: 0.5rem;
		text-decoration: underline;
		min-height: auto;
	}

	.clear-storage-link:hover {
		color: rgba(255, 255, 255, 0.8);
	}

	.event-info-grid {
		background: var(--color-content-bg);
		color: var(--color-text-secondary);
		border-radius: 1rem;
		padding: 2rem;
		text-align: left;
		box-shadow: 0 10px 25px var(--shadow-light);
		display: grid;
		gap: 1.5rem;
	}

	.venue-name {
		font-weight: bold;
		margin: 0 0 0.25rem 0;
		color: var(--color-text-primary);
	}

	.venue-description {
		font-size: 0.875rem;
		color: var(--color-text-muted);
		line-height: 1.4;
		margin: 0 0 0.5rem 0;
	}

	.info-item {
		display: flex;
		align-items: flex-start;
		gap: 1rem;
	}

	.info-icon {
		flex-shrink: 0;
		width: 40px;
		height: 40px;
		background: var(--color-bg-alt);
		border-radius: 0.5rem;
		display: flex;
		align-items: center;
		justify-content: center;
		color: var(--color-accent);
	}

	.info-content h4 {
		font-size: 1rem;
		font-weight: 600;
		margin: 0 0 0.25rem 0;
		color: var(--color-text-primary);
	}

	.info-content p {
		font-size: 0.875rem;
		color: var(--color-text-muted);
		margin: 0;
		line-height: 1.4;
	}

	.info-content a {
		color: var(--color-accent);
		text-decoration: underline;
	}

	.info-content a:hover {
		color: var(--color-accent-dark);
	}

	.community-link {
		font-weight: 600;
		margin-bottom: 0.25rem;
	}

	.talent-section {
		margin-bottom: 1rem;
	}

	.talent-section:last-child {
		margin-bottom: 0;
	}

	.talent-section h4 {
		margin-bottom: 0.25rem;
	}

	/* Loading and error states */
	.loading-state,
	.error-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 1rem;
		text-align: center;
		max-width: 400px;
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
		margin: 0;
		color: var(--color-error-text);
	}

	.error-state p {
		margin: 0;
		opacity: 0.9;
	}

	/* Mobile optimization */
	@media (max-width: 640px) {
		.event-screen {
			padding: 15px;
		}

		.status-title {
			font-size: 2rem;
			gap: 0.5rem;
		}

		.status-icon {
			width: 36px;
			height: 36px;
		}

		.welcome-box,
		.donation-box {
			padding: 1.25rem;
		}

		.event-info-grid {
			padding: 1.5rem;
			gap: 1rem;
		}

		.info-item {
			gap: 0.75rem;
		}
	}

	/* Larger screens - show info grid in 2 columns */
	@media (min-width: 640px) {
		.event-info-grid {
			grid-template-columns: 1fr 1fr;
		}
	}

	/* Raffle Winner Announcement Styles */
	.raffle-winner-announcement {
		background: linear-gradient(135deg, var(--color-success-bg-start) 0%, var(--color-success-bg-end) 100%);
		color: white;
		border-radius: 1rem;
		padding: 1.5rem;
		margin-bottom: 2rem;
		box-shadow: 0 10px 25px var(--shadow-success);
		animation: slideDown 0.5s ease-out;
		position: relative;
		overflow: hidden;
	}

	.raffle-winner-announcement::before {
		content: '';
		position: absolute;
		top: -50%;
		left: -50%;
		width: 200%;
		height: 200%;
		background: linear-gradient(
			45deg,
			transparent 30%,
			var(--overlay-white-light) 50%,
			transparent 70%
		);
		animation: shimmer 3s infinite;
	}

	@keyframes slideDown {
		from {
			transform: translateY(-20px);
			opacity: 0;
		}
		to {
			transform: translateY(0);
			opacity: 1;
		}
	}

	@keyframes shimmer {
		0% {
			transform: translateX(-100%) translateY(-100%) rotate(45deg);
		}
		100% {
			transform: translateX(100%) translateY(100%) rotate(45deg);
		}
	}

	.raffle-title {
		font-size: 1.75rem;
		font-weight: bold;
		margin: 0 0 1rem 0;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		text-shadow: 0 2px 4px var(--shadow-base);
		position: relative;
		z-index: 1;
	}

	.raffle-title svg {
		fill: white;
		animation: sparkle 1.5s ease-in-out infinite;
	}

	@keyframes sparkle {
		0%, 100% {
			transform: scale(1) rotate(0deg);
		}
		50% {
			transform: scale(1.2) rotate(180deg);
		}
	}

	.winners-list {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
		position: relative;
		z-index: 1;
	}

	.winner-item {
		background: var(--overlay-white);
		border-radius: 0.5rem;
		padding: 1rem;
		backdrop-filter: blur(10px);
		transition: all 0.3s ease;
	}

	.winner-item.is-you {
		background: linear-gradient(135deg, var(--color-winner-bg-start) 0%, var(--color-winner-bg-end) 100%);
		border: 2px solid var(--color-winner-border);
		animation: pulse 2s infinite;
		box-shadow: 0 4px 20px var(--shadow-winner);
	}

	.winner-item.is-you .winner-place,
	.winner-item.is-you .winner-name,
	.winner-item.is-you .winner-message {
		color: white;
		text-shadow: 0 1px 3px var(--shadow-text);
	}

	@keyframes pulse {
		0%, 100% {
			transform: scale(1);
			box-shadow: 0 0 0 0 var(--shadow-winner-pulse-start);
		}
		50% {
			transform: scale(1.02);
			box-shadow: 0 0 0 10px var(--shadow-winner-pulse-end);
		}
	}

	.winner-place {
		font-size: 0.875rem;
		font-weight: 600;
		opacity: 0.95;
		margin-bottom: 0.25rem;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}

	.winner-name {
		font-size: 1.25rem;
		font-weight: bold;
		margin-bottom: 0.25rem;
	}

	.winner-message {
		font-size: 1rem;
		margin-top: 0.5rem;
		font-weight: 600;
		animation: bounce 1s ease-in-out infinite;
	}

	@keyframes bounce {
		0%, 100% {
			transform: translateY(0);
		}
		50% {
			transform: translateY(-5px);
		}
	}

	@media (max-width: 640px) {
		.raffle-title {
			font-size: 1.5rem;
		}

		.raffle-title svg {
			width: 24px;
			height: 24px;
		}

		.winner-name {
			font-size: 1.125rem;
		}
	}
</style>
