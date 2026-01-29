console.log('Audio Remote Bridge: Google Meet Content Script Loaded');

// Configuration
const SELECTORS = {
  // Mic button usually has data-is-muted attribute
  micButton: 'button[data-is-muted]',
  // Fallback: aria-label
  micButtonAria: 'button[aria-label*="microphone"]'
};

// Listen for messages from background script
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.action === 'bridge-event') {
    handleBridgeEvent(message.event);
  }
});

function handleBridgeEvent(event) {
  const micButton = findMicButton();

  if (!micButton) {
    console.warn('Mic button not found');
    return;
  }

  const isMuted = micButton.getAttribute('data-is-muted') === 'true';

  switch (event) {
    case 'toggle-mic':
      micButton.click();
      break;

    case 'mute-mic':
      if (!isMuted) micButton.click();
      break;

    case 'unmute-mic':
      if (isMuted) micButton.click();
      break;
  }
}

function findMicButton() {
  // Try primary selector
  let btn = document.querySelector(SELECTORS.micButton);
  if (btn) return btn;

  // Try aria-label fallback (English)
  const ariaBtns = document.querySelectorAll(SELECTORS.micButtonAria);
  for (const b of ariaBtns) {
    // Basic heuristics to ensure it's the main control bar button
    if (b.offsetHeight > 30) return b;
  }

  return null;
}

// Observe state changes and report back
function setupObserver() {
  const observer = new MutationObserver((mutations) => {
    for (const mutation of mutations) {
      if (mutation.type === 'attributes' &&
          (mutation.attributeName === 'data-is-muted' || mutation.attributeName === 'aria-label')) {

        const btn = mutation.target;
        // Check if this is the mic button
        if (btn.matches(SELECTORS.micButton) || btn.matches(SELECTORS.micButtonAria)) {
            const isMuted = btn.getAttribute('data-is-muted') === 'true';
            reportState(isMuted);
        }
      }
    }
  });

  // Observe the entire body for now (or a specific container if we can identify it)
  observer.observe(document.body, {
    attributes: true,
    subtree: true,
    attributeFilter: ['data-is-muted', 'aria-label']
  });
}

function reportState(muted) {
  chrome.runtime.sendMessage({
    action: 'report-state',
    muted: muted
  });
}

// Initialize observer
setupObserver();
