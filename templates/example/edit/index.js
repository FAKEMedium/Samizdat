// Example edit form handler
const exampleId = window.location.pathname.match(/\/(\d+)\/edit/) ?
                  window.location.pathname.match(/\/(\d+)\/edit/)[1] :
                  'new';

// Load existing data if editing
if (exampleId !== 'new') {
  loadExample();
}

// Form submission handler
document.getElementById('exampleForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  await saveExample();
});

// Load example data for editing
async function loadExample() {
  const data = await window.authenticatedFetch(window.location.pathname, {
    method: 'GET'
  });

  if (data && data.example) {
    populateForm(data.example);
  }
}

// Populate form with example data
function populateForm(example) {
  document.getElementById('title').value = example.title || '';
  document.getElementById('description').value = example.description || '';
  document.getElementById('content').value = example.content || '';
  document.getElementById('status').value = example.status || 'draft';
  document.getElementById('category').value = example.category || '';
  document.getElementById('tags').value = Array.isArray(example.tags) ?
                                          example.tags.join(', ') :
                                          (example.tags || '');
  document.getElementById('active').checked = example.active || false;
  document.getElementById('featured').checked = example.featured || false;
  document.getElementById('published').checked = example.published || false;
}

// Save example (create or update)
async function saveExample() {
  const form = document.getElementById('exampleForm');
  const formData = new FormData(form);

  // Convert FormData to object
  const data = {};
  for (const [key, value] of formData.entries()) {
    if (key === 'active' || key === 'featured' || key === 'published') {
      data[key] = form.elements[key].checked ? 1 : 0;
    } else {
      data[key] = value;
    }
  }

  // Determine URL and method
  let url, method;
  if (exampleId === 'new') {
    url = '/api/example';
    method = 'POST';
  } else {
    url = `/api/example/${exampleId}`;
    method = 'PUT';
  }

  const result = await window.authenticatedFetch(url, {
    method: method,
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(data)
  });

  if (result && result.success) {
    showToast('success', result.message || '<%== __("Saved successfully") %>');

    // If creating new, redirect to edit page
    if (exampleId === 'new' && result.example && result.example.id) {
      setTimeout(() => {
        window.location.href = `<%= url_for('admin_example_edit') %>/${result.example.id}/edit`;
      }, 1000);
    }
  }
}

// Show toast notification
function showToast(type, message) {
  const toastContainer = document.getElementById('toast-messages');
  toastContainer.innerHTML = `
<%== web->indent($toast, 1) %>`;

  const toastEl = toastContainer.querySelector('.toast');
  if (toastEl) {
    const toast = new bootstrap.Toast(toastEl);
    toast.show();
  }

  // Auto-hide after a delay
  setTimeout(() => {
    toastContainer.innerHTML = '';
  }, 3000);
}