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

  function renderData(items) {
    const tbody = document.getElementById('adminsList');
    if (!items.length) {
      tbody.innerHTML = `<tr><td colspan="4" class="text-muted text-center py-3"><%== __('No results found') %></td></tr>`;
      return;
    }

    tbody.innerHTML = items.map(a => {
      const url = `<%== url_for('email_admin', username => '_USR_') %>`.replace('_USR_', encodeURIComponent(a.username));
      const active = a.active ? '<span class="badge bg-success"><%== __("Yes") %></span>' : '<span class="badge bg-secondary"><%== __("No") %></span>';
      const superadmin = a.superadmin ? '<span class="badge bg-primary"><%== __("Yes") %></span>' : '<span class="badge bg-secondary"><%== __("No") %></span>';
      return `<tr>
        <td>${a.username}</td>
        <td>${active}</td>
        <td>${superadmin}</td>
        <td class="text-end"><a href="${url}" class="btn btn-sm btn-secondary" data-bs-toggle="modal" data-bs-target="#universalmodal"><%== icon 'pencil-fill', {} %></a></td>
      </tr>`;
    }).join('');
  }

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
