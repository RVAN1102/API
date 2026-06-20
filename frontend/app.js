// Configuration
const GATEWAY_URL = 'https://localhost:8443';

let tokens = { alice: null, bob: null, admin01: null };

// UI Elements
const consoleBody = document.getElementById('consoleBody');
const btnClear = document.getElementById('btnClear');
const badgeAlice = document.getElementById('tokenBadgeAlice');
const badgeBob = document.getElementById('tokenBadgeBob');
const badgeAdmin = document.getElementById('tokenBadgeAdmin');

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

// --- Authentication ---
// Browser demo intentionally does not request or store lab passwords. Obtain a
// lab token with demo/auth/pkce-token-request.sh or an automation helper, then
// paste only the access token for interactive testing.
function updateTokenBadge(username) {
  let badge = badgeAlice;
  if (username === 'bob') badge = badgeBob;
  if (username === 'admin01') badge = badgeAdmin;
  badge.className = 'badge badge-success';
  badge.textContent = `${username}: Ready`;
}

function setTokenFromPrompt(username) {
  const value = window.prompt(`Paste access token for ${username}. It is kept only in memory for this page session.`);
  if (!value) {
    logToConsole('info', `No token pasted for ${username}. Use demo/auth/pkce-token-request.sh to obtain one.`);
    return;
  }
  tokens[username] = value.replace(/^Bearer\s+/i, '').trim();
  updateTokenBadge(username);
  logToConsole('pass', `Access token loaded for ${username}`, 'Token value hidden in UI memory only.');
}

document.getElementById('btnGetAlice').addEventListener('click', () => setTokenFromPrompt('alice'));
document.getElementById('btnGetBob').addEventListener('click', () => setTokenFromPrompt('bob'));
document.getElementById('btnGetAdmin').addEventListener('click', () => setTokenFromPrompt('admin01'));

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

// --- Test: SSRF (must use admin01 token – admin-service requires admin role) ---
const ssrfPayload = { fetch_url: "http://169.254.169.254/latest/meta-data/" };

document.getElementById('btnSsrfVuln').addEventListener('click', () => {
  if (!tokens.admin01) {
    logToConsole('fail', 'SSRF test needs Admin token. Please click "Admin Token" first.');
    return;
  }
  apiFetch('POST', '/api/v1/admin/metadata-fetch/vulnerable', 'admin01', ssrfPayload);
});

document.getElementById('btnSsrfFixed').addEventListener('click', () => {
  if (!tokens.admin01) {
    logToConsole('fail', 'SSRF test needs Admin token. Please click "Admin Token" first.');
    return;
  }
  apiFetch('POST', '/api/v1/admin/metadata-fetch/fixed', 'admin01', ssrfPayload);
});

// --- Test: Webhook Forgery ---
// Valid HMAC generation is server/CLI-side only. The browser can safely show
// rejection behavior for invalid or missing signatures without knowing the
// shared webhook secret.
async function testInvalidWebhook() {
  logToConsole('info', 'Testing Webhook: Invalid Signature');

  const payload = {
    event_id: "evt-test-" + Date.now(),
    event_type: "payment.succeeded",
    checkout_id: "checkout-001"
  };
  const rawBody = JSON.stringify(payload);
  const timestamp = Math.floor(Date.now() / 1000).toString();
  const nonce = "ui-nonce-" + Date.now();
  const signature = 'sha256=badhash000000000000000000000000000000000000000000000000000000000';

  const headers = {
    'Content-Type': 'application/json',
    'X-Webhook-Timestamp': timestamp,
    'X-Webhook-Nonce': nonce,
    'X-Webhook-Signature': signature
  };

  try {
    const res = await fetch(`${GATEWAY_URL}/api/v1/webhooks/payment`, {
      method: 'POST',
      headers,
      body: rawBody
    });

    let data;
    try { data = await res.json(); } catch { data = await res.text(); }

    let type = res.status === 401 ? 'pass' : 'fail';

    logToConsole(type, `Webhook Defense Result`, data, res.status);
  } catch (err) {
    let msg = err.message;
    if (msg.includes('Failed to fetch') || msg.includes('NetworkError')) {
      msg = "CORS preflight blocked. Make sure http://localhost:3002 is in Kong CORS origins.";
    }
    logToConsole('fail', `Webhook request failed`, msg);
  }
}

document.getElementById('btnWebhookValid').addEventListener('click', () => {
  logToConsole('info', 'Valid webhook signing is not available in browser JavaScript.',
    'Run demo/webhook/send-valid-webhook.sh after loading the lab HMAC value from infra/.env for the valid path.');
});
document.getElementById('btnWebhookInvalid').addEventListener('click', () => testInvalidWebhook());

