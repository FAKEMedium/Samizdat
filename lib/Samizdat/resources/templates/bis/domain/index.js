// BIS Domain Detail JavaScript
// URL patterns from named routes
const BIS_DOMAIN_API = '<%= url_for('BIS.public.domain', domain => 'PLACEHOLDER') %>'.replace('/PLACEHOLDER', '');
const BIS_DOMAIN_BASE = '<%= url_for('bis_domain', domain => 'PLACEHOLDER') %>'.replace('/PLACEHOLDER', '');
const BIS_SECTOR_BASE = '<%= url_for('bis_sector', sector => 'PLACEHOLDER') %>'.replace('/PLACEHOLDER', '');
const LOCALE = '<%= stash('language') || 'en' %>';

// Format number with locale-specific decimal separator
function formatNumber(num, decimals = 1) {
  return num.toLocaleString(LOCALE, {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals
  });
}

async function loadDomainDetails() {
  try {
    // Get domain from URL path
    const pathParts = window.location.pathname.split('/');
    const domain = pathParts[pathParts.length - 1];

    const response = await fetch(`${BIS_DOMAIN_API}/${domain}`);

    if (!response.ok) {
      if (response.status === 404) {
        showError('<%= __('Domain not found') %>');
      } else {
        throw new Error('<%= __('Failed to load domain details') %>');
      }
      return;
    }

    const data = await response.json();

    // Ensure numeric fields are numbers
    if (data.domain) {
      data.domain.score = parseFloat(data.domain.score) || 0;
      data.domain.compliant_checks = parseInt(data.domain.compliant_checks) || 0;
      data.domain.total_checks = parseInt(data.domain.total_checks) || 0;
    }

    renderDomainHeader(data.domain, data.tags);
    renderComplianceOverview(data.domain);
    renderChecksTable(data.checks);
    renderProviderSummary(data.checks);

  } catch (error) {
    console.error('Error loading domain details:', error);
    showError('<%= __('Failed to load domain details') %>');
  }
}

// Render domain header
function renderDomainHeader(domain, tags) {
  document.getElementById('domain-name').textContent = domain.domain;
  document.getElementById('domain-title').textContent = domain.title || '';
  document.getElementById('domain-description').textContent = domain.description || '';

  // Render tags
  const tagsContainer = document.getElementById('domain-tags');
  if (tags && tags.length > 0) {
    tagsContainer.innerHTML = tags.map(tag =>
      `<a href="${BIS_SECTOR_BASE}/${tag.key}" class="badge bg-secondary text-decoration-none me-1">${tag.display_name || tag.key}</a>`
    ).join('');
  }

  // Render score display as circular ring
  const scoreColor = getScoreColor(domain.score);
  const colorMap = {
    'success': '#198754',
    'info': '#0dcaf0',
    'warning': '#ffc107',
    'danger': '#dc3545'
  };
  const color = colorMap[scoreColor] || '#6c757d';

  // Calculate circle parameters
  const radius = 45;
  const circumference = 2 * Math.PI * radius;
  const offset = circumference - (domain.score / 100) * circumference;

  document.getElementById('domain-score-display').innerHTML = `
    <div style="position: relative; width: 120px; height: 120px; margin-left: auto;"
         role="progressbar"
         aria-label="<%= __('Compliance score') %>"
         aria-valuenow="${domain.score}"
         aria-valuemin="0"
         aria-valuemax="100">
      <svg width="120" height="120" style="transform: rotate(-90deg);" aria-hidden="true">
        <!-- Background circle -->
        <circle cx="60" cy="60" r="${radius}"
                fill="none" stroke="#e9ecef" stroke-width="10"/>
        <!-- Progress circle -->
        <circle cx="60" cy="60" r="${radius}"
                fill="none" stroke="${color}" stroke-width="10"
                stroke-dasharray="${circumference}"
                stroke-dashoffset="${offset}"
                stroke-linecap="round"/>
      </svg>
      <div style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); text-align: center;" aria-hidden="true">
        <div style="font-size: 1.8rem; font-weight: bold; color: ${color};">${domain.score}%</div>
        <small class="text-muted" style="font-size: 0.7rem;">${domain.compliant_checks}/${domain.total_checks}</small>
      </div>
    </div>
  `;
}

