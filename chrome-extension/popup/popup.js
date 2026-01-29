const BRIDGE_API = 'http://localhost:8765';

document.addEventListener('DOMContentLoaded', checkStatus);
document.getElementById('retry-btn').addEventListener('click', checkStatus);

async function checkStatus() {
  const connStatus = document.getElementById('connection-status');
  const micStatus = document.getElementById('mic-status');

  connStatus.textContent = 'Checking...';
  connStatus.className = 'status-value';

  try {
    const response = await fetch(`${BRIDGE_API}/status`);
    if (response.ok) {
      const data = await response.json();

      connStatus.textContent = 'Connected';
      connStatus.className = 'status-value connected';

      micStatus.textContent = data.muted ? 'Muted' : 'Active';
      micStatus.className = `status-value ${data.muted ? 'muted' : 'active'}`;
    } else {
      throw new Error('Server error');
    }
  } catch (error) {
    connStatus.textContent = 'Disconnected';
    connStatus.className = 'status-value disconnected';
    micStatus.textContent = '-';
  }
}
