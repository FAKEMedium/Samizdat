const groupId = window.location.pathname.split('/').filter(Boolean).pop();
const isNew = groupId === 'new';
const apiUrl = isNew
  ? '<%= url_for("Account.groups.create") %>'
  : `<%= url_for('Account.groups.get', groupid => 0) %>`.replace('/0', '/' + groupId);

async function loadGroup() {
  if (isNew) return;

  const result = await window.authenticatedFetch(apiUrl, { method: 'GET' });
  if (result && result.success) {
    document.getElementById('groupname').value = result.group.groupname || '';

    if (result.members && result.members.length) {
      const list = document.getElementById('membersList');
      let html = '';
      result.members.forEach(m => {
        html += `<li class="list-group-item">
          <a href="/users/${m.useruuid}">${m.displayname || m.username}</a>
        </li>`;
      });
      list.innerHTML = html;
      document.getElementById('membersSection').classList.remove('d-none');
    }
  }
}

document.getElementById('groupForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  const groupname = document.getElementById('groupname').value.trim();
  const method = isNew ? 'POST' : 'PUT';

  const result = await window.authenticatedFetch(apiUrl, {
    method: method,
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'groupname=' + encodeURIComponent(groupname)
  });

  const statusDiv = document.getElementById('saveStatus');
  const alertDiv = statusDiv.querySelector('.alert');
  statusDiv.classList.remove('d-none');

  if (result && result.success) {
    alertDiv.className = 'alert alert-success';
    alertDiv.textContent = '<%= __("Saved") %>';
    if (isNew) {
      setTimeout(() => window.location.href = '<%= url_for("account_group") %>', 1000);
    }
  } else {
    alertDiv.className = 'alert alert-danger';
    alertDiv.textContent = (result && result.error) || '<%= __("Failed to save") %>';
  }
});

loadGroup();
