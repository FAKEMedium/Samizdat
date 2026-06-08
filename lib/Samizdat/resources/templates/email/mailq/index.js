(async function() {
  const basePath = window.location.pathname.replace(/\/$/, '');
  const apiBase = '/api/v1/email/mailq';
  const form = document.forms.mailqfilter;
  const tbody = document.getElementById('mailqList');
  const summary = document.getElementById('mailqSummary');

  let allItems = [];

  function compileRe(s) {
    if (!s) return null;
    try { return new RegExp(s); } catch (e) { return null; }
  }

  function currentFilter() {
    return {
      sender:    form.sender.value.trim(),
      recipient: form.recipient.value.trim(),
      queue:     form.queue.value.trim(),
    };
  }

  function applyFilter(items) {
    const f = currentFilter();
    const re = {
      sender:    compileRe(f.sender),
      recipient: compileRe(f.recipient),
      queue:     compileRe(f.queue),
    };
    return items.filter(it => {
      if (re.queue && !re.queue.test(it.queue_name || '')) return false;
      if (re.sender && !re.sender.test(it.sender || '')) return false;
      if (re.recipient) {
        const rcpts = it.recipients || [];
        if (!rcpts.some(r => re.recipient.test((r.address || r) + ''))) return false;
      }
      return true;
    });
  }

  function fmtSize(n) {
    n = Number(n) || 0;
    if (n < 1024) return n + ' B';
    if (n < 1048576) return (n / 1024).toFixed(1) + ' KB';
    return (n / 1048576).toFixed(1) + ' MB';
  }

  function fmtTime(ts) {
    if (!ts) return '';
    return new Date(ts * 1000).toISOString().replace('T', ' ').slice(0, 19);
  }

  function escape(s) {
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  function render(items) {
    if (!items.length) {
      tbody.innerHTML = `<tr><td colspan="7" class="text-muted text-center py-3"><%== __('Queue empty') %></td></tr>`;
      summary.textContent = `0 / ${allItems.length}`;
      return;
    }
    summary.textContent = `${items.length} / ${allItems.length}`;
    tbody.innerHTML = items.map(it => {
      const id = encodeURIComponent(it.queue_id);
      const rcpts = (it.recipients || []).map(r => escape(r.address || r)).join('<br>');
      return `<tr>
        <td><span class="badge bg-secondary">${escape(it.queue_name)}</span></td>
        <td><a href="${basePath}/message/${id}" class="text-decoration-none font-monospace">${escape(it.queue_id)}</a></td>
        <td>${fmtSize(it.message_size)}</td>
        <td class="small">${fmtTime(it.arrival_time)}</td>
        <td>${escape(it.sender)}</td>
        <td class="small">${rcpts}</td>
        <td class="text-end">
          <button class="btn btn-sm btn-warning" data-action="hold" data-id="${escape(it.queue_id)}" title="<%== __('Hold') %>"><%== icon 'pause-fill', {} %></button>
          <button class="btn btn-sm btn-success" data-action="release" data-id="${escape(it.queue_id)}" title="<%== __('Release') %>"><%== icon 'play-fill', {} %></button>
          <button class="btn btn-sm btn-danger"  data-action="delete"  data-id="${escape(it.queue_id)}" title="<%== __('Delete') %>"><%== icon 'trash', {} %></button>
        </td>
      </tr>`;
    }).join('');
  }

  async function loadData() {
    summary.textContent = '<%== __('Loading...') %>';
    const data = await window.authenticatedFetch(apiBase);
    if (data) {
      allItems = data.data || [];
      render(applyFilter(allItems));
    }
  }

  async function rowAction(action, id) {
    const url = action === 'delete'
      ? `${apiBase}/${encodeURIComponent(id)}`
      : `${apiBase}/${encodeURIComponent(id)}/${action}`;
    const method = action === 'delete' ? 'DELETE' : 'POST';
    const res = await window.authenticatedFetch(url, { method });
    if (res && res.success) loadData();
  }

  // Filter form
  form.addEventListener('submit', (e) => {
    e.preventDefault();
    render(applyFilter(allItems));
  });

  // Row action buttons
  tbody.addEventListener('click', (e) => {
    const btn = e.target.closest('button[data-action]');
    if (!btn) return;
    rowAction(btn.dataset.action, btn.dataset.id);
  });

  // Flush
  document.getElementById('btnFlush').addEventListener('click', async () => {
    await window.authenticatedFetch(`${apiBase}/flush`, { method: 'POST' });
    loadData();
  });

  // Purge: dry-run first, then show confirm modal
  const purgeModal = new bootstrap.Modal(document.getElementById('purgeModal'));
  const purgeConfirm = document.getElementById('purgeConfirm');
  const btnPurgeConfirm = document.getElementById('btnPurgeConfirm');
  let pendingPurge = null;

  purgeConfirm.addEventListener('input', () => {
    btnPurgeConfirm.disabled = (purgeConfirm.value !== 'DELETE');
  });

  document.getElementById('btnPurge').addEventListener('click', async () => {
    const f = currentFilter();
    const hasFilter = f.sender || f.recipient || f.queue;
    const body = { filter: f, dry_run: true };
    if (!hasFilter) body.confirm = 'all';
    const res = await window.authenticatedFetch(`${apiBase}/purge`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    if (!res) return;
    if (res.ok === false) {
      document.getElementById('purgeSummary').textContent = res.error || '<%== __('Cannot purge') %>';
      pendingPurge = null;
      btnPurgeConfirm.disabled = true;
    } else {
      const target = hasFilter
        ? `<%== __('matching the filter') %>`
        : `<%== __('the ENTIRE queue') %>`;
      document.getElementById('purgeSummary').textContent =
        `<%== __('About to delete') %> ${res.matched} <%== __('messages') %> (${target}).`;
      pendingPurge = { filter: f, hasFilter };
      purgeConfirm.value = '';
      btnPurgeConfirm.disabled = true;
    }
    purgeModal.show();
  });

  btnPurgeConfirm.addEventListener('click', async () => {
    if (!pendingPurge) return;
    const body = { filter: pendingPurge.filter };
    if (!pendingPurge.hasFilter) body.confirm = 'all';
    const res = await window.authenticatedFetch(`${apiBase}/purge`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    purgeModal.hide();
    if (res) loadData();
  });

  loadData();
})();
