document.querySelector('#cardcol-<%== $service %> h5.card-header').innerHTML = `<%== __('Cache') %>`;

document.getElementById('purgeCache')?.addEventListener('click', async (e) => {
  e.preventDefault();
  if (!confirm('<%== __("Are you sure you want to purge all cache?") %>')) return;
  const result = await window.authenticatedFetch('<%== url_for("Cache.purge") %>', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ pattern: '*', confirmed: true })
  });
  if (result?.success) {
    window.showToast(result.message || '<%== __("Cache purged") %>');
    location.reload();
  } else {
    window.showToast(result?.error || '<%== __("Failed to purge cache") %>');
  }
});