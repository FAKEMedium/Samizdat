// RealtimeRegister contacts list
const contactsTable = document.getElementById('contacts');
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
  prevBtn.addEventListener('click', () => loadContacts(currentSearch, (currentPageNum - 1) * pageSize));
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
  nextBtn.addEventListener('click', () => loadContacts(currentSearch, (currentPageNum + 1) * pageSize));
  paginationControls.appendChild(nextBtn);
}

function loadContacts(search = '', offset = 0) {
  currentSearch = search;
  currentOffset = offset;

  const url = new URL('<%= url_for('RTR.contacts.index') %>', window.location.origin);
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
    const tbody = contactsTable.querySelector('tbody');
    tbody.innerHTML = '';

    // API returns { contacts: { entities: [...], pagination: {...} } }
    const contactList = data.contacts?.entities || [];
    const pagination = data.contacts?.pagination;

    if (contactList.length === 0) {
      tbody.innerHTML = '<tr><td colspan="5" class="text-center"><%== __('No contacts found') %></td></tr>';
      if (paginationControls) paginationControls.innerHTML = '';
      return;
    }

    contactList.forEach(contact => {
      const row = document.createElement('tr');
      row.innerHTML = `
        <td><a href="<%== url_for('rtr_contacts') %>/${contact.handle}">${contact.handle}</a></td>
        <td>${contact.name || 'N/A'}</td>
        <td>${contact.organization || 'N/A'}</td>
        <td>${contact.email || 'N/A'}</td>
        <td class="text-end">
          <a href="<%== url_for('rtr_contacts') %>/${contact.handle}" class="btn btn-sm btn-primary"><%== __('View') %></a>
        </td>
      `;
      tbody.appendChild(row);
    });

    if (pagination) {
      renderPagination(pagination);
    }
  })
  .catch(error => {
    console.error('Error loading contacts:', error);
    const tbody = contactsTable.querySelector('tbody');
    tbody.innerHTML = '<tr><td colspan="5" class="text-center text-danger"><%== __('Error loading contacts') %></td></tr>';
    if (paginationControls) paginationControls.innerHTML = '';
  });
}

searchButton.addEventListener('click', () => loadContacts(searchterm.value));
searchterm.addEventListener('keypress', (e) => {
  if (e.key === 'Enter') loadContacts(searchterm.value);
});

// New contact button handler - opens domain contacts form with RR pre-selected
document.getElementById('newContact')?.addEventListener('click', async () => {
  const modalDialog = document.querySelector('#universalmodal #modalDialog');
  if (modalDialog) modalDialog.classList.add('modal-xl');
  await window.openModalFromUrl('<%= url_for('domain_contact_new') %>?registries=rr');
});

// Load contacts on page load
loadContacts();
