// Website show page handler
const websiteid = window.location.pathname.split('/').filter(Boolean).pop();

// Load website data
loadWebsite();

async function loadWebsite() {
  const data = await window.authenticatedFetch(`<%== url_for('Website.get', websiteid => '_ID_') %>`.replace('_ID_', websiteid), {
    method: 'GET'
  });

  if (data && data.website) {
    populateDetails(data.website, data.domains || []);
  }
}

function populateDetails(website, domains) {
  document.getElementById('domainname').textContent = website.domainname || '-';
  document.getElementById('servername').textContent = website.servername || '-';
  document.getElementById('home').textContent = website.home || '-';
  document.getElementById('shell').textContent = website.shell || '-';
  document.getElementById('ip4').textContent = website.ip4 || '<%== __("Server default") %>';
  document.getElementById('ip6').textContent = website.ip6 || '<%== __("Server default") %>';
  document.getElementById('redirecturl').textContent = website.redirecturl || '-';

  const statusEl = document.getElementById('status');
  if (website.active) {
    statusEl.innerHTML = '<span class="badge bg-success"><%== __("Active") %></span>';
  } else {
    statusEl.innerHTML = '<span class="badge bg-secondary"><%== __("Inactive") %></span>';
  }

  // Update edit button href
  document.getElementById('editBtn').href = `<%== url_for('Website.edit', websiteid => '_ID_') %>`.replace('_ID_', websiteid);

  // Populate domains table
  const tbody = document.querySelector('#domainsTable tbody');
  if (!domains || domains.length === 0) {
    tbody.innerHTML = '<tr><td colspan="3" class="text-center"><%== __("No domains") %></td></tr>';
    return;
  }

  let snippet = '';
  domains.forEach(domain => {
    const incertBadge = domain.incert
      ? '<span class="badge bg-success"><%== __("Yes") %></span>'
      : '<span class="badge bg-secondary"><%== __("No") %></span>';
    const primaryBadge = domain.domainid === website.primarydomain
      ? ' <span class="badge bg-primary"><%== __("Primary") %></span>'
      : '';

    snippet += `
      <tr data-domainid="${domain.domainid}">
        <td>${domain.domainname}${primaryBadge}</td>
        <td>${incertBadge}</td>
        <td class="text-end">
          <button class="btn btn-sm btn-outline-primary btn-set-primary" data-id="${domain.domainid}" title="<%== __('Set as primary') %>">
            <%== icon 'star' %>
          </button>
          <button class="btn btn-sm btn-danger btn-delete-domain" data-id="${domain.domainid}" title="<%== __('Delete') %>">
            <%== icon 'trash' %>
          </button>
        </td>
      </tr>
    `;
  });
  tbody.innerHTML = snippet;

  // Attach domain action handlers
  document.querySelectorAll('.btn-set-primary').forEach(btn => {
    btn.addEventListener('click', () => setPrimaryDomain(btn.getAttribute('data-id')));
  });
  document.querySelectorAll('.btn-delete-domain').forEach(btn => {
    btn.addEventListener('click', () => deleteDomain(btn.getAttribute('data-id')));
  });
}

// Delete website
document.getElementById('deleteBtn').addEventListener('click', async () => {
  if (!confirm('<%== __("Are you sure you want to delete this website?") %>')) return;

  const result = await window.authenticatedFetch(`<%== url_for('Website.delete', websiteid => '_ID_') %>`.replace('_ID_', websiteid), {
    method: 'DELETE'
  });

  if (result && result.success) {
    window.location.href = '<%== url_for('website_index') %>';
  }
});

// Add domain
document.getElementById('addDomainBtn').addEventListener('click', async () => {
  const domainname = prompt('<%== __("Enter domain name:") %>');
  if (!domainname) return;

  const result = await window.authenticatedFetch(`<%== url_for('Website.domains.create', websiteid => '_ID_') %>`.replace('_ID_', websiteid), {
    method: 'POST',
    body: JSON.stringify({ domainname: domainname })
  });

  if (result && result.success) {
    loadWebsite();
  }
});

// Set primary domain
async function setPrimaryDomain(domainid) {
  const result = await window.authenticatedFetch(`<%== url_for('Website.primaryDomain', websiteid => '_ID_') %>`.replace('_ID_', websiteid), {
    method: 'PUT',
    body: JSON.stringify({ domainid: parseInt(domainid) })
  });

  if (result && result.success) {
    loadWebsite();
  }
}

// Delete domain
async function deleteDomain(domainid) {
  if (!confirm('<%== __("Are you sure you want to delete this domain?") %>')) return;

  const result = await window.authenticatedFetch(`<%== url_for('Website.domains.delete', websiteid => '_WID_', domainid => '_DID_') %>`.replace('_WID_', websiteid).replace('_DID_', domainid), {
    method: 'DELETE'
  });

  if (result && result.success) {
    loadWebsite();
  }
}
