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
    try { addressInput.setSelectionRange(0, 0); } catch (e) {}
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
      // Display emails one per line for readability
      gotoInput.value = (a.goto || '').split(',').map(s => s.trim()).join('\n');
      document.getElementById('active').checked = a.active !== false;
    }
  }

  // Parse goto field: split by comma, newline, or whitespace and clean up
  function parseGoto(value) {
    return value
      .split(/[\s,]+/)
      .map(s => s.trim())
      .filter(s => s && s.includes('@'))
      .join(',');
  }

  // Clear validation state
  function clearValidation() {
    gotoInput.classList.remove('is-invalid');
    document.getElementById('gotoFeedback').textContent = '';
  }

  // Show validation error
  function showError(field, message) {
    field.classList.add('is-invalid');
    const feedback = document.getElementById(field.id + 'Feedback');
    if (feedback) feedback.textContent = message;
  }

  // Clear on input
  gotoInput.addEventListener('input', clearValidation);

  // Form submission
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    clearValidation();

    const formData = {
      address: addressInput.value,
      goto: parseGoto(gotoInput.value),
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
      const error = result?.error || '<%== __("Failed to save alias") %>';
      // Check if error is about goto field
      if (error.toLowerCase().includes('email') || error.toLowerCase().includes('forward') || error.toLowerCase().includes('address')) {
        showError(gotoInput, error);
      } else {
        window.showToast(error, 'danger');
      }
    }
  });

  // Initialize
  if (editingAlias) {
    loadAlias();
  }
})();
