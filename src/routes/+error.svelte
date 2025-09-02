<!-- Custom Error Page -->
<script lang="ts">
	import { page } from '$app/stores';
	
	$: status = $page.status;
	$: message = $page.error?.message || 'Something went wrong';
</script>

<svelte:head>
	<title>Error {status}</title>
	<meta name="viewport" content="width=device-width, initial-scale=1.0" />
</svelte:head>

<div class="container">
	<div class="error-card">
		<div class="error-icon">🚫</div>
		
		{#if status === 404}
			<h1 class="title">Event Not Found</h1>
			<p class="message">
				This event can't be found or is no longer active. 
				Please check your URL or contact the event organizer.
			</p>
		{:else}
			<h1 class="title">Error {status}</h1>
			<p class="message">{message}</p>
		{/if}
		
		<button 
			class="back-btn" 
			type="button"
			on:click={() => history.back()}
		>
			Go Back
		</button>
	</div>
</div>

<style>
	.container {
		min-height: 100vh;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 1rem;
		background: linear-gradient(135deg, var(--color-error-bg-start) 0%, var(--color-error-bg-end) 100%);
	}

	.error-card {
		background: var(--color-bg-white);
		border-radius: 1rem;
		padding: 2rem;
		box-shadow: 0 10px 25px var(--shadow-light);
		text-align: center;
		max-width: 500px;
		width: 100%;
	}

	.error-icon {
		font-size: 4rem;
		margin-bottom: 1rem;
	}

	.title {
		font-size: 2rem;
		font-weight: bold;
		color: var(--color-error-page-text);
		margin-bottom: 1rem;
	}

	.message {
		font-size: 1.1rem;
		color: var(--color-error-page-text-muted);
		line-height: 1.6;
		margin-bottom: 2rem;
	}

	.back-btn {
		background: linear-gradient(135deg, var(--color-error-bg-start) 0%, var(--color-error-bg-end) 100%);
		color: white;
		border: none;
		padding: 1rem 2rem;
		font-size: 1.1rem;
		font-weight: bold;
		border-radius: 0.5rem;
		cursor: pointer;
		transition: transform 0.2s, box-shadow 0.2s;
	}

	.back-btn:hover {
		transform: translateY(-2px);
		box-shadow: 0 5px 15px var(--shadow-error-button);
	}

	.back-btn:active {
		transform: translateY(0);
	}

	/* Mobile optimization */
	@media (max-width: 640px) {
		.container {
			padding: 0.5rem;
		}
		
		.error-card {
			padding: 1.5rem;
		}
		
		.title {
			font-size: 1.75rem;
		}
		
		.error-icon {
			font-size: 3rem;
		}
	}
</style>