document.querySelector('#cardcol-<%== $service %> h5.card-header').innerHTML = `<%== __('Mailer') %>`;

(function () {
  const form = document.forms.searchmailer;
  if (!form) return;

  const searchBtn = form.querySelector('[name="searchBtn"]');
  const searchTerm = form.querySelector('[name="searchterm"]');

  async function doSearch() {
    const term = searchTerm.value.trim();
    const what = form.querySelector('[name="searchwhat"]:checked')?.value || 'mail';

    let url;
    switch (what) {
      case 'mail':
        url = `<%== url_for('Mailer.search') %>?q=${encodeURIComponent(term)}&type=mail`;
        break;
      case 'address':
        url = `<%== url_for('Mailer.search') %>?q=${encodeURIComponent(term)}&type=address`;
        break;
      case 'bounce':
        url = `<%== url_for('Mailer.search') %>?q=${encodeURIComponent(term)}&type=bounce`;
        break;
    }

    const data = await window.authenticatedFetch(url);
    if (data?.results) {
      displayResults(data.results, what);
    }
  }

  function displayResults(results, type) {
    // Display search results in modal or inline
    if (results.length === 0) {
      window.showToast('<%== __("No results found") %>', 'warning');
      return;
    }

    if (results.length === 1) {
      // Navigate directly to single result
      const r = results[0];
      switch (type) {
        case 'mail':
          window.location.href = `<%== url_for('mailer_show', mailid => '_ID_') %>`.replace('_ID_', r.mailid);
          break;
        case 'address':
          window.location.href = `<%== url_for('mailer_addresses') %>?email=${encodeURIComponent(r.email)}`;
          break;
        case 'bounce':
          window.location.href = `<%== url_for('mailer_bounces') %>?email=${encodeURIComponent(r.email)}`;
          break;
      }
    } else {
      // Show results count and first few
      window.showToast(`<%== __("Found") %> ${results.length} <%== __("results") %>`, 'info');
    }
  }

  searchBtn?.addEventListener('click', doSearch);
  searchTerm?.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      doSearch();
    }
  });

  // Load edit form in modal via AJAX
  async function openMailModal(url) {
    try {
      const response = await fetch(url, {
        method: 'GET',
        headers: {
          'Accept': 'text/html',
          'X-Requested-With': 'XMLHttpRequest'
        }
      });
      const body = await response.text();

      const modalDialog = document.querySelector('#modalDialog');
      modalDialog.innerHTML = body;

      // Extract and execute modal script
      const modalscript = modalDialog.querySelector('#modalscript');
      if (modalscript) {
        const blob = new Blob([modalscript.innerHTML], { type: 'application/javascript' });
        const blobUrl = URL.createObjectURL(blob);
        const script = document.createElement('script');
        script.id = 'modaljs';
        script.src = blobUrl;
        script.onload = () => URL.revokeObjectURL(blobUrl);
        modalDialog.appendChild(script);
        modalscript.remove();
      }

      const modal = bootstrap.Modal.getOrCreateInstance(document.querySelector('#universalmodal'));
      modal.show();
    } catch (e) {
      console.error('Error loading mail modal:', e);
    }
  }

  // New mail button opens modal
  const newMailBtn = document.querySelector('#newMailBtn');
  newMailBtn?.addEventListener('click', (e) => {
    e.preventDefault();
    openMailModal(newMailBtn.href);
  });
})();
