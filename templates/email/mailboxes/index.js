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

function getMailboxes() {
  sendData();
}

function populate(formdata) {
  let mailboxes = formdata.data || [];
  let snippet = '';

  for (const mailbox of mailboxes) {
    const active = mailbox.active ? '<span class="badge bg-success"><%== __("Yes") %></span>' : '<span class="badge bg-secondary"><%== __("No") %></span>';
    snippet += `
      <tr data-username="${mailbox.username}">
        <td>${mailbox.username}</td>
        <td>${mailbox.name || ''}</td>
        <td>${mailbox.domain || ''}</td>
        <td>${mailbox.quota || 0} MB</td>
        <td>${active}</td>
        <td>
          <button class="btn btn-sm btn-primary" onclick="editMailbox('${mailbox.username}')"><%== __('Edit') %></button>
          <button class="btn btn-sm btn-danger" onclick="deleteMailbox('${mailbox.username}')"><%== __('Delete') %></button>
        </td>
      </tr>`;
  }
  document.querySelector('#mailboxes tbody').innerHTML = snippet;
}

// Modal functions
function showMailboxModal(username = null) {
  const modal = new bootstrap.Modal(document.getElementById('mailboxModal'));
  const form = document.getElementById('mailboxForm');
  form.reset();
  document.getElementById('username').readOnly = false;
  document.getElementById('password').required = true;

  if (username) {
    loadMailbox(username);
  }

  modal.show();
}

async function loadMailbox(username) {
  try {
    const response = await authenticatedFetch('<%== url_for('email_mailbox', username => '') %>/' + encodeURIComponent(username));
    const result = await response.json();

    if (result.success) {
      const m = result.mailbox;
      document.getElementById('username').value = m.username || '';
      document.getElementById('name').value = m.name || '';
      document.getElementById('quota').value = m.quota || '';
      document.getElementById('mailbox_active').checked = m.active || false;
      document.getElementById('username').readOnly = true;
      document.getElementById('password').required = false;
    }
  } catch (error) {
    showToast('Error loading mailbox: ' + error.message, 'danger');
  }
}

async function saveMailbox() {
  const form = document.getElementById('mailboxForm');
  const username = document.getElementById('username').value;
  const isEdit = document.getElementById('username').readOnly;

  const data = new FormData(form);

  try {
    const url = '<%== url_for('email_mailbox', username => '') %>/' + (isEdit ? encodeURIComponent(username) : '');

    const response = await authenticatedFetch(url.replace(/\/$/, ''), {
      method: isEdit ? 'PUT' : 'POST',
      body: data
    });

    const result = await response.json();

    if (result.success) {
      showToast(result.message || '<%== __('Mailbox saved successfully') %>', 'success');
      bootstrap.Modal.getInstance(document.getElementById('mailboxModal')).hide();
      getMailboxes();
    } else {
      showToast('Error: ' + (result.error || 'Unknown error'), 'danger');
    }
  } catch (error) {
    showToast('Error saving mailbox: ' + error.message, 'danger');
  }
}

async function deleteMailbox(username) {
  if (!confirm('<%== __('Are you sure you want to delete this mailbox?') %>')) return;

  try {
    const response = await authenticatedFetch('<%== url_for('email_mailbox', username => '') %>/' + encodeURIComponent(username), {
      method: 'DELETE'
    });

    const result = await response.json();

    if (result.success) {
      showToast(result.message || '<%== __('Mailbox deleted successfully') %>', 'success');
      getMailboxes();
    } else {
      showToast('Error: ' + (result.error || 'Unknown error'), 'danger');
    }
  } catch (error) {
    showToast('Error deleting mailbox: ' + error.message, 'danger');
  }
}

window.editMailbox = showMailboxModal;
window.deleteMailbox = deleteMailbox;

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
document.getElementById('saveMailbox').addEventListener('click', saveMailbox);

// Load data
getMailboxes();
