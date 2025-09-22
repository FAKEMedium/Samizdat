// Example list handler with pagination and search
let currentPage = 1;
let totalPages = 1;
let searchTerm = '';

// Load examples on page load
loadExamples();

// Search functionality
document.getElementById('searchButton').addEventListener('click', () => {
  searchTerm = document.getElementById('searchterm').value;
  currentPage = 1;
  loadExamples();
});

// Enter key in search field
document.getElementById('searchterm').addEventListener('keypress', (e) => {
  if (e.key === 'Enter') {
    searchTerm = e.target.value;
    currentPage = 1;
    loadExamples();
  }
});

// Load examples from API
async function loadExamples() {
  const params = new URLSearchParams({
    page: currentPage,
    limit: 20,
    searchterm: searchTerm
  });

  const data = await window.authenticatedFetch(`${window.location.pathname}?${params}`, {
    method: 'GET'
  });

  if (data) {
    populateTable(data.examples);
    updatePagination(data.pagination);
  }
}

// Populate the table with examples
function populateTable(examples) {
  const tbody = document.querySelector('#examples tbody');

  if (!examples || examples.length === 0) {
    tbody.innerHTML = `
      <tr>
        <td colspan="6" class="text-center"><%== __('No examples found') %></td>
      </tr>
    `;
    return;
  }

  let snippet = '';
  examples.forEach(example => {
    const createdDate = example.created ? new Date(example.created).toLocaleDateString() : '';
    const statusClass = example.status === 'active' ? 'success' : 'secondary';

    snippet += `
      <tr data-id="${example.id}">
        <td>${example.id}</td>
        <td>
          <a href="<%= url_for('example_show') %>/${example.id}">${example.title || ''}</a>
        </td>
        <td>${example.description || ''}</td>
        <td>
          <span class="badge bg-${statusClass}">${example.status || 'draft'}</span>
        </td>
        <td>${createdDate}</td>
        <td class="text-end">
          <a href="<%= url_for('admin_example_edit') %>/${example.id}/edit"
             class="btn btn-sm btn-secondary"
             title="<%== __('Edit') %>">
            <%== icon 'pencil-fill' %>
          </a>
          <button data-id="${example.id}"
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
      if (!confirm('<%== __("Are you sure you want to delete this example?") %>')) return;

      const id = btn.getAttribute('data-id');
      await deleteExample(id);
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
      loadExamples();
    });
  });
}

// Delete an example
async function deleteExample(id) {
  const result = await window.authenticatedFetch(`/api/example/${id}`, {
    method: 'DELETE'
  });

  if (result && result.success) {
    showToast('success', '<%== __("Example deleted successfully") %>');
    loadExamples(); // Reload the list
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