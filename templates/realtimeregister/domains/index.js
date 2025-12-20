// RealtimeRegister domains list
const domainsTable = document.getElementById('domains');
const searchButton = document.getElementById('searchButton');
const searchterm = document.getElementById('searchterm');
const paginationControls = document.getElementById('pagination-controls');

// Read perpage from cookie, fallback to config default
const pageSize = parseInt(document.cookie.split('; ').find(row => row.startsWith('perpage='))?.split('=')[1]) || <%= $perpage %>;
let currentOffset = 0;
let currentSearch = '';

function renderPagination(pagination) {
  if (!paginationControls) return;

  const totalPages = Math.ceil(pagination.total / pagination.limit);
  const currentPageNum = Math.floor(pagination.offset / pagination.limit);

  paginationControls.innerHTML = '';

  // Previous button
  const prevBtn = document.createElement('button');
  prevBtn.className = 'btn btn-sm btn-outline-primary';
  prevBtn.disabled = currentPageNum === 0;
  prevBtn.innerHTML = '<%== icon "chevron-left" %>';
  prevBtn.addEventListener('click', () => loadDomains(currentSearch, (currentPageNum - 1) * pageSize));
  paginationControls.appendChild(prevBtn);

  // Page info
  const pageInfo = document.createElement('button');
  pageInfo.className = 'btn btn-sm btn-outline-primary';
  pageInfo.disabled = true;
  pageInfo.innerHTML = `<span class="d-none d-md-inline"><%== __('Page') %> </span>${currentPageNum + 1}/${totalPages}`;
  paginationControls.appendChild(pageInfo);

  // Next button
  const nextBtn = document.createElement('button');
  nextBtn.className = 'btn btn-sm btn-outline-primary';
  nextBtn.disabled = currentPageNum >= totalPages - 1;
  nextBtn.innerHTML = '<%== icon "chevron-right" %>';
  nextBtn.addEventListener('click', () => loadDomains(currentSearch, (currentPageNum + 1) * pageSize));
  paginationControls.appendChild(nextBtn);
}

function loadDomains(search = '', offset = 0) {
  currentSearch = search;
  currentOffset = offset;

  const url = new URL('<%= url_for('RTR.domains.index') %>', window.location.origin);
  if (search) url.searchParams.set('search', search);
  url.searchParams.set('limit', pageSize);
  url.searchParams.set('offset', offset);

  fetch(url, {
    headers: { 'Accept': 'application/json' },
    credentials: 'same-origin'
  })
  .then(response => {
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    return response.json();
  })
  .then(data => {
    const tbody = domainsTable.querySelector('tbody');
    tbody.innerHTML = '';

    // API returns { domains: { entities: [...], pagination: {...} } }
    const domainList = data.domains?.entities || [];
    const pagination = data.domains?.pagination;

    if (domainList.length === 0) {
      tbody.innerHTML = '<tr><td colspan="5" class="text-center"><%== __('No domains found') %></td></tr>';
      if (paginationControls) paginationControls.innerHTML = '';
      return;
    }

    domainList.forEach(domain => {
      const row = document.createElement('tr');
      // Status is an array, display all statuses
      const statusBadges = domain.status && domain.status.length > 0
        ? domain.status.map(s => `<span class="badge bg-${s === 'OK' ? 'success' : 'warning'}">${s}</span>`).join(' ')
        : 'N/A';

      // Registrant link
      const registrantLink = domain.registrant
        ? `<a href="<%== url_for('rtr_contacts') %>/${domain.registrant}">${domain.registrant}</a>`
        : 'N/A';

      row.innerHTML = `
        <td><a href="<%== url_for('rtr_domains') %>/${domain.domainName}">${domain.domainName}</a></td>
        <td>${statusBadges}</td>
        <td>${domain.expiryDate ? domain.expiryDate.substring(0, 10) : 'N/A'}</td>
        <td>${registrantLink}</td>
        <td class="text-end">
          <a href="<%== url_for('rtr_domains') %>/${domain.domainName}" class="btn btn-sm btn-primary"><%== __('View') %></a>
        </td>
      `;
      tbody.appendChild(row);
    });

    if (pagination) {
      renderPagination(pagination);
    }
  })
  .catch(error => {
    console.error('Error loading domains:', error);
    const tbody = domainsTable.querySelector('tbody');
    tbody.innerHTML = '<tr><td colspan="5" class="text-center text-danger"><%== __('Error loading domains') %></td></tr>';
    if (paginationControls) paginationControls.innerHTML = '';
  });
}

searchButton.addEventListener('click', () => loadDomains(searchterm.value));
searchterm.addEventListener('keypress', (e) => {
  if (e.key === 'Enter') loadDomains(searchterm.value);
});

// Load domains on page load
loadDomains();
