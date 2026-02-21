// Configuration
const BRIDGE_API = 'http://localhost:8765';
const POLL_ENDPOINT = `${BRIDGE_API}/bridge/poll`;
const ALARM_NAME = 'keep-alive-alarm';

// State
let isPolling = false;

// 1. Initialize
chrome.runtime.onStartup.addListener(startService);
chrome.runtime.onInstalled.addListener(startService);

// 2. Alarm Listener (Wake up mechanism)
chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === ALARM_NAME) {
    // console.log('⏰ Keep-alive alarm triggered');
    if (!isPolling) startPolling();
  }
});

// Manual start if loaded directly
startService();

function startService() {
  console.log('🚀 MicDrop Bridge Service started');
  // Set up alarm to fire every 30 seconds to keep worker alive
  chrome.alarms.create(ALARM_NAME, { periodInMinutes: 0.5 });
  startPolling();
}

async function startPolling() {
  if (isPolling) return;
  isPolling = true;
  console.log('🔄 Polling loop initialized');

  while (isPolling) {
    try {
      // Use AbortController to prevent hanging connections
      const controller = new AbortController();
      // Server-side timeout is typically 30s-60s. We set client timeout slightly higher.
      const timeoutId = setTimeout(() => controller.abort(), 65000);

      const response = await fetch(POLL_ENDPOINT, { signal: controller.signal });
      clearTimeout(timeoutId);

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const data = await response.json();
      console.log('⚡️ Received event:', data.event);

      // Handle event asynchronously
      handleEvent(data.event);

    } catch (error) {
      if (error.name === 'AbortError') {
        // Timeout is expected if no events occur, just reconnect immediately
        // console.log('Poll timeout, reconnecting...');
      } else {
        console.warn('Polling connection lost (App might be closed):', error.message);
        // Wait 5s before retrying to avoid spamming
        await new Promise(resolve => setTimeout(resolve, 5000));
      }
    }
  }
}

async function handleEvent(event) {
  // Find all Google Meet tabs
  const tabs = await chrome.tabs.query({ url: '*://meet.google.com/*' });

  if (tabs.length === 0) {
    // console.log('No Google Meet tabs found to control');
    return;
  }

  // Broadcast event to all Meet tabs
  for (const tab of tabs) {
    try {
      await chrome.tabs.sendMessage(tab.id, {
        action: 'bridge-event',
        event: event
      });
      console.log(`Sent ${event} to tab ${tab.id}`);
    } catch (err) {
      console.error(`Failed to send message to tab ${tab.id}:`, err);
    }
  }
}

// Listen for state updates from Content Script and forward to Native App
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.action === 'report-state') {
    // Forward state to Native App (fire and forget)
    fetch(`${BRIDGE_API}/bridge/mic-state`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ muted: message.muted })
    }).catch(err => {
        // Silent fail for reporting is fine
    });
  }
});
