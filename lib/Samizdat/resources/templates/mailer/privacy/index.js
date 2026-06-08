(async function () {
  const privateId = '<%= $private_id %>';

  async function fetchData() {
    const data = await fetch(`<%== url_for('Mailer.privacy', private_id => '_ID_') %>`.replace('_ID_', privateId), {
      headers: { 'Accept': 'application/json' }
    }).then(r => r.json());
    
    if (data) {
      populate(data);
    }
  }

  function populate(data) {
    const addr = data.address || {};
    const lists = data.lists || [];
    const deliveries = data.deliveries || [];

    // Address info
    let infoHtml = '<dl class="row mb-0">';
    infoHtml += '<dt class="col-sm-3"><%== __("Email") %></dt><dd class="col-sm-9">' + (addr.email || '') + '</dd>';
    if (addr.name) infoHtml += '<dt class="col-sm-3"><%== __("Name") %></dt><dd class="col-sm-9">' + addr.name + '</dd>';
    if (addr.first_name) infoHtml += '<dt class="col-sm-3"><%== __("First name") %></dt><dd class="col-sm-9">' + addr.first_name + '</dd>';
    if (addr.last_name) infoHtml += '<dt class="col-sm-3"><%== __("Last name") %></dt><dd class="col-sm-9">' + addr.last_name + '</dd>';
    infoHtml += '<dt class="col-sm-3"><%== __("Source") %></dt><dd class="col-sm-9">' + (addr.source || '') + '</dd>';
    infoHtml += '<dt class="col-sm-3"><%== __("Created") %></dt><dd class="col-sm-9">' + (addr.created ? new Date(addr.created).toLocaleDateString() : '') + '</dd>';
    infoHtml += '</dl>';
    document.querySelector('#addressInfo').innerHTML = infoHtml;

    // Lists
    let listsHtml = '';
    if (lists.length === 0) {
      listsHtml = '<tr><td colspan="3" class="text-muted"><%== __("Not subscribed to any lists") %></td></tr>';
    } else {
      for (const l of lists) {
        listsHtml += '<tr>'
          + '<td>' + l.name + '</td>'
          + '<td>' + (l.description || '<span class="text-muted">-</span>') + '</td>'
          + '<td>' + (l.subscribed ? new Date(l.subscribed).toLocaleDateString() : '') + '</td>'
          + '</tr>';
      }
    }
    document.querySelector('#listsTable tbody').innerHTML = listsHtml;

    // Deliveries
    let delHtml = '';
    if (deliveries.length === 0) {
      delHtml = '<tr><td colspan="3" class="text-muted"><%== __("No mails received") %></td></tr>';
    } else {
      for (const d of deliveries) {
        const statusClass = d.status === 'sent' ? 'text-success' : (d.status === 'failed' ? 'text-danger' : '');
        delHtml += '<tr>'
          + '<td>' + d.mail_name + '</td>'
          + '<td><span class="' + statusClass + '">' + d.status + '</span></td>'
          + '<td>' + (d.sent ? new Date(d.sent).toLocaleDateString() : '') + '</td>'
          + '</tr>';
      }
    }
    document.querySelector('#deliveriesTable tbody').innerHTML = delHtml;
  }

  document.querySelector('#deleteBtn')?.addEventListener('click', async () => {
    if (!confirm('<%== __("Are you sure you want to delete all your data? This cannot be undone.") %>')) return;

    const result = await fetch(`<%== url_for('Mailer.privacy.delete', private_id => '_ID_') %>`.replace('_ID_', privateId), {
      method: 'POST',
      headers: { 'Accept': 'application/json' }
    }).then(r => r.json());

    if (result?.success) {
      alert('<%== __("Your data has been deleted.") %>');
      window.location.href = '/';
    } else {
      alert(result?.toast || '<%== __("An error occurred") %>');
    }
  });

  fetchData();
})();
