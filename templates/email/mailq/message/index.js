(async function() {
  const apiBase = '/api/v1/email/mailq';
  const id = decodeURIComponent(window.location.pathname.split('/').filter(Boolean).pop());
  const idEl = document.getElementById('mailqId');
  const bodyEl = document.getElementById('mailqBody');

  idEl.textContent = id;

  async function load() {
    bodyEl.textContent = '<%== __('Loading...') %>';
    const res = await window.authenticatedFetch(`${apiBase}/${encodeURIComponent(id)}`);
    if (res && res.success) {
      bodyEl.textContent = res.content || '';
    } else {
      bodyEl.textContent = (res && res.error) || '<%== __('Not found') %>';
    }
  }

  async function action(verb) {
    const url = verb === 'delete'
      ? `${apiBase}/${encodeURIComponent(id)}`
      : `${apiBase}/${encodeURIComponent(id)}/${verb}`;
    const method = verb === 'delete' ? 'DELETE' : 'POST';
    const res = await window.authenticatedFetch(url, { method });
    if (res && res.success) {
      if (verb === 'delete') {
        window.location.href = '<%== url_for('email_mailq_index') %>';
      } else {
        load();
      }
    }
  }

  document.getElementById('btnHold').addEventListener('click', () => action('hold'));
  document.getElementById('btnRelease').addEventListener('click', () => action('release'));
  document.getElementById('btnDelete').addEventListener('click', () => {
    if (confirm('<%== __('Delete this queued message?') %>')) action('delete');
  });

  load();
})();
