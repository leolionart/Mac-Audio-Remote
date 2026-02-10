// MicDrop Bridge - Background Service Worker
// Handles extension lifecycle and server communication

const SERVER_URL = 'http://localhost:8765';

// Listen for extension install
chrome.runtime.onInstalled.addListener(() => {
  console.log('🎤 MicDrop Bridge installed');
});

// Listen for messages from content script
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.type === 'SERVER_STATUS') {
    // Check server status
    fetch(`${SERVER_URL}/status`)
      .then(response => response.ok)
      .then(available => sendResponse({ available }))
      .catch(() => sendResponse({ available: false }));
    return true; // Keep channel open for async response
  }
});

// Keep service worker alive (Chrome kills it after 30s of inactivity)
let keepAliveInterval;

function keepAlive() {
  keepAliveInterval = setInterval(() => {
    console.log('Service worker keepalive ping');
  }, 20000); // Every 20 seconds
}

function stopKeepAlive() {
  clearInterval(keepAliveInterval);
}

keepAlive();
