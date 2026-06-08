// BIS Providers page
const loadProviders = async () => {
  try {
    const response = await fetch('<%= url_for('BIS.public.providers') %>');

    if (!response.ok) throw new Error('Failed to load providers');

    const data = await response.json();
    const tbody = document.querySelector('#providers-table tbody');
    tbody.innerHTML = '';

    if (!data.providers || data.providers.length === 0) {
      tbody.innerHTML = '<tr><td colspan="6" class="text-center">No provider data available</td></tr>';
      return;
    }

    data.providers.forEach(provider => {
      const row = document.createElement('tr');

      const providerName = provider.provider_name || provider.hosting_provider || 'Unknown';
      const country = provider.country_code || '-';
      const isSwedish = provider.is_swedish ? '<span class="badge bg-success">Yes</span>' : '<span class="badge bg-secondary">No</span>';
      const cloudAct = provider.cloud_act_applies ? '<span class="badge bg-warning text-dark">Yes</span>' : '<span class="badge bg-secondary">No</span>';

      row.innerHTML = `
        <td>${providerName}</td>
        <td>${country}</td>
        <td>${isSwedish}</td>
        <td>${cloudAct}</td>
        <td>${provider.domain_count || 0}</td>
        <td>${provider.total_records || 0}</td>
      `;

      tbody.appendChild(row);
    });
  } catch (error) {
    console.error('Error loading providers:', error);
    const tbody = document.querySelector('#providers-table tbody');
    tbody.innerHTML = '<tr><td colspan="6" class="text-center text-danger">Error loading providers</td></tr>';
  }
};

loadProviders();
