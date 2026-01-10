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
      const domainBadge = domainCount > 0
        ? `<a href="#" class="badge bg-info text-decoration-none" data-admin-idx="${idx}">${domainCount}</a>`
        : '<span class="badge bg-secondary">0</span>';
      return `<tr>
        <td>${a.username}</td>
        <td>${domainBadge}</td>
        <td>${active}</td>
        <td>${superadmin}</td>
        <td class="text-end"><a href="${url}" class="btn btn-sm btn-secondary" data-bs-toggle="modal" data-bs-target="#universalmodal"><%== icon 'pencil-fill', {} %></a></td>
      </tr>`;
    }).join('');
  }

  // Handle domain badge clicks
  document.getElementById('adminsList').addEventListener('click', (e) => {
    const badge = e.target.closest('[data-admin-idx]');
    if (badge) {
      e.preventDefault();
      const idx = parseInt(badge.dataset.adminIdx);
      const admin = adminsData[idx];
      if (admin?.domains?.length) {
        const list = document.getElementById('domainsList');
        list.innerHTML = admin.domains.map(d => {
          const href = `<%== url_for('email_domain', domain => '_DOM_') %>`.replace('_DOM_', encodeURIComponent(d.domain));
          return `<a href="${href}" class="list-group-item list-group-item-action">${d.domain}${d.description ? ' <small class="text-muted">- ' + d.description + '</small>' : ''}</a>`;
        }).join('');
        new bootstrap.Modal(document.getElementById('domainsModal')).show();
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

  // Initial load
  loadData();
})();
