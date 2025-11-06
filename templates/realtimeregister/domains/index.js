// RealtimeRegister domains list
const domainsTable = document.getElementById('domains');
const searchButton = document.getElementById('searchButton');
const searchterm = document.getElementById('searchterm');

function loadDomains(search = '') {
  const url = new URL('<%= url_for('rtr_domains') %>', window.location.origin);
  if (search) url.searchParams.set('search', search);

  fetch(url, {
    headers: { 'Accept': 'application/json' }
  })
  .then(response => response.json())
  .then(data => {
    const tbody = domainsTable.querySelector('tbody');
    tbody.innerHTML = '';

    if (!data.domains || data.domains.length === 0) {
      tbody.innerHTML = '<tr><td colspan="5" class="text-center"><%== __('No domains found') %></td></tr>';
      return;
    }

    data.domains.forEach(domain => {
      const row = document.createElement('tr');
      row.innerHTML = `
        <td><a href="<%= url_for('rtr_domain', domain => '') %>${domain.domainName}">${domain.domainName}</a></td>
        <td><span class="badge bg-${domain.status === 'ok' ? 'success' : 'warning'}">${domain.status || 'N/A'}</span></td>
        <td>${domain.expiryDate || 'N/A'}</td>
        <td>${domain.registrant || 'N/A'}</td>
        <td class="text-end">
          <a href="<%= url_for('rtr_domain', domain => '') %>${domain.domainName}" class="btn btn-sm btn-primary"><%== __('View') %></a>
        </td>
      `;
      tbody.appendChild(row);
    });
  })
  .catch(error => {
    console.error('Error loading domains:', error);
    const tbody = domainsTable.querySelector('tbody');
    tbody.innerHTML = '<tr><td colspan="5" class="text-center text-danger"><%== __('Error loading domains') %></td></tr>';
  });
}

searchButton.addEventListener('click', () => loadDomains(searchterm.value));
searchterm.addEventListener('keypress', (e) => {
  if (e.key === 'Enter') loadDomains(searchterm.value);
});

// Load domains on page load
loadDomains();
