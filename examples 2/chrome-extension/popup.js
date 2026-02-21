// MicDrop Bridge - Popup UI Script

const SERVER_URL = 'http://localhost:8765';

const indicator = document.getElementById('indicator');
const statusText = document.getElementById('status-text');
const testButton = document.getElementById('test-btn');

/**
 * Check server connection
 */
async function checkConnection() {
  try {
    const response = await fetch(`${SERVER_URL}/status`, {
      method: 'GET',
      signal: AbortSignal.timeout(2000)
    });

    if (response.ok) {
      const data = await response.json();
      updateUI(true, data);
    } else {
      updateUI(false);
    }
  } catch (error) {
    console.error('Connection check failed:', error);
    updateUI(false);
  }
}

/**
 * Update UI based on connection status
 */
function updateUI(connected, data = null) {
  if (connected) {
    indicator.classList.add('connected');
    indicator.classList.remove('disconnected');
    statusText.textContent = '✅ Connected to MicDrop Server';

    if (data) {
      const muteStatus = data.muted ? 'Muted 🔇' : 'Active 🎤';
      statusText.textContent = `✅ Connected • ${muteStatus}`;
    }

    testButton.disabled = false;
  } else {
    indicator.classList.add('disconnected');
    indicator.classList.remove('connected');
    statusText.textContent = '❌ Server not available';
    testButton.disabled = true;
  }
}

/**
 * Test toggle
 */
async function testToggle() {
  testButton.disabled = true;
  testButton.textContent = 'Testing...';

  try {
    const response = await fetch(`${SERVER_URL}/toggle-mic`, {
      method: 'POST'
    });

    const result = await response.json();

    if (result.status === 'ok') {
      alert(`✅ Toggle successful!\nMuted: ${result.muted}`);
    } else if (result.status === 'timeout') {
      alert('⚠️ Extension confirmation timeout\nMake sure you are in a Google Meet call');
    } else {
      alert(`❌ Toggle failed: ${result.status}`);
    }
  } catch (error) {
    alert(`❌ Test failed: ${error.message}`);
  }

  testButton.textContent = 'Test Connection';
  testButton.disabled = false;
}

// Event listeners
testButton.addEventListener('click', testToggle);

// Check connection on load
checkConnection();

// Refresh every 3 seconds
setInterval(checkConnection, 3000);
