// Certificate list handler with pagination and search
let currentPage = 1;
let totalPages = 1;
let searchTerm = '';

// Load certificates on page load
loadCertificates();

// Search functionality
document.getElementById('searchButton').addEventListener('click', () => {
  searchTerm = document.getElementById('searchterm').value;
  currentPage = 1;
  loadCertificates();
});

// Enter key in search field
document.getElementById('searchterm').addEventListener('keypress', (e) => {
  if (e.key === 'Enter') {
    searchTerm = e.target.value;
    currentPage = 1;
    loadCertificates();
  }
});

// Load certificates from API
async function loadCertificates() {
  const params = new URLSearchParams({
    page: currentPage,
    limit: 20,
    searchterm: searchTerm
  });

  const data = await window.authenticatedFetch(`${window.location.pathname}?${params}`, {
    method: 'GET'
  });

  if (data) {
    populateTable(data.certificates);
    updatePagination(data.pagination);
  }
}

// Populate the table with certificates
function populateTable(certificates) {
  const tbody = document.querySelector('#certificates tbody');

  if (!certificates || certificates.length === 0) {
    tbody.innerHTML = `
      <tr>
        <td colspan="7" class="text-center"><%== __('No certificates found') %></td>
      </tr>
    `;
    return;
  }

  let snippet = '';
  certificates.forEach(cert => {
    const expiresDate = cert.expires_at ? new Date(cert.expires_at).toLocaleDateString() : '';
    const statusClass = cert.status === 'active' ? 'success' : 'secondary';

    // Check if certificate is expiring soon (within 30 days)
    const daysUntilExpiry = cert.expires_at ? Math.floor((new Date(cert.expires_at) - new Date()) / (1000 * 60 * 60 * 24)) : null;
    const expiryWarning = daysUntilExpiry !== null && daysUntilExpiry < 30 && daysUntilExpiry > 0
      ? `<span class="badge bg-warning ms-2">${daysUntilExpiry} days</span>`
      : daysUntilExpiry !== null && daysUntilExpiry <= 0
      ? `<span class="badge bg-danger ms-2">Expired</span>`
      : '';

    snippet += `
      <tr data-id="${cert.certificateid}">
        <td>${cert.certificateid}</td>
        <td>
          <a href="<%= url_for('certificate_show') %>/${cert.certificateid}">${cert.domain || ''}</a>
        </td>
        <td>${cert.commonname || ''}</td>
        <td>${cert.issuer || ''}</td>
        <td>${expiresDate}${expiryWarning}</td>
        <td>
          <span class="badge bg-${statusClass}">${cert.status || 'unknown'}</span>
        </td>
        <td class="text-end">
          <a href="<%= url_for('certificate_edit') %>/${cert.certificateid}/edit"
             class="btn btn-sm btn-secondary"
             title="<%== __('Edit') %>">
            <%== icon 'pencil-fill' %>
          </a>
          <button data-id="${cert.certificateid}"
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
      if (!confirm('<%== __("Are you sure you want to delete this certificate?") %>')) return;

      const id = btn.getAttribute('data-id');
      await deleteCertificate(id);
    });
  });
}

// Update pagination controls
function updatePagination(pagination) {
  if (!pagination) return;

  currentPage = pagination.page;
  totalPages = pagination.pages;

  const paginationEl = document.getElementById('pagination');
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

  // Page numbers (show max 5 pages)
  let startPage = Math.max(1, currentPage - 2);
  let endPage = Math.min(totalPages, startPage + 4);

  if (startPage > 1) {
    paginationHtml += `
      <li class="page-item">
        <a class="page-link" href="#" data-page="1">1</a>
      </li>
    `;
    if (startPage > 2) {
      paginationHtml += `<li class="page-item disabled"><span class="page-link">...</span></li>`;
    }
  }

  for (let i = startPage; i <= endPage; i++) {
    const active = i === currentPage ? 'active' : '';
    paginationHtml += `
      <li class="page-item ${active}">
        <a class="page-link" href="#" data-page="${i}">${i}</a>
      </li>
    `;
  }

  if (endPage < totalPages) {
    if (endPage < totalPages - 1) {
      paginationHtml += `<li class="page-item disabled"><span class="page-link">...</span></li>`;
    }
    paginationHtml += `
      <li class="page-item">
        <a class="page-link" href="#" data-page="${totalPages}">${totalPages}</a>
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
      loadCertificates();
    });
  });
}

// Delete a certificate
async function deleteCertificate(id) {
  const result = await window.authenticatedFetch(`<%== url_for('certificate_index') %>/${id}`, {
    method: 'DELETE'
  });

  if (result && result.success) {
    showToast('success', '<%== __("Certificate deleted successfully") %>');
    loadCertificates(); // Reload the list
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
  toastContainer.innerHTML = toastHtml;

  const toastEl = toastContainer.querySelector('.toast');
  const toast = new bootstrap.Toast(toastEl);
  toast.show();
}
