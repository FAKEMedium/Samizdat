// BIS Sector View JavaScript
// URL patterns from named routes
const BIS_SECTOR_API = '<%= url_for('BIS.public.sector', sector => 'PLACEHOLDER') %>'.replace('/PLACEHOLDER', '');
const BIS_SECTOR_BASE = '<%= url_for('bis_sector', sector => 'PLACEHOLDER') %>'.replace('/PLACEHOLDER', '');
const BIS_DOMAIN_BASE = '<%= url_for('bis_domain', domain => 'PLACEHOLDER') %>'.replace('/PLACEHOLDER', '');
const LOCALE = '<%= stash('language') || 'en' %>';

// Format number with locale-specific decimal separator
function formatNumber(num, decimals = 1) {
  return num.toLocaleString(LOCALE, {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals
  });
}

let currentSort = 'score-desc';

async function loadSectorView() {
  try {
    // Get sector from URL path
    const pathParts = window.location.pathname.split('/');
    const sector = pathParts[pathParts.length - 1];

    // Request a high limit to get all domains in the sector
    const response = await fetch(`${BIS_SECTOR_API}/${sector}?limit=10000`);

    if (!response.ok) {
      if (response.status === 404) {
        showError('Sector not found');
      } else {
        throw new Error('Failed to load sector data');
      }
      return;
    }

    const data = await response.json();

    renderSectorHeader(data.sector_info);
    renderDomainsTable(data);

  } catch (error) {
    console.error('Error loading sector view:', error);
    showError('Failed to load sector data');
  }
}

// Render sector header
function renderSectorHeader(sectorInfo) {
  if (!sectorInfo) return;

  document.getElementById('sector-title').textContent = sectorInfo.display_name || '';
  document.getElementById('sector-description').textContent = sectorInfo.description || '';
}

// Render domains table
function renderDomainsTable(data) {
  const tbody = document.querySelector('#domains-table tbody');
  const scores = data.scores || [];
  const total = data.total || 0;

  if (!scores || scores.length === 0) {
    tbody.innerHTML = '<tr><td colspan="8" class="text-center text-muted">No domains found in this sector</td></tr>';

    // Clear stats
    document.getElementById('compliance-rate').textContent = '0%';
    document.getElementById('total-domains').textContent = '0';
    document.getElementById('compliant-domains').textContent = '0';
    document.getElementById('avg-score').textContent = '0';

    return;
  }

  // Calculate statistics - use actual total from API
  const compliant = scores.filter(s => s.has_bis_badge).length;
  const complianceRate = (compliant / total) * 100;
  const avgScore = scores.reduce((sum, s) => sum + parseFloat(s.score || 0), 0) / scores.length;

  // Update stats
  const rateColor = complianceRate >= 75 ? 'success' : complianceRate >= 50 ? 'warning' : 'danger';
  document.getElementById('compliance-rate').innerHTML = `<span class="text-${rateColor}">${formatNumber(complianceRate)}%</span>`;
  document.getElementById('total-domains').textContent = total;
  document.getElementById('compliant-domains').innerHTML = `<span class="text-success">${compliant}</span>`;
  document.getElementById('avg-score').textContent = formatNumber(avgScore);

  // Sort scores
  sortScores(scores);

  // Render table
  tbody.innerHTML = scores.map(score => {
    const scoreColor = getScoreColor(score.score);
    const badge = score.has_bis_badge ? '<span class="badge bg-primary">🏆</span>' : '';

    return `
      <tr>
        <td><a href="${BIS_DOMAIN_BASE}/${score.domain}">${score.domain}</a></td>
        <td>${score.title || '-'}</td>
        <td>
          <div class="d-flex align-items-center">
            <div class="progress flex-grow-1" style="min-width: 60px; height: 20px !important; margin-right: 8px;">
              <div class="progress-bar bg-${scoreColor}" role="progressbar"
                   style="width: ${score.score}%; height: 100%;" aria-valuenow="${score.score}" aria-valuemin="0" aria-valuemax="100"></div>
            </div>
            <span class="text-nowrap" style="min-width: 40px;">${score.score}%</span>
          </div>
        </td>
        <td class="text-center">${getRecordBadge(score.a_compliant)}</td>
        <td class="text-center">${getRecordBadge(score.mx_compliant)}</td>
        <td class="text-center">${getRecordBadge(score.ns_compliant)}</td>
        <td><small>${score.primary_provider || '-'}</small></td>
        <td>${badge}</td>
      </tr>
    `;
  }).join('');
}

// Sort scores array
function sortScores(scores) {
  switch(currentSort) {
    case 'score-desc':
      scores.sort((a, b) => b.score - a.score);
      break;
    case 'score-asc':
      scores.sort((a, b) => a.score - b.score);
      break;
    case 'domain-asc':
      scores.sort((a, b) => a.domain.localeCompare(b.domain));
      break;
    case 'domain-desc':
      scores.sort((a, b) => b.domain.localeCompare(a.domain));
      break;
  }
}

// Get score color
function getScoreColor(score) {
  if (score === 100) return 'success';
  if (score >= 75) return 'info';
  if (score >= 50) return 'warning';
  return 'danger';
}

// Get badge for record compliance
function getRecordBadge(compliant) {
  if (compliant === null || compliant === undefined) {
    return '<span class="badge bg-secondary">-</span>';
  }
  return compliant
    ? '<span class="badge bg-success">✓</span>'
    : '<span class="badge bg-danger">✗</span>';
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

// Set up sort handler
document.getElementById('sort-select').addEventListener('change', (e) => {
  currentSort = e.target.value;
  loadSectorView();
});

// Load on page load
loadSectorView();
