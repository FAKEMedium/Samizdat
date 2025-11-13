// BIS Sector View JavaScript
// URL patterns from named routes
const BIS_SECTOR_BASE = '<%= url_for('bis_sector', sector => 'PLACEHOLDER') %>'.replace('/PLACEHOLDER', '');
const BIS_DOMAIN_BASE = '<%= url_for('bis_domain', domain => 'PLACEHOLDER') %>'.replace('/PLACEHOLDER', '');

let currentSort = 'score-desc';

async function loadSectorView() {
  try {
    // Get sector from URL path
    const pathParts = window.location.pathname.split('/');
    const sector = pathParts[pathParts.length - 1];

    const response = await fetch(`${BIS_SECTOR_BASE}/${sector}`, {
      headers: { 'Accept': 'application/json' }
    });

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
    renderDomainsTable(data.scores);

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
function renderDomainsTable(scores) {
  const tbody = document.querySelector('#domains-table tbody');

  if (!scores || scores.length === 0) {
    tbody.innerHTML = '<tr><td colspan="8" class="text-center text-muted">No domains found in this sector</td></tr>';

    // Clear stats
    document.getElementById('compliance-rate').textContent = '0%';
    document.getElementById('total-domains').textContent = '0';
    document.getElementById('compliant-domains').textContent = '0';
    document.getElementById('avg-score').textContent = '0';

    return;
  }

  // Calculate statistics
  const total = scores.length;
  const compliant = scores.filter(s => s.has_bis_badge).length;
  const complianceRate = (compliant / total) * 100;
  const avgScore = scores.reduce((sum, s) => sum + parseFloat(s.score || 0), 0) / total;

  // Update stats
  const rateColor = complianceRate >= 75 ? 'success' : complianceRate >= 50 ? 'warning' : 'danger';
  document.getElementById('compliance-rate').innerHTML = `<span class="text-${rateColor}">${complianceRate.toFixed(1)}%</span>`;
  document.getElementById('total-domains').textContent = total;
  document.getElementById('compliant-domains').innerHTML = `<span class="text-success">${compliant}</span>`;
  document.getElementById('avg-score').textContent = avgScore.toFixed(1);

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
          <div class="progress" style="min-width: 60px;">
            <div class="progress-bar bg-${scoreColor}" role="progressbar"
                 style="width: ${score.score}%">${score.score}%</div>
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
