// BIS Manager JavaScript
// URL patterns - HTML routes for navigation, API routes for data
const BIS_INDEX_URL = '<%= url_for('bis_index') %>';
const BIS_MANAGER_API = '<%= url_for('BIS.manager.index') %>';
const BIS_RUNS_API = '<%= url_for('BIS.runs.index') %>';
const BIS_RUNS_START_API = '<%= url_for('BIS.runs.start') %>';
const LOCALE = '<%= stash('language') || 'en' %>';

// Format number with locale-specific decimal separator
function formatNumber(num, decimals = 1) {
  return num.toLocaleString(LOCALE, {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals
  });
}

// Load manager dashboard
async function loadManagerDashboard() {
  try {
    const response = await fetch(BIS_MANAGER_API);

    if (!response.ok) throw new Error('Failed to load manager data');

    const data = await response.json();

    renderSectorStats(data.sector_stats);
    renderRunsTable(data.recent_runs);

  } catch (error) {
    console.error('Error loading manager dashboard:', error);
    showError('Failed to load manager data');
  }
}

// Render sector statistics
function renderSectorStats(sectors) {
  const container = document.getElementById('sector-stats');

  if (!sectors || sectors.length === 0) {
    container.innerHTML = '<div class="col-12"><p class="text-muted">No data available</p></div>';
    return;
  }

  container.innerHTML = sectors.map(sector => {
    const complianceRate = parseFloat(sector.compliance_rate) || 0;
    const avgScore = parseFloat(sector.avg_score) || 0;
    const cardColor = complianceRate >= 75 ? 'success' : complianceRate >= 50 ? 'warning' : 'danger';

    return `
      <div class="col-md-6 col-lg-3 mb-3">
        <div class="card border-${cardColor}">
          <div class="card-body">
            <h6 class="card-subtitle mb-2 text-muted">${sector.display_name}</h6>
            <h2 class="card-title text-${cardColor}">${formatNumber(complianceRate)}%</h2>
            <p class="card-text">
              <small>${sector.compliant_domains}/${sector.total_domains} compliant</small><br>
              <small>Avg score: ${formatNumber(avgScore)}</small>
            </p>
          </div>
        </div>
      </div>
    `;
  }).join('');
}

// Render recent runs table
function renderRunsTable(runs) {
  const tbody = document.querySelector('#runs-table tbody');

  if (!runs || runs.length === 0) {
    tbody.innerHTML = '<tr><td colspan="7" class="text-center text-muted">No runs found</td></tr>';
    return;
  }

  tbody.innerHTML = runs.map(run => {
    const startedAt = run.started_at ? new Date(run.started_at).toLocaleString() : '-';
    const completedAt = run.completed_at ? new Date(run.completed_at).toLocaleString() : '-';
    const statusBadge = getStatusBadge(run.status);

    // Get statistics from nested object
    const stats = run.statistics || {};
    const domainsChecked = run.domains_checked || stats.total_domains || 0;
    const compliantCount = stats.compliant_domains || 0;
    const badgeCount = compliantCount; // Compliant domains are those with BIS badge

    return `
      <tr>
        <td>${run.id}</td>
        <td><small>${startedAt}</small></td>
        <td><small>${completedAt}</small></td>
        <td>${statusBadge}</td>
        <td>${domainsChecked}</td>
        <td>${compliantCount}</td>
        <td>${badgeCount}</td>
      </tr>
    `;
  }).join('');
}

// Get status badge
function getStatusBadge(status) {
  const badges = {
    'pending': '<span class="badge bg-secondary">Pending</span>',
    'running': '<span class="badge bg-primary">Running</span>',
    'completed': '<span class="badge bg-success">Completed</span>',
    'failed': '<span class="badge bg-danger">Failed</span>'
  };
  return badges[status] || '<span class="badge bg-secondary">Unknown</span>';
}

// Start new check run
async function startNewRun() {
  const btn = document.getElementById('start-run-btn');
  btn.disabled = true;
  btn.textContent = 'Starting...';

  try {
    const response = await fetch(BIS_RUNS_START_API, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    });

    if (!response.ok) throw new Error('Failed to start run');

    const data = await response.json();

    if (data.success) {
      showSuccess(`Check run ${data.run_id} started successfully`);

      // Start the actual checking process
      await fetch(`<%== url_for('BIS.runs.check', id => '_ID_') %>`.replace('_ID_', data.run_id), {
        method: 'POST'
      });

      // Reload dashboard to show new run
      setTimeout(() => loadManagerDashboard(), 2000);
    }

  } catch (error) {
    console.error('Error starting run:', error);
    showError('Failed to start check run');
  } finally {
    btn.disabled = false;
    btn.textContent = 'Start New Check Run';
  }
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

// Show success message
function showSuccess(message) {
  const container = document.querySelector('.container-fluid');
  const alert = document.createElement('div');
  alert.className = 'alert alert-success alert-dismissible fade show';
  alert.innerHTML = `
    ${message}
    <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
  `;
  container.insertBefore(alert, container.firstChild);
}

// Event listeners
document.getElementById('start-run-btn').addEventListener('click', startNewRun);

// Load on page load
loadManagerDashboard();
