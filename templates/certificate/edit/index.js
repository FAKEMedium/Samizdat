// Certificate edit form handler
const form = document.getElementById('certificateForm');
const certificateId = window.location.pathname.split('/').filter(p => p && p !== 'edit').pop();
const isNew = certificateId === 'new';

// Handle form submission
form.addEventListener('submit', async (e) => {
  e.preventDefault();

  const formData = new FormData(form);
  const data = {};

  // Convert FormData to object
  for (const [key, value] of formData.entries()) {
    data[key] = value;
  }

  // Handle checkboxes
  data.active = form.querySelector('#active').checked ? 1 : 0;
  data.autorenew = form.querySelector('#autorenew').checked ? 1 : 0;

  const url = isNew
    ? '<%== url_for('certificate_create') %>'
    : `<%== url_for('certificate_index') %>/${certificateId}`;

  const method = isNew ? 'POST' : 'PUT';

  const result = await window.authenticatedFetch(url, {
    method: method,
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams(data)
  });

  if (result && result.success) {
    // Show toast notification
    const toastContainer = document.getElementById('toast-container');
    toastContainer.innerHTML = `<%= $toast %>`;
    const toastEl = toastContainer.querySelector('.toast');
    const toast = new bootstrap.Toast(toastEl);
    toast.show();

    // Redirect after a short delay
    setTimeout(() => {
      if (isNew && result.certificate) {
        window.location.href = `<%== url_for('certificate_show') %>/${result.certificate.certificateid}`;
      } else {
        window.location.href = '<%== url_for('certificate_index') %>';
      }
    }, 1500);
  } else {
    alert('<%== __("Failed to save certificate") %>: ' + (result?.error || 'Unknown error'));
  }
});
