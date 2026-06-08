(async function() {
  const basePath = window.location.pathname.replace(/\/$/, '');
  const urlParams = new URLSearchParams(window.location.search);
  const form = document.forms.searchadmins;
  const searchInput = form.searchterm;
  let currentPage = parseInt(urlParams.get('page')) || 1;

  // Initialize fields from URL params
  if (urlParams.get('searchterm')) {
    searchInput.value = urlParams.get('searchterm');
  }

  async function loadData() {
    const searchterm = searchInput.value;
    let url = `<%== url_for('Email.admins.index') %>?page=${currentPage}`;
    if (searchterm) url += `&searchterm=${encodeURIComponent(searchterm)}`;

    const data = await window.authenticatedFetch(url);
    if (data) {
      renderData(data.data || []);
      renderPagination(data.pagination || {});
    }
  }

  // Store admin data for modal display
  let adminsData = [];

  function renderData(items) {
    adminsData = items;
    const tbody = document.getElementById('adminsList');
    if (!items.length) {
      tbody.innerHTML = `<tr><td colspan="5" class="text-muted text-center py-3"><%== __('No results found') %></td></tr>`;
      return;
    }

    tbody.innerHTML = items.map((a, idx) => {
      const url = `<%== url_for('email_admin', username => '_USR_') %>`.replace('_USR_', encodeURIComponent(a.username));
      const active = a.active ? '<span class="badge bg-success"><%== __("Yes") %></span>' : '<span class="badge bg-secondary"><%== __("No") %></span>';
      const superadmin = a.superadmin ? '<span class="badge bg-primary"><%== __("Yes") %></span>' : '<span class="badge bg-secondary"><%== __("No") %></span>';
      const domainCount = a.domains?.length || 0;
      const domainBadge = `<a href="#" class="badge ${domainCount > 0 ? 'bg-info' : 'bg-secondary'} text-decoration-none" data-admin-idx="${idx}">${domainCount}</a>`;
      return `<tr>
        <td>${a.username}</td>
        <td>${domainBadge}</td>
        <td>${active}</td>
        <td>${superadmin}</td>
        <td class="text-end">
          <a href="${url}" class="btn btn-sm btn-secondary" data-bs-toggle="modal" data-bs-target="#universalmodal"><%== icon 'pencil-fill', {} %></a>
          <button type="button" class="btn btn-sm btn-danger btn-delete-admin" data-username="${a.username}"><%== icon 'trash-fill', {} %></button>
        </td>
      </tr>`;
    }).join('');
  }

  // Current admin being edited in modal
  let currentModalAdmin = null;
  let allDomains = [];

  // Fetch all domains for search (exclude alias domains)
  async function fetchAllDomains() {
    const data = await window.authenticatedFetch('<%== url_for("Email.domains.index") %>?limit=1000&exclude_alias_domains=1');
    allDomains = data?.data || [];
  }

  // Render managed domains list with remove buttons
  function renderManagedDomains(admin) {
    const list = document.getElementById('domainsList');
    if (!admin.domains?.length) {
      list.innerHTML = '<li class="list-group-item text-muted"><%== __("No domains") %></li>';
      return;
    }
    list.innerHTML = admin.domains.map(d => {
      const href = `<%== url_for('email_domain', domain => '_DOM_') %>`.replace('_DOM_', encodeURIComponent(d.domain));
      return `<li class="list-group-item d-flex justify-content-between align-items-center">
        <a href="${href}">${d.domain}${d.description ? ' <small class="text-muted">- ' + d.description + '</small>' : ''}</a>
        <button type="button" class="btn btn-sm btn-outline-danger btn-remove-domain" data-domain="${d.domain}"><%== icon 'x', {} %></button>
      </li>`;
    }).join('');
  }

  // Filter and render search results
  function renderSearchResults(searchTerm) {
    const results = document.getElementById('domainSearchResults');
    if (!searchTerm) {
      results.innerHTML = '';
      return;
    }
    const managedDomains = new Set((currentModalAdmin?.domains || []).map(d => d.domain));
    const filtered = allDomains
      .filter(d => d.domain.toLowerCase().includes(searchTerm.toLowerCase()) && !managedDomains.has(d.domain))
      .slice(0, 10);
    if (!filtered.length) {
      results.innerHTML = '<li class="list-group-item text-muted"><%== __("No results") %></li>';
      return;
    }
    results.innerHTML = filtered.map(d =>
      `<li class="list-group-item d-flex justify-content-between align-items-center">
        ${d.domain}${d.description ? ' <small class="text-muted">- ' + d.description + '</small>' : ''}
        <button type="button" class="btn btn-sm btn-outline-success btn-add-domain" data-domain="${d.domain}"><%== icon 'plus', {} %></button>
      </li>`
    ).join('');
  }

  // Handle table clicks (domain badges and delete buttons)
  document.getElementById('adminsList').addEventListener('click', async (e) => {
    // Domain badge click - open modal
    const badge = e.target.closest('[data-admin-idx]');
    if (badge) {
      e.preventDefault();
      const idx = parseInt(badge.dataset.adminIdx);
      currentModalAdmin = adminsData[idx];
      document.getElementById('domainSearch').value = '';
      document.getElementById('domainSearchResults').innerHTML = '';
      renderManagedDomains(currentModalAdmin);
      if (!allDomains.length) await fetchAllDomains();
      new bootstrap.Modal(document.getElementById('domainsModal')).show();
      return;
    }

    // Delete admin button click
    const deleteBtn = e.target.closest('.btn-delete-admin');
    if (deleteBtn) {
      const username = deleteBtn.dataset.username;
      if (!confirm(`<%== __("Delete admin") %> ${username}?`)) return;

      const result = await window.authenticatedFetch(
        `<%== url_for('Email.admins.delete', username => '_USR_') %>`.replace('_USR_', encodeURIComponent(username)),
        { method: 'DELETE' }
      );
      if (result?.success) {
        window.showToast(result.message);
        loadData();
      } else {
        window.showToast(result?.error || '<%== __("Failed to delete admin") %>', 'danger');
      }
    }
  });

  // Domain search input
  document.getElementById('domainSearch').addEventListener('input', (e) => {
    renderSearchResults(e.target.value);
  });

  // Handle add/remove domain in modal
  document.getElementById('domainsModal').addEventListener('click', async (e) => {
    const addBtn = e.target.closest('.btn-add-domain');
    if (addBtn && currentModalAdmin) {
      const domain = addBtn.dataset.domain;
      const result = await window.authenticatedFetch(
        `<%== url_for('Email.domain_admins.add', domain => '_DOM_', admin => '_ADM_') %>`.replace('_DOM_', encodeURIComponent(domain)).replace('_ADM_', encodeURIComponent(currentModalAdmin.username)),
        { method: 'POST' }
      );
      if (result?.success) {
        currentModalAdmin.domains = currentModalAdmin.domains || [];
        currentModalAdmin.domains.push({ domain });
        renderManagedDomains(currentModalAdmin);
        document.getElementById('domainSearch').value = '';
        renderSearchResults('');
        loadData(); // Refresh table
      } else {
        window.showToast(result?.error || '<%== __("Failed to add domain") %>', 'danger');
      }
      return;
    }

    const removeBtn = e.target.closest('.btn-remove-domain');
    if (removeBtn && currentModalAdmin) {
      const domain = removeBtn.dataset.domain;
      const result = await window.authenticatedFetch(
        `<%== url_for('Email.domain_admins.remove', domain => '_DOM_', admin => '_ADM_') %>`.replace('_DOM_', encodeURIComponent(domain)).replace('_ADM_', encodeURIComponent(currentModalAdmin.username)),
        { method: 'DELETE' }
      );
      if (result?.success) {
        currentModalAdmin.domains = currentModalAdmin.domains.filter(d => d.domain !== domain);
        renderManagedDomains(currentModalAdmin);
        loadData(); // Refresh table
      } else {
        window.showToast(result?.error || '<%== __("Failed to remove domain") %>', 'danger');
      }
    }
  });

  function renderPagination(p) {
    const nav = document.querySelector('#pagination ul');
    if (!p.pages || p.pages <= 1) {
      nav.innerHTML = '';
      return;
    }

    let html = `<li class="page-item ${p.page <= 1 ? 'disabled' : ''}"><a class="page-link" href="#" data-page="${p.page - 1}">&laquo;</a></li>`;
    for (let i = 1; i <= p.pages; i++) {
      if (i === 1 || i === p.pages || (i >= p.page - 2 && i <= p.page + 2)) {
        html += `<li class="page-item ${i === p.page ? 'active' : ''}"><a class="page-link" href="#" data-page="${i}">${i}</a></li>`;
      } else if (i === p.page - 3 || i === p.page + 3) {
        html += `<li class="page-item disabled"><span class="page-link">...</span></li>`;
      }
    }
    html += `<li class="page-item ${p.page >= p.pages ? 'disabled' : ''}"><a class="page-link" href="#" data-page="${p.page + 1}">&raquo;</a></li>`;
    nav.innerHTML = html;
  }

  // Form submit
  form.addEventListener('submit', (e) => {
    e.preventDefault();
    currentPage = 1;
    loadData();
  });

  // Pagination clicks
  document.getElementById('pagination').addEventListener('click', (e) => {
    const link = e.target.closest('.page-link');
    if (link && !link.parentElement.classList.contains('disabled')) {
      e.preventDefault();
      currentPage = parseInt(link.dataset.page);
      loadData();
    }
  });

  // Reload data when modal closes (keeps current page)
  document.getElementById('universalmodal')?.addEventListener('hidden.bs.modal', () => {
    loadData();
  });

  // Initial load
  loadData();
})();
