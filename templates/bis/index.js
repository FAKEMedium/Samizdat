// BIS Dashboard JavaScript
// URL patterns from named routes
const BIS_SCORES_URL = '<%= url_for('BIS.public.scores') %>';
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

let currentPage = 1;
let currentFilter = {
  sector: '',
  compliance: '',
  search: ''
};

// Fetch and display data
async function loadDashboard() {
  try {
    const params = new URLSearchParams({
      limit: 50,
      offset: (currentPage - 1) * 50
    });

    if (currentFilter.sector) {
      params.append('tag', currentFilter.sector);
    }

    if (currentFilter.search) {
      params.append('search', currentFilter.search);
    }

    if (currentFilter.compliance) {
      params.append('compliance', currentFilter.compliance);
    }

    const response = await fetch(`${BIS_SCORES_URL}?${params}`);

    if (!response.ok) throw new Error('<%= __('Failed to load dashboard data') %>');

    const data = await response.json();

    renderSectorStats(data.sector_stats);
    renderDomainsTable(data.scores);
    renderPagination(data.total || data.scores.length);

  } catch (error) {
    console.error('Error loading dashboard:', error);
    showError('<%= __('Failed to load dashboard data') %>');
  }
}

// Render sector statistics cards
function renderSectorStats(sectors) {
  const container = document.getElementById('sector-cards');
  const sectorFilter = document.getElementById('sector-filter');

  if (!sectors || sectors.length === 0) {
    container.innerHTML = '<div class="col-12"><p class="text-muted"><%= __('No data available') %></p></div>';
    return;
  }

  // Populate filter dropdown
  sectors.forEach(sector => {
    const option = document.createElement('option');
    option.value = sector.sector;
    option.textContent = sector.display_name;
    sectorFilter.appendChild(option);
  });

  // Create sector cards
  container.innerHTML = sectors.map(sector => {
    const complianceRate = parseFloat(sector.compliance_rate) || 0;
    const avgScore = parseFloat(sector.avg_score) || 0;
    const cardColor = complianceRate >= 75 ? 'success' : complianceRate >= 50 ? 'warning' : 'danger';

    return `
      <div class="col-md-6 col-lg-3 mb-3">
        <div class="card border-${cardColor}">
          <div class="card-body">
            <h3 class="card-subtitle mb-2 text-muted">${sector.display_name}</h3>
            <h2 class="card-title text-${cardColor}">${formatNumber(complianceRate)}%</h2>
            <p class="card-text">
              <small>${sector.compliant_domains}/${sector.total_domains} <%= __('compliant') %></small><br>
              <small><%= __('Avg score') %>: ${formatNumber(avgScore)}</small>
            </p>
            <a href="${BIS_SECTOR_BASE}/${sector.sector}" class="btn btn-sm btn-outline-${cardColor}"><%= __('View Details') %></a>
          </div>
        </div>
      </div>
    `;
  }).join('');
}

// Render domains table
function renderDomainsTable(scores) {
  const tbody = document.querySelector('#domains-table tbody');

  if (!scores || scores.length === 0) {
    tbody.innerHTML = '<tr><td colspan="8" class="text-center text-muted"><%= __('No domains found') %></td></tr>';
    return;
  }

  tbody.innerHTML = scores.map(score => {
    const scoreColor = getScoreColor(score.score);
    const badge = score.has_bis_badge ? '<span class="badge bg-primary">🏆 BIS</span>' : '';

    return `
      <tr>
        <td><a href="${BIS_DOMAIN_BASE}/${score.domain}">${score.domain}</a></td>
        <td>${score.title || '-'}</td>
        <td>
          <div class="d-flex align-items-center">
            <div class="progress flex-grow-1" style="min-width: 60px; height: 20px !important; margin-right: 8px;">
              <div class="progress-bar bg-${scoreColor}" role="progressbar"
                   aria-label="<%= __('Compliance score') %>"
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

// Get color based on score
function getScoreColor(score) {
  if (score === 100) return 'success';
  if (score >= 75) return 'info';
  if (score >= 50) return 'warning';
  if (score >= 25) return 'warning';
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

// Render pagination
function renderPagination(totalResults) {
  const pagination = document.getElementById('pagination');
  const totalPages = Math.ceil(totalResults / 50);

  if (totalPages <= 1) {
    pagination.innerHTML = '';
    return;
  }

  let html = '';

  // Previous button
  html += `
    <li class="page-item ${currentPage === 1 ? 'disabled' : ''}">
      <a class="page-link" href="#" data-page="${currentPage - 1}"><%= __('Previous') %></a>
    </li>
  `;

  // Page numbers
  for (let i = 1; i <= totalPages; i++) {
    if (i === 1 || i === totalPages || (i >= currentPage - 2 && i <= currentPage + 2)) {
      html += `
        <li class="page-item ${i === currentPage ? 'active' : ''}">
          <a class="page-link" href="#" data-page="${i}">${i}</a>
        </li>
      `;
    } else if (i === currentPage - 3 || i === currentPage + 3) {
      html += '<li class="page-item disabled"><span class="page-link">...</span></li>';
    }
  }

  // Next button
  html += `
    <li class="page-item ${currentPage === totalPages ? 'disabled' : ''}">
      <a class="page-link" href="#" data-page="${currentPage + 1}"><%= __('Next') %></a>
    </li>
  `;

  pagination.innerHTML = html;

  // Add click handlers
  pagination.querySelectorAll('a[data-page]').forEach(link => {
    link.addEventListener('click', (e) => {
      e.preventDefault();
      const page = parseInt(e.target.dataset.page);
      if (page > 0 && page <= totalPages) {
        currentPage = page;
        loadDashboard();
      }
    });
  });
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

// Set up filters
document.getElementById('sector-filter').addEventListener('change', (e) => {
  currentFilter.sector = e.target.value;
  currentPage = 1;
  loadDashboard();
});

document.getElementById('compliance-filter').addEventListener('change', (e) => {
  currentFilter.compliance = e.target.value;
  currentPage = 1;
  loadDashboard();
});

let searchTimeout;
document.getElementById('search-filter').addEventListener('input', (e) => {
  clearTimeout(searchTimeout);
  searchTimeout = setTimeout(() => {
    currentFilter.search = e.target.value;
    currentPage = 1; // Reset to first page when searching
    loadDashboard();
  }, 300);
});

// Load on page load
loadDashboard();
