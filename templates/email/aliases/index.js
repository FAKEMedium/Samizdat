async function sendData() {
  const request = {
    method: 'GET',
    headers: {Accept: 'application/json'}
  };
  try {
    const response = await fetch(window.location, request);
    if (!response.ok) {
      if (response.status === 401) {
        const data = await response.json();
        if (window.handle401Error) {
          window.handle401Error(data.error || '<%== __("Authentication required") %>');
        } else {
          window.location.href = '<%== url_for('account_login') %>';
        }
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
    const response = await authenticatedFetch('<%== url_for('email_alias', address => '') %>/' + encodeURIComponent(address));
    const result = await response.json();

    if (result.success) {
      const a = result.alias;
      document.getElementById('address').value = a.address || '';
      document.getElementById('goto').value = a.goto || '';
      document.getElementById('alias_active').checked = a.active || false;
      document.getElementById('address').readOnly = true;
    }
  } catch (error) {
    showToast('Error loading alias: ' + error.message, 'danger');
  }
}

async function saveAlias() {
  const form = document.getElementById('aliasForm');
  const address = document.getElementById('address').value;
  const isEdit = document.getElementById('address').readOnly;

  const data = new FormData(form);

  try {
    const url = '<%== url_for('email_alias', address => '') %>/' + (isEdit ? encodeURIComponent(address) : '');

    const response = await authenticatedFetch(url.replace(/\/$/, ''), {
      method: isEdit ? 'PUT' : 'POST',
      body: data
    });

    const result = await response.json();

    if (result.success) {
      showToast(result.message || '<%== __('Alias saved successfully') %>', 'success');
      bootstrap.Modal.getInstance(document.getElementById('aliasModal')).hide();
      getAliases();
    } else {
      showToast('Error: ' + (result.error || 'Unknown error'), 'danger');
    }
  } catch (error) {
    showToast('Error saving alias: ' + error.message, 'danger');
  }
}

async function deleteAlias(address) {
  if (!confirm('<%== __('Are you sure you want to delete this alias?') %>')) return;

  try {
    const response = await authenticatedFetch('<%== url_for('email_alias', address => '') %>/' + encodeURIComponent(address), {
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
