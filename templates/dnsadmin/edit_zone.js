document.addEventListener('DOMContentLoaded', function () {

  // Helper: Show a Bootstrap toast notification
  function showToast(message) {
    let toastContainer = document.getElementById('toast-container');
    if (!toastContainer) {
      toastContainer = document.createElement('div');
      toastContainer.id = 'toast-container';
      toastContainer.setAttribute('aria-live', 'polite');
      toastContainer.setAttribute('aria-atomic', 'true');
      toastContainer.className = 'position-fixed top-0 end-0 p-3';
      toastContainer.style.zIndex = '1080';
      document.body.appendChild(toastContainer);
    }

    const toastEl = document.createElement('div');
    toastEl.className = 'toast';
    toastEl.setAttribute('role', 'alert');
    toastEl.setAttribute('aria-live', 'assertive');
    toastEl.setAttribute('aria-atomic', 'true');

    toastEl.innerHTML = `
      <div class="toast-header">
        <strong class="me-auto">Notification</strong>
        <small class="text-muted">just now</small>
        <button type="button" class="btn-close" data-bs-dismiss="toast" aria-label="Close"></button>
      </div>
      <div class="toast-body">
        ${message}
      </div>
    `;

    toastContainer.appendChild(toastEl);
    const bsToast = new bootstrap.Toast(toastEl, { delay: 5000 });
    bsToast.show();
    toastEl.addEventListener('hidden.bs.toast', function () {
      toastEl.remove();
    });
  }

  // Get reference to the form element
  const form = document.getElementById('zone-form');
  const path = window.location.pathname;
  const editMatch = path.match(/\/zone\/(\d+)\/edit/);

  // If the URL indicates edit mode (e.g. /dnsadmin/zone/123/edit)
  if (editMatch) {
    const zoneId = editMatch[1];
    form.action = '<%== config->{managerurl} %>dnsadmin/zone/' + zoneId;

    // Insert a hidden _method field to override POST to PUT
    const methodInput = document.createElement('input');
    methodInput.type = 'hidden';
    methodInput.name = '_method';
    methodInput.value = 'put';
    form.appendChild(methodInput);

    // Fetch zone data via AJAX/JSON and populate the form
    fetch('<%== config->{managerurl} %>/dnsadmin/zone/' + zoneId, { headers: { 'Accept': 'application/json' } })
      .then(response => response.json())
      .then(data => {
        if (data.error) {
          showToast(data.error);
        } else {
          document.getElementById('zone-id').value = data.id || zoneId;
          document.getElementById('zone-name').value = data.name || '';
          document.getElementById('zone-kind').value = data.kind || 'Master';
          document.getElementById('form-title').textContent = 'Edit Zone';
        }
      })
      .catch(err => {
        console.error(err);
        showToast('An error occurred while fetching zone data.');
      });
  } else {
    // New zone mode
    form.action = '<%== config->{managerurl} %>/dnsadmin/zone';
    document.getElementById('form-title').textContent = 'New Zone';
  }

  // Handle form submission via AJAX
  form.addEventListener('submit', function(e) {
    e.preventDefault();
    const formData = new FormData(form);
    const action = form.action;
    // If a hidden _method field exists, use its value; otherwise, use form.method
    const method = form.querySelector('input[name="_method"]')
      ? form.querySelector('input[name="_method"]').value
      : form.method;

    fetch(action, {
      method: method.toUpperCase(),
      headers: { 'Accept': 'application/json' },
      body: formData
    })
      .then(response => response.json())
      .then(result => {
        showToast(result.toast || 'Operation completed.');
        if (result.success) {
          // Optionally redirect to the zones index after a short delay
          setTimeout(() => { window.location.href = '<%== config->{managerurl} %>/dnsadmin'; }, 2000);
        }
      })
      .catch(error => {
        console.error(error);
        showToast('An error occurred while processing the request.');
      });
  });
});
