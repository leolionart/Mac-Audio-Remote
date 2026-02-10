// MicDrop Bridge - Google Meet Content Script
// This script runs on meet.google.com and controls the microphone

const SERVER_URL = 'http://localhost:8765';
const POLL_RETRY_DELAY = 1000; // 1 second

console.log('🎤 MicDrop Bridge loaded for Google Meet');

// State tracking
let isPolling = false;
let pollAbortController = null;

/**
 * Get current mute state from Google Meet UI
 * @returns {boolean} True if muted, false if unmuted
 */
function getMeetMuteState() {
  // Try multiple selectors (Google Meet UI changes frequently)
  const selectors = [
    '[data-is-muted="true"]',
    '[aria-label*="Turn off microphone"]',
    'button[aria-label*="microphone"][data-is-muted]'
  ];

  for (const selector of selectors) {
    const button = document.querySelector(selector);
    if (button) {
      const isMuted = button.getAttribute('data-is-muted') === 'true' ||
                      button.getAttribute('aria-label')?.includes('Turn on') ||
                      button.classList.contains('muted');
      console.log(`Detected mute state: ${isMuted}`);
      return isMuted;
    }
  }

  console.warn('Could not detect mute state - assuming unmuted');
  return false;
}

/**
 * Find and click the microphone toggle button
 * @returns {Promise<boolean>} True if button was clicked
 */
async function toggleMicrophoneButton() {
  const selectors = [
    '[data-tooltip*="microphone"]',
    '[aria-label*="microphone" i]',
    'button[jsname][data-is-muted]'
  ];

  for (const selector of selectors) {
    const button = document.querySelector(selector);
    if (button) {
      console.log('Clicking microphone button:', selector);
      button.click();

      // Wait for UI update
      await sleep(200);
      return true;
    }
  }

  console.error('Microphone button not found!');
  return false;
}

/**
 * Send confirmation to MicDrop server with actual state
 */
async function sendConfirmation() {
  try {
    const actualState = getMeetMuteState();
    console.log(`📤 Sending confirmation: muted=${actualState}`);

    const response = await fetch(`${SERVER_URL}/bridge/mic-state`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ muted: actualState })
    });

    if (response.ok) {
      console.log('✅ Confirmation sent successfully');
    } else {
      console.error('⚠️ Confirmation failed:', response.status);
    }
  } catch (error) {
    console.error('❌ Confirmation error:', error);
  }
}

/**
 * Handle events from MicDrop server
 */
async function handleEvent(event) {
  console.log(`📥 Received event: ${event}`);

  switch (event) {
    case 'toggle-mic':
    case 'mute-mic':
    case 'unmute-mic':
      const clicked = await toggleMicrophoneButton();
      if (clicked) {
        // CRITICAL: Send confirmation with actual state
        await sendConfirmation();
      } else {
        console.error('Failed to toggle microphone');
      }
      break;

    default:
      console.log(`Ignoring unknown event: ${event}`);
  }
}

/**
 * Long-polling loop to receive events from server
 */
async function pollForEvents() {
  if (isPolling) {
    console.log('Already polling, skipping');
    return;
  }

  isPolling = true;
  console.log('🔄 Starting long-poll loop');

  while (isPolling) {
    try {
      pollAbortController = new AbortController();

      const response = await fetch(`${SERVER_URL}/bridge/poll`, {
        signal: pollAbortController.signal
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }

      const data = await response.json();
      await handleEvent(data.event);

    } catch (error) {
      if (error.name === 'AbortError') {
        console.log('Poll aborted');
        break;
      }

      console.error('Poll error:', error);
      await sleep(POLL_RETRY_DELAY);
    }
  }

  console.log('🛑 Polling stopped');
}

/**
 * Stop polling
 */
function stopPolling() {
  isPolling = false;
  if (pollAbortController) {
    pollAbortController.abort();
    pollAbortController = null;
  }
}

/**
 * Check if server is available
 */
async function checkServerConnection() {
  try {
    const response = await fetch(`${SERVER_URL}/status`, {
      method: 'GET',
      signal: AbortSignal.timeout(2000)
    });
    return response.ok;
  } catch {
    return false;
  }
}

/**
 * Initialize extension
 */
async function init() {
  console.log('🚀 Initializing MicDrop Bridge');

  // Check if we're in a Google Meet call (not just meet.google.com home)
  const urlPattern = /meet\.google\.com\/[a-z]{3}-[a-z]{4}-[a-z]{3}/;
  if (!urlPattern.test(window.location.href)) {
    console.log('Not in a meeting, waiting...');

    // Watch for navigation to meeting
    const observer = new MutationObserver(() => {
      if (urlPattern.test(window.location.href)) {
        observer.disconnect();
        init();
      }
    });

    observer.observe(document.body, { childList: true, subtree: true });
    return;
  }

  // Check server connection
  const serverAvailable = await checkServerConnection();
  if (!serverAvailable) {
    console.error('❌ MicDrop Server not available at', SERVER_URL);
    console.log('Please start MicDrop app on macOS');
    return;
  }

  console.log('✅ MicDrop Server connected');

  // Wait for Meet UI to load
  await waitForMeetUI();

  // Start polling
  pollForEvents();

  // Send initial state
  await sendConfirmation();
}

/**
 * Wait for Google Meet UI to be ready
 */
async function waitForMeetUI() {
  const maxAttempts = 20;
  let attempts = 0;

  while (attempts < maxAttempts) {
    const button = document.querySelector('[aria-label*="microphone" i]');
    if (button) {
      console.log('✅ Meet UI ready');
      return;
    }

    attempts++;
    await sleep(500);
  }

  console.warn('⚠️ Meet UI not detected, proceeding anyway');
}

/**
 * Sleep utility
 */
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// Cleanup on page unload
window.addEventListener('beforeunload', () => {
  stopPolling();
});

// Start when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}