// Render compliance overview cards
function renderComplianceOverview(domain) {
  // Overall score
  const scoreColor = getScoreColor(domain.score);
  document.getElementById('overall-score').innerHTML = `
    <span class="text-${scoreColor}">${domain.score}%</span>
  `;

  // BIS Badge
  const badgeDisplay = document.getElementById('bis-badge-display');
  if (domain.has_bis_badge) {
    badgeDisplay.innerHTML = '<span class="badge bg-primary mt-2">🏆 <%= __('BIS Badge') %></span>';
  } else {
    badgeDisplay.innerHTML = '';
  }

  // A/AAAA Records - combined status (compliant only if both are compliant or null)
  const aCompliant = domain.a_compliant === null || domain.a_compliant;
  const aaaaCompliantCheck = domain.aaaa_compliant === null || domain.aaaa_compliant;
  const aaaaCompliant = aCompliant && aaaaCompliantCheck;
  const hasAorAAAA = domain.a_compliant !== null || domain.aaaa_compliant !== null;
  renderRecordStatus('a-record', hasAorAAAA ? aaaaCompliant : null);

  // MX Records
  renderRecordStatus('mx-record', domain.mx_compliant);

  // NS Records
  renderRecordStatus('ns-record', domain.ns_compliant);
}

// Render individual record type status
function renderRecordStatus(prefix, compliant) {
  const statusElement = document.getElementById(`${prefix}-status`);

  if (compliant === null || compliant === undefined) {
    statusElement.innerHTML = '<span class="text-muted">-</span>';
  } else if (compliant) {
    statusElement.innerHTML = '<span class="text-success">✓</span>';
  } else {
    statusElement.innerHTML = '<span class="text-danger">✗</span>';
  }
}

// Render checks table
function renderChecksTable(checks) {
  const tbody = document.querySelector('#checks-table tbody');

  if (!checks || checks.length === 0) {
    tbody.innerHTML = '<tr><td colspan="8" class="text-center text-muted"><%= __('No check data available') %></td></tr>';
    return;
  }

  tbody.innerHTML = checks.map(check => {
    const statusBadge = check.is_compliant
      ? '<span class="badge bg-success">✓ <%= __('Swedish') %></span>'
      : '<span class="badge bg-danger">✗ <%= __('Foreign') %></span>';

    const countryFlag = check.country_code ? getFlagEmoji(check.country_code) : '';

    return `
      <tr>
        <td><span class="badge bg-secondary">${check.record_type}</span></td>
        <td><code>${check.record_value || '-'}</code></td>
        <td><code>${check.ip_address || '-'}</code></td>
        <td>${countryFlag} ${check.country_code || '-'}</td>
        <td>${check.asn ? `AS${check.asn}` : '-'}</td>
        <td><small>${check.as_name || '-'}</small></td>
        <td><small>${check.hosting_provider || '-'}</small></td>
        <td>${statusBadge}</td>
      </tr>
    `;
  }).join('');

  // Count records by type
  const counts = {
    A: checks.filter(c => c.record_type === 'A').length,
    AAAA: checks.filter(c => c.record_type === 'AAAA').length,
    MX: checks.filter(c => c.record_type === 'MX').length,
    NS: checks.filter(c => c.record_type === 'NS').length
  };

  const totalA = counts.A + counts.AAAA;
  document.getElementById('a-record-count').textContent = totalA > 0
    ? `${counts.A} A + ${counts.AAAA} AAAA`
    : '<%= __('No A/AAAA records') %>';
  document.getElementById('mx-record-count').textContent = counts.MX > 0 ? `${counts.MX} <%= __('record(s)') %>` : '<%= __('No MX records') %>';
  document.getElementById('ns-record-count').textContent = `${counts.NS} <%= __('record(s)') %>`;
}

