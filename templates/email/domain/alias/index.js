async function sendData() {
  const request = {
    method: 'GET',
    headers: {Accept: 'application/json'}
  };
  try {
    const response = await fetch(window.location, request);
    if (!response.ok) {
      if (response.status === 401) {
        // Handled by the global fetch interceptor (apidom.js), which opens the
        // login form in #universalmodal. Don't double-handle it here.
        return;
      } else {
        alert('Request failed: ' + response.statusText);
      }
    } else {
      populate(await response.json());
    }
  } catch (e) {
    console.error('Request error:', e);
    alert('Request failed');
  }
}

function getAliases() {
  sendData();
}

function populate(formdata) {
  let aliases = formdata.data || [];
  let snippet = '';

  for (const alias of aliases) {
    const active = alias.active ? '<span class="badge bg-success"><%== __("Yes") %></span>' : '<span class="badge bg-secondary"><%== __("No") %></span>';
    snippet += `
      <tr data-address="${alias.address}">
        <td>${alias.address}</td>
        <td>${alias.goto || ''}</td>
        <td>${alias.domain || ''}</td>
        <td>${active}</td>
        <td>
          <button class="btn btn-sm btn-primary" onclick="editAlias('${alias.address}')"><%== __('Edit') %></button>
          <button class="btn btn-sm btn-danger" onclick="deleteAlias('${alias.address}')"><%== __('Delete') %></button>
        </td>
      </tr>`;
  }
  document.querySelector('#aliases tbody').innerHTML = snippet;
}

// Modal functions
function showAliasModal(address = null) {
  const modal = new bootstrap.Modal(document.getElementById('aliasModal'));
  const form = document.getElementById('aliasForm');
  form.reset();
  document.getElementById('address').readOnly = false;

  if (address) {
    loadAlias(address);
  }

  modal.show();
}

async function loadAlias(address) {
  try {
    const response = await authenticatedFetch('<%== url_for('Email.aliases.index') %>/' + encodeURIComponent(address));
    const result = await response.json();

    if (result.success) {
      const a = result.alias;
      document.getElementById('address').value = a.address || '';
      // Display emails one per line for readability
      document.getElementById('goto').value = (a.goto || '').split(',').map(s => s.trim()).join('\n');
      document.getElementById('alias_active').checked = a.active || false;
      document.getElementById('address').readOnly = true;
    }
  } catch (error) {
    showToast('Error loading alias: ' + error.message, 'danger');
  }
}

// Parse goto field: split by comma, newline, or whitespace and clean up
function parseGoto(value) {
  return value
    .split(/[\s,]+/)
    .map(s => s.trim())
    .filter(s => s && s.includes('@'))
    .join(',');
}

// Clear validation state
function clearGotoValidation() {
  const gotoField = document.getElementById('goto');
  gotoField.classList.remove('is-invalid');
  document.getElementById('gotoFeedback').textContent = '';
}

// Show validation error on goto field
function showGotoError(message) {
  const gotoField = document.getElementById('goto');
  gotoField.classList.add('is-invalid');
  document.getElementById('gotoFeedback').textContent = message;
}

// Clear validation on input
document.getElementById('goto').addEventListener('input', clearGotoValidation);

async function saveAlias() {
  const form = document.getElementById('aliasForm');
  const address = document.getElementById('address').value;
  const isEdit = document.getElementById('address').readOnly;

  clearGotoValidation();

  const data = new FormData(form);
  // Parse goto field before submission
  data.set('goto', parseGoto(data.get('goto')));

  try {
    const url = isEdit
      ? '<%== url_for('Email.aliases.index') %>/' + encodeURIComponent(address)
      : '<%== url_for('Email.aliases.create') %>';

    const response = await authenticatedFetch(url, {
      method: isEdit ? 'PUT' : 'POST',
      body: data
    });

    const result = await response.json();

    if (result.success) {
      showToast(result.message || '<%== __('Alias saved successfully') %>', 'success');
      bootstrap.Modal.getInstance(document.getElementById('aliasModal')).hide();
      getAliases();
    } else {
      const error = result.error || 'Unknown error';
      // Check if error is about goto field
      if (error.toLowerCase().includes('email') || error.toLowerCase().includes('forward') || error.toLowerCase().includes('address')) {
        showGotoError(error);
      } else {
        showToast('Error: ' + error, 'danger');
      }
    }
  } catch (error) {
    showToast('Error saving alias: ' + error.message, 'danger');
  }
}

async function deleteAlias(address) {
  if (!confirm('<%== __('Are you sure you want to delete this alias?') %>')) return;

  try {
    const response = await authenticatedFetch('<%== url_for('Email.aliases.index') %>/' + encodeURIComponent(address), {
      method: 'DELETE'
    });

    const result = await response.json();

    if (result.success) {
      showToast(result.message || '<%== __('Alias deleted successfully') %>', 'success');
      getAliases();
    } else {
      showToast('Error: ' + (result.error || 'Unknown error'), 'danger');
    }
  } catch (error) {
    showToast('Error deleting alias: ' + error.message, 'danger');
  }
}

window.editAlias = showAliasModal;
window.deleteAlias = deleteAlias;

function showToast(message, type = 'info') {
  const container = document.getElementById('toast-messages');
  const toast = document.createElement('div');
  toast.className = `alert alert-${type} alert-dismissible fade show`;
  toast.setAttribute('role', 'alert');
  toast.innerHTML = `
    ${message}
    <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
  `;
  container.appendChild(toast);

  setTimeout(() => {
    toast.classList.remove('show');
    setTimeout(() => toast.remove(), 150);
  }, 5000);
}

// Set up save button handler
document.getElementById('saveAlias').addEventListener('click', saveAlias);

// Load data
getAliases();
