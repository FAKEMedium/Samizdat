(async function() {
  const basePath = window.location.pathname.replace(/\/$/, '');
  const urlParams = new URLSearchParams(window.location.search);
  const form = document.forms.searchdomains;
  const searchInput = form.searchterm;
  const customerSearch = form.customerSearch;
  const customeridInput = form.customerid;
  let currentPage = parseInt(urlParams.get('page')) || 1;
  let currentCustomer = urlParams.get('customerid') || null;
  let searchTimeout = null;

  // Initialize fields from URL params
  if (urlParams.get('searchterm')) {
    searchInput.value = urlParams.get('searchterm');
  }

  async function loadData() {
    const searchterm = searchInput.value;
    let url = `${basePath}?type=domains&page=${currentPage}`;
    if (searchterm) url += `&searchterm=${encodeURIComponent(searchterm)}`;
    if (currentCustomer) url += `&customerid=${currentCustomer}`;

    const data = await window.authenticatedFetch(url);
    if (data) {
      renderData(data.data || []);
      renderPagination(data.pagination || {});
    }
  }

  function renderData(items) {
    const tbody = document.getElementById('emailsList');
    if (!items.length) {
      tbody.innerHTML = `<tr><td colspan="3" class="text-muted text-center py-3"><%== __('No results found') %></td></tr>`;
      return;
    }

    tbody.innerHTML = items.map(d => {
      const url = `${basePath}/${encodeURIComponent(d.domain)}`;
      return `<tr>
        <td><a href="${url}" class="text-decoration-none">${d.domain}</a></td>
        <td>${d.description || ''}</td>
        <td class="text-end"><a href="${url}" class="btn btn-sm btn-secondary"><%== icon 'pencil-fill', {} %></a></td>
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

  // Customer live search
  customerSearch.addEventListener('input', (e) => {
    const value = e.target.value;
    clearTimeout(searchTimeout);
    if (value.length >= 3) {
      searchTimeout = setTimeout(() => searchCustomers(value), 300);
    } else if (value === '') {
      currentCustomer = null;
      customeridInput.value = '';
      currentPage = 1;
      loadData();
    }
  });

  async function searchCustomers(term) {
    const data = await window.authenticatedFetch(`<%== url_for('Customer.index') %>?simple=1&searchterm=${encodeURIComponent(term)}`);
    if (data && data.customers && data.customers.length > 0) {
      const c = data.customers[0];
      currentCustomer = c.customerid;
      customeridInput.value = c.customerid;
      customerSearch.value = c.name;
      customerSearch.classList.add('is-valid');
      setTimeout(() => customerSearch.classList.remove('is-valid'), 1500);
      currentPage = 1;
      loadData();
    } else {
      customerSearch.classList.add('is-invalid');
      setTimeout(() => customerSearch.classList.remove('is-invalid'), 1500);
    }
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
