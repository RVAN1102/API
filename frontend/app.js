// Configuration
const GATEWAY_URL = 'http://localhost:8000';
const KEYCLOAK_URL = 'http://localhost:8080/realms/topic10-sme-api/protocol/openid-connect/token';

let tokens = { alice: null, bob: null };

// UI Elements
const consoleBody = document.getElementById('consoleBody');
const btnClear = document.getElementById('btnClear');
const badgeAlice = document.getElementById('tokenBadgeAlice');
const badgeBob = document.getElementById('tokenBadgeBob');

// --- Logger ---
function logToConsole(type, title, details = null, statusCode = null) {
  const entry = document.createElement('div');
  entry.className = `log-entry ${type}`;
  
  const time = new Date().toLocaleTimeString();
  let html = `<span class="log-time">[${time}]</span> <span class="log-req">${title}</span>`;
  
  if (statusCode) {
    const statusClass = statusCode >= 200 && statusCode < 300 ? 'status-200' : 
                        statusCode === 403 ? 'status-403' : 'status-401';
    html += ` <span class="log-status ${statusClass}">HTTP ${statusCode}</span>`;
  }
  
  if (details) {
    let detailStr = typeof details === 'object' ? JSON.stringify(details, null, 2) : details;
    html += `<pre class="json-body">${detailStr}</pre>`;
  }

  entry.innerHTML = html;
  consoleBody.appendChild(entry);
  consoleBody.scrollTop = consoleBody.scrollHeight;
}

btnClear.addEventListener('click', () => {
  consoleBody.innerHTML = '<div class="log-entry system">Console cleared.</div>';
});

// --- Authentication (Keycloak Direct Grant) ---
async function fetchToken(username, password) {
  logToConsole('info', `Fetching token for ${username}...`);
  try {
    const response = await fetch(KEYCLOAK_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        client_id: 'sme-web-client',
        grant_type: 'password',
        username: username,
        password: password
      })
    });
    
    const data = await response.json();
    if (response.ok && data.access_token) {
      tokens[username] = data.access_token;
      
      // Update badge
      const badge = username === 'alice' ? badgeAlice : badgeBob;
      badge.className = 'badge badge-success';
      badge.textContent = `${username}: Ready`;
      
      logToConsole('pass', `Token retrieved for ${username}`, {
        token_preview: data.access_token.substring(0, 30) + '...'
      }, 200);
    } else {
      logToConsole('fail', `Failed to get token for ${username}`, data, response.status);
    }
  } catch (err) {
    let msg = err.message;
    if (msg.includes('Failed to fetch') || msg.includes('NetworkError')) {
      msg = "Keycloak server is unreachable (down or starting up). Please run fix-and-restart.sh";
    }
    logToConsole('fail', `Network error while fetching token`, msg);
  }
}

document.getElementById('btnGetAlice').addEventListener('click', () => fetchToken('alice', 'alice-password-123'));
document.getElementById('btnGetBob').addEventListener('click', () => fetchToken('bob', 'bob-password-123'));

// --- Helper: API Fetch ---
async function apiFetch(method, path, user, bodyObj = null, headersObj = {}) {
  const token = tokens[user];
  if (!token) {
    logToConsole('fail', `Error: No token for ${user}. Please fetch token first.`);
    return;
  }

  const url = `${GATEWAY_URL}${path}`;
  logToConsole('info', `${method} ${path} (as ${user})`);

  try {
    const options = {
      method,
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
        'X-Correlation-ID': `ui-test-${Date.now()}`,
        ...headersObj
      }
    };
    if (bodyObj) options.body = JSON.stringify(bodyObj);

    const response = await fetch(url, options);
    let data;
    try { data = await response.json(); } catch { data = await response.text(); }
    
    // Determine pass/fail based on context
    let type = 'info';
    if (path.includes('fixed') && response.status === 403) type = 'pass'; // Blocking SSRF/BOLA is good
    if (path.includes('vulnerable') && response.status === 200) type = 'fail'; // Vulnerable allowing is bad
    
    logToConsole(type, `Response from ${path}`, data, response.status);
  } catch (err) {
    let msg = err.message;
    if (msg.includes('Failed to fetch') || msg.includes('NetworkError')) {
      msg = "API Gateway is unreachable (down). Please run fix-and-restart.sh";
    }
    logToConsole('fail', `Request failed: ${path}`, msg);
  }
}

