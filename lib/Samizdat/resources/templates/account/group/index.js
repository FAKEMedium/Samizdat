async function loadGroups(page = 1) {
  const result = await window.authenticatedFetch(`<%= url_for('Account.groups.index') %>?page=${page}`, {
    method: 'GET'
  });

  if (result && result.success) {
    const groups = result.groups || [];
    const total = result.total || 0;
    const limit = result.limit || 25;
    const totalPages = Math.ceil(total / limit);

    const tbody = document.querySelector('#groups tbody');
    let html = '';

    groups.forEach(group => {
      html += `<tr>
        <td><a href="<%= url_for('account_group_view', groupid => 0) %>".replace('/0', '/' + group.groupid)>${group.groupname}</a></td>
        <td>${group.member_count || 0}</td>
      </tr>`;
    });

    tbody.innerHTML = html || '<tr><td colspan="2" class="text-muted text-center"><%= __("No groups found") %></td></tr>';
  }
}

loadGroups();
