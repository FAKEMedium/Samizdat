// BIS Trends page
const LOCALE = '<%= stash('language') || 'en' %>';

// Format number with locale-specific decimal separator
function formatNumber(num, decimals = 1) {
  return num.toLocaleString(LOCALE, {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals
  });
}

let trendsChart = null;
let currentDays = 90;

const loadTrends = async (days = 90) => {
  try {
    const response = await fetch(`<%= url_for('BIS.public.trends') %>?days=${days}`);

    if (!response.ok) throw new Error('Failed to load trends');

    const data = await response.json();

    if (!data.trends || data.trends.length === 0) {
      document.querySelector('#trends-table tbody').innerHTML =
        '<tr><td colspan="6" class="text-center">No trend data available</td></tr>';
      return;
    }

    updateChart(data.trends);
    updateTable(data.trends);
  } catch (error) {
    console.error('Error loading trends:', error);
    document.querySelector('#trends-table tbody').innerHTML =
      '<tr><td colspan="6" class="text-center text-danger">Error loading trends</td></tr>';
  }
};

const updateChart = (trends) => {
  const canvas = document.getElementById('trends-chart');
  const ctx = canvas.getContext('2d');

  // Destroy existing chart if it exists
  if (trendsChart) {
    trendsChart.destroy();
  }

  const dates = trends.map(t => new Date(t.date).toLocaleDateString());
  const overallRates = trends.map(t => parseFloat(t.compliance_rate) || 0);
  const aRates = trends.map(t => parseFloat(t.a_compliance_rate) || 0);
  const mxRates = trends.map(t => parseFloat(t.mx_compliance_rate) || 0);
  const nsRates = trends.map(t => parseFloat(t.ns_compliance_rate) || 0);

  // Simple chart implementation (you may want to use Chart.js or similar)
  // For now, just show the data in the table
  // TODO: Add Chart.js library and implement proper chart
};

const updateTable = (trends) => {
  const tbody = document.querySelector('#trends-table tbody');
  tbody.innerHTML = '';

  trends.forEach(trend => {
    const row = document.createElement('tr');
    const date = new Date(trend.date).toLocaleDateString();

    row.innerHTML = `
      <td>${date}</td>
      <td>${formatNumber(parseFloat(trend.compliance_rate || 0))}%</td>
      <td>${formatNumber(parseFloat(trend.a_compliance_rate || 0))}%</td>
      <td>${formatNumber(parseFloat(trend.mx_compliance_rate || 0))}%</td>
      <td>${formatNumber(parseFloat(trend.ns_compliance_rate || 0))}%</td>
      <td>${formatNumber(parseFloat(trend.avg_score || 0))}</td>
    `;

    tbody.appendChild(row);
  });
};

// Time range buttons
document.querySelectorAll('[data-days]').forEach(btn => {
  btn.addEventListener('click', (e) => {
    document.querySelectorAll('[data-days]').forEach(b => b.classList.remove('active'));
    e.target.classList.add('active');

    const days = parseInt(e.target.dataset.days);
    currentDays = days;
    loadTrends(days);
  });
});

// Initial load
loadTrends(currentDays);