// Render provider summary
function renderProviderSummary(checks) {
  const container = document.getElementById('provider-summary');

  if (!checks || checks.length === 0) {
    container.innerHTML = '<p class="text-muted"><%= __('No provider data available') %></p>';
    return;
  }

  // Count providers
  const providerCounts = {};
  const providerCompliance = {};

  checks.forEach(check => {
    const provider = check.hosting_provider || '<%= __('Unknown') %>';
    providerCounts[provider] = (providerCounts[provider] || 0) + 1;

    if (!providerCompliance[provider]) {
      providerCompliance[provider] = {
        total: 0,
        compliant: 0,
        country: check.country_code
      };
    }

    providerCompliance[provider].total++;
    if (check.is_compliant) {
      providerCompliance[provider].compliant++;
    }
  });

  // Sort by count
  const sorted = Object.entries(providerCounts).sort((a, b) => b[1] - a[1]);

  container.innerHTML = `
    <div class="row">
      ${sorted.map(([provider, count]) => {
        const stats = providerCompliance[provider];
        const rate = formatNumber((stats.compliant / stats.total) * 100, 0);
        const badgeColor = stats.compliant === stats.total ? 'success' : 'danger';
        const flag = stats.country ? getFlagEmoji(stats.country) : '';

        return `
          <div class="col-md-4 mb-3">
            <div class="card border-${badgeColor}">
              <div class="card-body">
                <h6 class="card-subtitle mb-2">${flag} ${provider}</h6>
                <p class="card-text">
                  <strong>${count}</strong> <%= __('record(s)') %><br>
                  <span class="text-${badgeColor}">${rate}% <%= __('compliant') %></span>
                </p>
              </div>
            </div>
          </div>
        `;
      }).join('')}
    </div>
  `;
}

// Get score color
function getScoreColor(score) {
  if (score === 100) return 'success';
  if (score >= 75) return 'info';
  if (score >= 50) return 'warning';
  return 'danger';
}

// Get flag emoji for country code
function getFlagEmoji(countryCode) {
  if (!countryCode || countryCode.length !== 2) return '';

  const codePoints = countryCode
    .toUpperCase()
    .split('')
    .map(char => 127397 + char.charCodeAt());

  return String.fromCodePoint(...codePoints);
}

// Show error message
function showError(message) {
  const container = document.querySelector('.container-fluid');
  const alert = document.createElement('div');
  alert.className = 'alert alert-danger alert-dismissible fade show';
  alert.innerHTML = `
    ${message}
    <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
  `;
  container.insertBefore(alert, container.firstChild);
}

// Navigate to prev/next domain (AJAX)
async function getDomain(to, domain) {
  // Nav route still uses Accept header for content negotiation
  const url = `${BIS_DOMAIN_BASE}/${domain}/${to}`;

  try {
    const response = await fetch(url, {
      headers: { 'Accept': 'application/json' }
    });

    if (!response.ok) {
      if (response.status === 404) {
        showError('<%= __('No more domains in this direction') %>');
      } else {
        throw new Error('<%= __('Failed to load domain') %>');
      }
      return false;
    }

    const data = await response.json();

    // Ensure numeric fields are numbers
    if (data.domain) {
      data.domain.score = parseFloat(data.domain.score) || 0;
      data.domain.compliant_checks = parseInt(data.domain.compliant_checks) || 0;
      data.domain.total_checks = parseInt(data.domain.total_checks) || 0;
    }

    // Update the page content
    renderDomainHeader(data.domain, data.tags);
    renderComplianceOverview(data.domain);
    renderChecksTable(data.checks);
    renderProviderSummary(data.checks);

    // Update navigation buttons
    bindNavigation(data.domain.domain);

    // Update browser history and URL
    const newUrl = `${BIS_DOMAIN_BASE}/${data.domain.domain}`;
    history.pushState({ domain: data.domain.domain }, '', newUrl);

    // Update page title
    document.title = `<%= __('BIS Check') %>: ${data.domain.domain}`;

    // Update H1 heading
    const headline = document.getElementById('headline');
    if (headline) {
      headline.textContent = `<%= __('BIS Check') %>: ${data.domain.domain}`;
    }

    return true;

  } catch (error) {
    console.error('Navigation error:', error);
    showError('<%= __('Failed to navigate') %>');
    return false;
  }
}

// Bind navigation buttons
function bindNavigation(currentDomain) {
  const prevButton = document.getElementById('prevdomain');
  const nextButton = document.getElementById('nextdomain');

  if (prevButton) {
    prevButton.onclick = () => getDomain('prev', currentDomain);
    prevButton.style.cursor = 'pointer';
  }

  if (nextButton) {
    nextButton.onclick = () => getDomain('next', currentDomain);
    nextButton.style.cursor = 'pointer';
  }
}

// Initialize navigation on page load
async function initializePage() {
  await loadDomainDetails();

  // Bind navigation buttons after initial load
  const pathParts = window.location.pathname.split('/');
  const domain = pathParts[pathParts.length - 1];
  bindNavigation(domain);
}

// Load on page load
initializePage();