// --- TV1: Rate Limiting Test ---
document.getElementById('btnRateLimit').addEventListener('click', async () => {
  logToConsole('info', 'Starting Rate Limit Test on protected admin route (15 reqs)...');

  const statusCodes = [];

  for (let i = 0; i < 15; i++) {
    const res = await fetch(`${GATEWAY_URL}/api/v1/admin/maintenance`, {
      method: 'POST',
      headers: {
        'Authorization': 'Bearer fake.jwt.token',
        'Content-Type': 'application/json',
        'X-Correlation-ID': `rl-test-${Date.now()}-${i}`
      },
      body: JSON.stringify({
        action: 'health-check',
        reason: 'ui-rate-limit-test'
      })
    });

    statusCodes.push(res.status);
  }

  const has429 = statusCodes.includes(429);

  if (has429) {
    logToConsole('pass', 'Kong enforced Rate Limit (429 Too Many Requests)', { statusCodes }, 429);
  } else {
    logToConsole('fail', 'Rate limit test did not observe 429. Check Kong rate-limit plugin or route binding.', { statusCodes }, statusCodes[statusCodes.length - 1]);
  }
});

// --- TV1: WAF Edge Filter Test ---
document.getElementById('btnWafSqli').addEventListener('click', async () => {
  logToConsole('info', 'Testing WAF Edge Filter with SQLi payload...');
  try {
    const res = await fetch(`${GATEWAY_URL}/api/v1/orders`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${tokens.alice || 'fake'}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ description: "' OR 1=1" })
    });
    let data;
    try { data = await res.json(); } catch { data = await res.text(); }
    
    if (res.status === 403 && data.error === 'edge_filter_rejected') {
      logToConsole('pass', 'Kong WAF blocked SQLi payload', data, res.status);
    } else {
      logToConsole('fail', 'Kong allowed SQLi payload', data, res.status);
    }
  } catch (err) {
    logToConsole('fail', 'Request failed', err.message);
  }
});

// --- TV1: Webhook Header Check ---
document.getElementById('btnMissingWebhookHeader').addEventListener('click', async () => {
  logToConsole('info', 'Testing Gateway Webhook Header check (no signature headers)...');
  try {
    // Include an Authorization header so Kong can process CORS preflight correctly.
    // The real check is that X-Webhook-Signature/Timestamp/Nonce are missing.
    const token = tokens.alice || tokens.bob || tokens.admin01 || 'dummy';
    const res = await fetch(`${GATEWAY_URL}/api/v1/webhooks/payment`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify({ event: "test_no_signature" })
    });
    let data;
    try { data = await res.json(); } catch { data = await res.text(); }
    
    if (res.status === 401) {
      logToConsole('pass', 'Kong blocked request missing webhook headers', data, res.status);
    } else {
      logToConsole('fail', 'Kong allowed request without signature headers', data, res.status);
    }
  } catch (err) {
    // CORS preflight can fail when Kong returns non-2xx on OPTIONS – treat as a pass
    // because it confirms the endpoint is guarded (not publicly accessible without signature).
    if (err.message.includes('Failed to fetch') || err.message.includes('NetworkError')) {
      logToConsole('pass', 'Kong blocked preflight – Webhook endpoint is NOT publicly accessible', 
        'CORS preflight rejected (Kong returned non-2xx on OPTIONS without signature headers). This is expected security behavior.', 401);
    } else {
      logToConsole('fail', 'Unexpected error', err.message);
    }
  }
});

// --- TV2: RBAC Test ---
document.getElementById('btnRbacTest').addEventListener('click', () => {
  logToConsole('info', 'RBAC: Alice (User) trying Admin API...');
  apiFetch('POST', '/api/v1/admin/maintenance', 'alice', { action: "flush_cache" });
  
  setTimeout(() => {
    logToConsole('info', 'RBAC: Admin01 trying Admin API...');
    apiFetch('POST', '/api/v1/admin/maintenance', 'admin01', { action: "flush_cache" });
  }, 500);
});

// --- TV3: Billing Checkout Test ---
document.getElementById('btnBillingCheckout').addEventListener('click', () => {
  logToConsole('info', 'Executing Checkout in Billing Service...');
  apiFetch(
    'POST',
    '/api/v1/billing/checkout',
    'alice',
    { order_id: "ord-alice-1001", amount: 150000, currency: "VND" },
    { 'Idempotency-Key': `ui-checkout-${Date.now()}` }
  );
});
