// Website list handler with pagination and search
let currentPage = 1;
let totalPages = 1;
let searchTerm = '';

// Load websites on page load
loadWebsites();

// Search functionality
document.getElementById('searchButton').addEventListener('click', () => {
  searchTerm = document.getElementById('searchterm').value;
  currentPage = 1;
  loadWebsites();
});

// Enter key in search field
document.getElementById('searchterm').addEventListener('keypress', (e) => {
  if (e.key === 'Enter') {
    searchTerm = e.target.value;
    currentPage = 1;
    loadWebsites();
  }
});

// Load websites from API
async function loadWebsites() {
  const params = new URLSearchParams({
    page: currentPage,
    limit: 20
  });
  if (searchTerm) {
    params.append('searchterm', searchTerm);
  }

  const data = await window.authenticatedFetch(`<%== url_for('Website.index') %>?${params}`, {
    method: 'GET'
  });

  if (data) {
    populateTable(data.websites);
    if (data.pagination) {
      updatePagination(data.pagination);
    }
  }
}

// Populate the table with websites
function populateTable(websites) {
  const tbody = document.querySelector('#websites tbody');

  if (!websites || websites.length === 0) {
    tbody.innerHTML = `
      <tr>
        <td colspan="6" class="text-center"><%== __('No websites found') %></td>
      </tr>
    `;
    return;
  }

  let snippet = '';
  websites.forEach(website => {
    const statusClass = website.active ? 'success' : 'secondary';
    const statusText = website.active ? '<%== __("Active") %>' : '<%== __("Inactive") %>';

    snippet += `
      <tr data-id="${website.websiteid}">
        <td>${website.websiteid}</td>
        <td>
          <a href="${'<%== url_for('website_edit', websiteid => '_ID_') %>'.replace('_ID_', website.websiteid)}">${website.domainname || '<%== __("No domain") %>'}</a>
        </td>
        <td>${website.servername || ''}</td>
        <td><code>${website.home || ''}</code></td>
        <td>
          <span class="badge bg-${statusClass}">${statusText}</span>
        </td>
        <td class="text-end">
          <button data-id="${website.websiteid}"
                  class="btn btn-sm btn-danger btn-delete"
                  title="<%== __('Delete') %>">
            <%== icon 'trash-fill' %>
          </button>
        </td>
      </tr>
    `;
  });

  tbody.innerHTML = snippet;

  // Attach delete handlers
  document.querySelectorAll('.btn-delete').forEach(btn => {
    btn.addEventListener('click', async () => {
      if (!confirm('<%== __("Are you sure you want to delete this website?") %>')) return;

      const id = btn.getAttribute('data-id');
      await deleteWebsite(id);
    });
  });
}

// Update pagination controls
function updatePagination(pagination) {
  if (!pagination) return;

  currentPage = pagination.page;
  totalPages = pagination.pages;

  const paginationEl = document.getElementById('pagination');
  if (!paginationEl) return;

  let paginationHtml = '';

  // Previous button
  if (currentPage > 1) {
    paginationHtml += `
      <li class="page-item">
        <a class="page-link" href="#" data-page="${currentPage - 1}"><%== __('Previous') %></a>
      </li>
    `;
  } else {
    paginationHtml += `
      <li class="page-item disabled">
        <span class="page-link"><%== __('Previous') %></span>
      </li>
    `;
  }

  // Page numbers
  let startPage = Math.max(1, currentPage - 2);
  let endPage = Math.min(totalPages, startPage + 4);

  for (let i = startPage; i <= endPage; i++) {
    const active = i === currentPage ? 'active' : '';
    paginationHtml += `
      <li class="page-item ${active}">
        <a class="page-link" href="#" data-page="${i}">${i}</a>
      </li>
    `;
  }

  // Next button
  if (currentPage < totalPages) {
    paginationHtml += `
      <li class="page-item">
        <a class="page-link" href="#" data-page="${currentPage + 1}"><%== __('Next') %></a>
      </li>
    `;
  } else {
    paginationHtml += `
      <li class="page-item disabled">
        <span class="page-link"><%== __('Next') %></span>
      </li>
    `;
  }

  paginationEl.innerHTML = paginationHtml;

  // Attach click handlers to pagination links
  paginationEl.querySelectorAll('.page-link[data-page]').forEach(link => {
    link.addEventListener('click', (e) => {
      e.preventDefault();
      currentPage = parseInt(link.getAttribute('data-page'));
      loadWebsites();
    });
  });
}

// Delete a website
async function deleteWebsite(id) {
  const result = await window.authenticatedFetch(`<%== url_for('Website.delete', websiteid => '_ID_') %>`.replace('_ID_', id), {
    method: 'DELETE'
  });

  if (result && result.success) {
    showToast('success', '<%== __("Website deleted successfully") %>');
    loadWebsites();
  }
}

// Show toast notification
function showToast(type, message) {
  const toastHtml = `
    <div class="toast align-items-center text-white bg-${type === 'success' ? 'success' : 'danger'} border-0"
         role="alert"
         aria-live="assertive"
         aria-atomic="true"
         data-bs-autohide="true"
         data-bs-delay="3000">
      <div class="d-flex">
        <div class="toast-body">
          ${message}
        </div>
        <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast"></button>
      </div>
    </div>
  `;

  const toastContainer = document.getElementById('toast-messages');
  if (toastContainer) {
    toastContainer.innerHTML = toastHtml;
    const toastEl = toastContainer.querySelector('.toast');
    const toast = new bootstrap.Toast(toastEl);
    toast.show();
  }
}
