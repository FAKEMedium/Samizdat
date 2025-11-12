// BIS Domain Detail JavaScript
async function loadDomainDetails() {
  try {
    // Get domain from URL path
    const pathParts = window.location.pathname.split('/');
    const domain = pathParts[pathParts.length - 1];

    const response = await fetch(`/bis/domain/${domain}`, {
      headers: { 'Accept': 'application/json' }
    });

    if (!response.ok) {
      if (response.status === 404) {
        showError('Domain not found');
      } else {
        throw new Error('Failed to load domain details');
      }
      return;
    }

    const data = await response.json();

    renderDomainHeader(data.domain);
    renderComplianceOverview(data.domain);
    renderChecksTable(data.checks);
    renderProviderSummary(data.checks);

  } catch (error) {
    console.error('Error loading domain details:', error);
    showError('Failed to load domain details');
  }
}

// Render domain header
function renderDomainHeader(domain) {
  document.getElementById('domain-name').textContent = domain.domain;
  document.getElementById('domain-title').textContent = domain.title || '';
  document.getElementById('domain-description').textContent = domain.description || '';

  // Render tags
  const tagsContainer = document.getElementById('domain-tags');
  if (domain.tags && domain.tags.length > 0) {
    tagsContainer.innerHTML = domain.tags.map(tag =>
      `<span class="badge bg-secondary me-1">${tag}</span>`
    ).join('');
  }

  // Render score display
  const scoreColor = getScoreColor(domain.score);
  document.getElementById('domain-score-display').innerHTML = `
    <div class="progress" style="height: 30px;">
      <div class="progress-bar bg-${scoreColor}" role="progressbar"
           style="width: ${domain.score}%; font-size: 1.2rem;"
           aria-valuenow="${domain.score}" aria-valuemin="0" aria-valuemax="100">
        ${domain.score}%
      </div>
    </div>
    <small class="text-muted mt-1 d-block">${domain.compliant_checks}/${domain.total_checks} checks passed</small>
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
    badgeDisplay.innerHTML = '<span class="badge bg-primary mt-2">🏆 BIS Badge</span>';
  } else {
    badgeDisplay.innerHTML = '';
  }

  // A Records
  renderRecordStatus('a-record', domain.a_compliant);

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
    tbody.innerHTML = '<tr><td colspan="8" class="text-center text-muted">No check data available</td></tr>';
    return;
  }

  tbody.innerHTML = checks.map(check => {
    const statusBadge = check.is_compliant
      ? '<span class="badge bg-success">✓ Swedish</span>'
      : '<span class="badge bg-danger">✗ Foreign</span>';

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
    MX: checks.filter(c => c.record_type === 'MX').length,
    NS: checks.filter(c => c.record_type === 'NS').length
  };

  document.getElementById('a-record-count').textContent = `${counts.A} record(s)`;
  document.getElementById('mx-record-count').textContent = counts.MX > 0 ? `${counts.MX} record(s)` : 'No MX records';
  document.getElementById('ns-record-count').textContent = `${counts.NS} record(s)`;
}

// Render provider summary
function renderProviderSummary(checks) {
  const container = document.getElementById('provider-summary');

  if (!checks || checks.length === 0) {
    container.innerHTML = '<p class="text-muted">No provider data available</p>';
    return;
  }

  // Count providers
  const providerCounts = {};
  const providerCompliance = {};

  checks.forEach(check => {
    const provider = check.hosting_provider || 'Unknown';
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
        const rate = ((stats.compliant / stats.total) * 100).toFixed(0);
        const badgeColor = stats.compliant === stats.total ? 'success' : 'danger';
        const flag = stats.country ? getFlagEmoji(stats.country) : '';

        return `
          <div class="col-md-4 mb-3">
            <div class="card border-${badgeColor}">
              <div class="card-body">
                <h6 class="card-subtitle mb-2">${flag} ${provider}</h6>
                <p class="card-text">
                  <strong>${count}</strong> record(s)<br>
                  <span class="text-${badgeColor}">${rate}% compliant</span>
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

// Load on page load
loadDomainDetails();