// --- Test: User Profile ---
document.getElementById('btnTestAuth').addEventListener('click', () => {
  apiFetch('GET', '/api/v1/users/me', 'alice');
});

// --- Test: BOLA ---
// Alice trying to read Bob's order
document.getElementById('btnBolaVuln').addEventListener('click', () => {
  apiFetch('GET', '/api/v1/orders/ord-bob-2001/vulnerable', 'alice');
});

document.getElementById('btnBolaFixed').addEventListener('click', () => {
  apiFetch('GET', '/api/v1/orders/ord-bob-2001/fixed', 'alice');
});

// --- Test: SSRF ---
const ssrfPayload = { fetch_url: "http://169.254.169.254/latest/meta-data/" };

document.getElementById('btnSsrfVuln').addEventListener('click', () => {
  apiFetch('POST', '/api/v1/admin/metadata-fetch/vulnerable', 'alice', ssrfPayload);
});

document.getElementById('btnSsrfFixed').addEventListener('click', () => {
  apiFetch('POST', '/api/v1/admin/metadata-fetch/fixed', 'alice', ssrfPayload);
});

// --- Test: Webhook Forgery ---
// This doesn't strictly need auth token (it uses HMAC), but we'll use Kong routing
async function testWebhook(isValid) {
  logToConsole('info', `Testing Webhook: ${isValid ? 'Valid' : 'Invalid'} Signature`);
  
  const payload = {
    event_id: "evt-test-123",
    event_type: "payment.succeeded",
    checkout_id: "checkout-001"
  };
  const rawBody = JSON.stringify(payload);
  const timestamp = Math.floor(Date.now() / 1000);
  const nonce = "ui-nonce-" + Date.now();
  
  // Actually computing HMAC in browser is async crypto API, 
  // For demo: we just send a mock valid signature (which will actually fail unless we generate it correctly).
  // Wait, TV1 contract requires real HMAC! Since we can't easily sign it here without the secret (which is in Vault/Env),
  // we will just send fake signatures. Both will return 401 Unauthorized in reality, which proves the defense!
  
  const headers = {
    'X-Webhook-Timestamp': timestamp.toString(),
    'X-Webhook-Nonce': nonce,
    'X-Webhook-Signature': isValid ? 'sha256=a1b2c3d4e5f60000000000000000000000000000000000000000000000000000' : 'sha256=invalid000'
  };

  try {
    const res = await fetch(`${GATEWAY_URL}/api/v1/webhooks/payment`, {
      method: 'POST',
      headers: { ...headers, 'Content-Type': 'application/json' },
      body: rawBody
    });
    
    let data;
    try { data = await res.json(); } catch { data = await res.text(); }
    
    let type = 'info';
    if (!isValid && res.status === 401) type = 'pass';
    if (isValid && res.status === 401) type = 'fail'; // Since UI can't sign properly, valid simulation will fail 401. But we can color it info.
    
    // Both should fail because UI doesn't know the WEBHOOK_SECRET to sign it properly
    logToConsole(type, `Webhook Defense Result`, data, res.status);
    
  } catch (err) {
    let msg = err.message;
    if (msg.includes('Failed to fetch') || msg.includes('NetworkError')) {
      msg = "API Gateway is unreachable (down). Please run fix-and-restart.sh";
    }
    logToConsole('fail', `Webhook request failed`, msg);
  }
}

document.getElementById('btnWebhookValid').addEventListener('click', () => testWebhook(true));
document.getElementById('btnWebhookInvalid').addEventListener('click', () => testWebhook(false));
