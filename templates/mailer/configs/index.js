(async function () {
  let configs = [];

  async function fetchConfigs() {
    const data = await window.authenticatedFetch('<%== url_for("Mailer.configs") %>');
    if (data) {
      configs = data.configs || [];
      renderConfigs();
    }
  }

  function renderConfigs() {
    const tbody = document.querySelector('#configsTable tbody');

    if (configs.length === 0) {
      tbody.innerHTML = '<tr><td colspan="3" class="text-muted"><%== __("No settings configured") %></td></tr>';
      return;
    }

    let html = '';
    for (const c of configs) {
      html += '<tr data-key="' + c.key + '">'
        + '<td><code>' + c.key + '</code></td>'
        + '<td class="config-value">' + (c.value || '<span class="text-muted">-</span>') + '</td>'
        + '<td class="text-end">'
        + '<button class="btn btn-sm btn-outline-primary edit-btn me-1" title="<%== __("Edit") %>"><%== icon("pencil") %></button>'
        + '<button class="btn btn-sm btn-outline-danger delete-btn" title="<%== __("Delete") %>"><%== icon("trash") %></button>'
        + '</td>'
        + '</tr>';
    }
    tbody.innerHTML = html;
  }

  document.querySelector('#addConfigBtn').addEventListener('click', () => {
    const key = prompt('<%== __("Setting key") %>:');
    if (!key) return;

    const value = prompt('<%== __("Value") %>:');
    if (value === null) return;

    saveConfig(key, value);
  });

  document.querySelector('#configsTable').addEventListener('click', async (e) => {
    const btn = e.target.closest('button');
    if (!btn) return;

    const row = btn.closest('tr');
    const key = row?.dataset.key;
    if (!key) return;

    if (btn.classList.contains('edit-btn')) {
      const current = configs.find(c => c.key === key);
      const value = prompt('<%== __("Value") %> (' + key + '):', current?.value || '');
      if (value === null) return;
      saveConfig(key, value);
    }

    if (btn.classList.contains('delete-btn')) {
      if (!confirm('<%== __("Delete") %> ' + key + '?')) return;
      await deleteConfig(key);
    }
  });

  async function saveConfig(key, value) {
    const result = await window.authenticatedFetch('<%== url_for("Mailer.config.upsert") %>', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ key, value })
    });

    if (result?.success) {
      window.showToast(result.toast, 'success');
      fetchConfigs();
    }
  }

  async function deleteConfig(key) {
    const result = await window.authenticatedFetch('<%== url_for("Mailer.config.delete", key => "_KEY_") %>'.replace('_KEY_', key), {
      method: 'DELETE'
    });

    if (result?.success) {
      window.showToast(result.toast, 'success');
      fetchConfigs();
    }
  }

  fetchConfigs();
})();