console.log('MicDrop Bridge: Google Meet Content Script Loaded');

// Selectors hoạt động cả pre-join lẫn in-meeting
// Pre-join:   DIV[role="button"][data-is-muted][aria-label*="microphone"]
// In-meeting: BUTTON[data-is-muted][aria-label*="microphone"]
const MIC_SEL  = '[data-is-muted][aria-label*="microphone" i]';
const CAM_SEL  = '[data-is-muted][aria-label*="camera" i]';

// Listen for messages from background script
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.action === 'bridge-event') {
    handleBridgeEvent(message.event);
  }
});

function handleBridgeEvent(event) {
  const mic = document.querySelector(MIC_SEL);
  if (!mic) { console.warn('MicDrop: mic button not found'); return; }
  const muted = mic.getAttribute('data-is-muted') === 'true';

  switch (event) {
    case 'toggle-mic':  mic.click(); break;
    case 'mute-mic':    if (!muted) mic.click(); break;
    case 'unmute-mic':  if (muted)  mic.click(); break;
  }
}

// Observe state changes → report to native app
function setupObserver() {
  const observer = new MutationObserver((mutations) => {
    for (const m of mutations) {
      if (m.type !== 'attributes') continue;
      const el = m.target;
      if (el.matches(MIC_SEL) || (el.hasAttribute('data-is-muted') && /microphone/i.test(el.getAttribute('aria-label') || ''))) {
        reportMicState(el.getAttribute('data-is-muted') === 'true');
      }
    }
  });
  observer.observe(document.body, {
    attributes: true, subtree: true,
    attributeFilter: ['data-is-muted', 'aria-label']
  });
}

function reportMicState(muted) {
  chrome.runtime.sendMessage({ action: 'report-state', muted });
}

// Auto-mute mic + camera khi vào Meet (pre-join và in-meeting)
function setupAutoMute() {
  let applied = false;

  function tryMute() {
    if (applied) return false;
    const mic = document.querySelector(MIC_SEL);
    if (!mic) return false;

    applied = true;
    console.log('MicDrop: Auto-muting on Meet load');

    // Mute mic nếu đang bật
    if (mic.getAttribute('data-is-muted') !== 'true') {
      mic.click();
      console.log('MicDrop: Mic muted');
    }

    // Tắt camera sau 300ms
    setTimeout(() => {
      const cam = document.querySelector(CAM_SEL);
      if (cam && cam.getAttribute('data-is-muted') !== 'true') {
        cam.click();
        console.log('MicDrop: Camera turned off');
      }
      // Report trạng thái mic sau khi settle
      setTimeout(() => {
        const m = document.querySelector(MIC_SEL);
        if (m) reportMicState(m.getAttribute('data-is-muted') === 'true');
      }, 300);
    }, 300);

    return true;
  }

  // Thử ngay (nếu DOM đã có sẵn)
  if (!tryMute()) {
    // Watch DOM cho buttons xuất hiện
    const observer = new MutationObserver(() => {
      if (tryMute()) observer.disconnect();
    });
    observer.observe(document.body, { childList: true, subtree: true });

    // Fallback timers phòng case DOM load chậm
    [500, 1500, 3000].forEach(ms => setTimeout(tryMute, ms));
  }
}

setupObserver();
setupAutoMute();
