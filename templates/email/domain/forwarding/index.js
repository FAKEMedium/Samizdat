(function() {
  const modalDialog = document.querySelector('#modalDialog');
  const sourceUrl = modalDialog?.dataset.sourceUrl || '';

  // Extract domain and address from URL: /email/{domain}/alias/{address}
  const pathMatch = sourceUrl.match(/\/email\/([^/]+)\/alias(?:\/([^?]+))?/);
  const domain = pathMatch ? decodeURIComponent(pathMatch[1]) : null;
  const editingAlias = pathMatch && pathMatch[2] ? decodeURIComponent(pathMatch[2]) : null;
  const isNew = !editingAlias;

  const form = document.getElementById('aliasForm');
  const addressInput = document.getElementById('address');
  const gotoInput = document.getElementById('goto');
  const submitBtn = document.getElementById('submitBtn');
  const modalTitle = document.getElementById('modaltitle');

  // Update UI for edit mode
  if (editingAlias) {
    modalTitle.textContent = '<%== __("Edit forwarding") %>';
    submitBtn.textContent = '<%== __("Save changes") %>';
    addressInput.disabled = true;
  } else if (domain) {
    // Pre-fill domain part for new alias
    addressInput.value = '@' + domain;
    addressInput.focus();
    addressInput.setSelectionRange(0, 0);
  }

  // Load existing alias data
  async function loadAlias() {
    if (!editingAlias || !domain) return;

    const data = await window.authenticatedFetch(
      `<%== url_for('Email.aliases.get', domain => '_DOM_', address => '_ADDR_') %>`
        .replace('_DOM_', encodeURIComponent(domain))
        .replace('_ADDR_', encodeURIComponent(editingAlias))
    );

    if (data && data.alias) {
      const a = data.alias;
      addressInput.value = a.address || '';
      gotoInput.value = a.goto || '';
      document.getElementById('active').checked = a.active !== false;
    }
  }

  // Form submission
  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    const formData = {
      address: addressInput.value,
      goto: gotoInput.value,
      active: document.getElementById('active').checked
    };

    let url, method;
    if (editingAlias) {
      url = `<%== url_for('Email.aliases.update', domain => '_DOM_', address => '_ADDR_') %>`
        .replace('_DOM_', encodeURIComponent(domain))
        .replace('_ADDR_', encodeURIComponent(editingAlias));
      method = 'PUT';
    } else {
      url = `<%== url_for('Email.aliases.create', domain => '_DOM_') %>`.replace('_DOM_', encodeURIComponent(domain));
      method = 'POST';
    }

    const result = await window.authenticatedFetch(url, {
      method: method,
      body: JSON.stringify(formData),
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' }
    });

    if (result && result.success) {
      window.showToast(result.message || '<%== __("Alias saved successfully") %>');
      const modal = bootstrap.Modal.getInstance(document.querySelector('#universalmodal'));
      if (modal) modal.hide();
      setTimeout(() => location.reload(), 500);
    } else {
      window.showToast(result?.error || '<%== __("Failed to save alias") %>', 'danger');
    }
  });

  // Initialize
  if (editingAlias) {
    loadAlias();
  }
})();
