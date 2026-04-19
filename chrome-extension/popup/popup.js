const BRIDGE_API = 'http://localhost:8765';

document.addEventListener('DOMContentLoaded', checkStatus);
document.getElementById('retry-btn').addEventListener('click', checkStatus);
document.getElementById('shortcuts-btn').addEventListener('click', () => {
  chrome.tabs.create({ url: 'chrome://extensions/shortcuts' });
});

async function checkStatus() {
  const connWrapper = document.getElementById('connection-status-wrapper');
  const connIndicator = document.getElementById('connection-indicator');
  const connText = document.getElementById('connection-text');
  
  const micWrapper = document.getElementById('mic-status-wrapper');
  const micIndicator = document.getElementById('mic-indicator');
  const micText = document.getElementById('mic-text');

  // Reset to checking state
  connText.textContent = 'Checking...';
  connWrapper.className = 'value status-checking';
  connIndicator.className = 'indicator bg-accent';

  try {
    const response = await fetch(`${BRIDGE_API}/status`);
    if (response.ok) {
      const data = await response.json();

      // App Connection
      connText.textContent = 'Connected';
      connWrapper.className = 'value status-connected';
      connIndicator.className = 'indicator bg-success';

      // Mic Status
      if (data.muted) {
        micText.textContent = 'Muted';
        micWrapper.className = 'value status-muted';
        micIndicator.className = 'indicator bg-danger';
      } else {
        micText.textContent = 'Active';
        micWrapper.className = 'value status-active';
        micIndicator.className = 'indicator bg-success';
      }
    } else {
      throw new Error('Server error');
    }
  } catch (error) {
    // Disconnected state
    connText.textContent = 'Disconnected';
    connWrapper.className = 'value status-disconnected';
    connIndicator.className = 'indicator bg-danger';
    
    micText.textContent = 'Unavailable';
    micWrapper.className = 'value';
    micIndicator.className = 'indicator bg-dim';
  }
}
