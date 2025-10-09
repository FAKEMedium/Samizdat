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

function getDomains() {
  sendData();
}

function populate(formdata) {
  let domains = formdata.data || [];
  let snippet = '';

  for (const domain of domains) {
    const active = domain.active ? '<span class="badge bg-success"><%== __("Yes") %></span>' : '<span class="badge bg-secondary"><%== __("No") %></span>';
    const mailboxesUrl = '<%== url_for('email_index') %>/domains/' + encodeURIComponent(domain.domain) + '/mailboxes';
    snippet += `
      <tr data-domain="${domain.domain}">
        <td>${domain.domain}</td>
        <td>${domain.description || ''}</td>
        <td><a href="${mailboxesUrl}">${domain.mailboxes || 0}</a></td>
        <td>${domain.quota || 0} MB</td>
        <td>${active}</td>
        <td>
          <button class="btn btn-sm btn-primary" onclick="editDomain('${domain.domain}')"><%== __('Edit') %></button>
          <button class="btn btn-sm btn-danger" onclick="deleteDomain('${domain.domain}')"><%== __('Delete') %></button>
        </td>
      </tr>`;
  }
  document.querySelector('#domains tbody').innerHTML = snippet;
}

// Modal functions
function showDomainModal(domain = null) {
  const modal = new bootstrap.Modal(document.getElementById('domainModal'));
  const form = document.getElementById('domainForm');
  form.reset();
  document.getElementById('domain').readOnly = false;

  if (domain) {
    loadDomain(domain);
  }

  modal.show();
}

async function loadDomain(domain) {
  try {
    const response = await authenticatedFetch('<%== url_for('email_domain', domain => '') %>/' + encodeURIComponent(domain));
    const result = await response.json();

    if (result.success) {
      const d = result.domain;
      document.getElementById('domain').value = d.domain || '';
      document.getElementById('description').value = d.description || '';
      document.getElementById('customerid').value = d.customerid || '';
      document.getElementById('active').checked = d.active || false;
      document.getElementById('domain').readOnly = true;
    }
  } catch (error) {
    showToast('Error loading domain: ' + error.message, 'danger');
  }
}

async function saveDomain() {
  const form = document.getElementById('domainForm');
  const domain = document.getElementById('domain').value;
  const isEdit = document.getElementById('domain').readOnly;

  const data = new FormData(form);

  try {
    const url = '<%== url_for('email_domain', domain => '') %>/' + (isEdit ? encodeURIComponent(domain) : '');

    const response = await authenticatedFetch(url.replace(/\/$/, ''), {
      method: isEdit ? 'PUT' : 'POST',
      body: data
    });

    const result = await response.json();

    if (result.success) {
      showToast(result.message || '<%== __('Domain saved successfully') %>', 'success');
      bootstrap.Modal.getInstance(document.getElementById('domainModal')).hide();
      getDomains();
    } else {
      showToast('Error: ' + (result.error || 'Unknown error'), 'danger');
    }
  } catch (error) {
    showToast('Error saving domain: ' + error.message, 'danger');
  }
}

async function deleteDomain(domain) {
  if (!confirm('<%== __('Are you sure you want to delete this domain?') %>')) return;

  try {
    const response = await authenticatedFetch('<%== url_for('email_domain', domain => '') %>/' + encodeURIComponent(domain), {
      method: 'DELETE'
    });

    const result = await response.json();

    if (result.success) {
      showToast(result.message || '<%== __('Domain deleted successfully') %>', 'success');
      getDomains();
    } else {
      showToast('Error: ' + (result.error || 'Unknown error'), 'danger');
    }
  } catch (error) {
    showToast('Error deleting domain: ' + error.message, 'danger');
  }
}

window.editDomain = showDomainModal;
window.deleteDomain = deleteDomain;

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
document.getElementById('saveDomain').addEventListener('click', saveDomain);

// Load data
getDomains();
