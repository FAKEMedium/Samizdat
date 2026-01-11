(function() {
  const modalDialog = document.querySelector('#modalDialog');
  const sourceUrl = modalDialog?.dataset.sourceUrl || '';

  // Extract domain and username from URL: /email/{domain}/mailbox/{username}
  const pathMatch = sourceUrl.match(/\/email\/([^/]+)\/mailbox(?:\/(.+))?$/);
  const domain = pathMatch ? decodeURIComponent(pathMatch[1]) : null;
  const editingMailbox = pathMatch && pathMatch[2] ? decodeURIComponent(pathMatch[2]) : null;
  const isNew = !editingMailbox;

  const form = document.getElementById('mailboxForm');
  const usernameInput = document.getElementById('username');
  const passwordInput = document.getElementById('password');
  const passwordError = document.getElementById('passwordError');
  const submitBtn = document.getElementById('submitBtn');
  const modalTitle = document.getElementById('modaltitle');

  function showError(input, errorEl, message) {
    input.classList.add('is-invalid');
    errorEl.textContent = message;
  }

  function clearError(input, errorEl) {
    input.classList.remove('is-invalid');
    errorEl.textContent = '';
  }

  // Clear error on input
  passwordInput.addEventListener('input', () => clearError(passwordInput, passwordError));

  // Update UI for edit mode
  if (editingMailbox) {
    modalTitle.textContent = '<%== __("Edit mailbox") %>';
    submitBtn.textContent = '<%== __("Save changes") %>';
    usernameInput.disabled = true;
    passwordInput.required = false;
    passwordInput.placeholder = '<%== __("Leave blank to keep current") %>';
  } else if (domain) {
    // Pre-fill domain part for new mailbox
    usernameInput.value = '@' + domain;
    usernameInput.focus();
    try { usernameInput.setSelectionRange(0, 0); } catch (e) {}
  }

  // Load existing mailbox data
  async function loadMailbox() {
    if (!editingMailbox) return;

    const data = await window.authenticatedFetch(
      `<%== url_for('Email.mailboxes.get', domain => '_DOM_', username => '_USR_') %>`
        .replace('_DOM_', encodeURIComponent(domain))
        .replace('_USR_', encodeURIComponent(editingMailbox))
    );

    if (data && data.mailbox) {
      const m = data.mailbox;
      usernameInput.value = m.username || '';
      document.getElementById('name').value = m.name || '';
      document.getElementById('quota').value = m.quota ? Math.floor(m.quota / 1048576) : 1024;
      document.getElementById('active').checked = m.active !== false;
    }
  }

  // Form submission
  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    const formData = {
      username: usernameInput.value,
      name: document.getElementById('name').value,
      quota: document.getElementById('quota').value * 1048576, // Convert MB to bytes
      active: document.getElementById('active').checked
    };

    const password = passwordInput.value;
    if (password) {
      formData.password = password;
    }

    let url, method;
    if (editingMailbox) {
      url = `<%== url_for('Email.mailboxes.update', domain => '_DOM_', username => '_USR_') %>`
        .replace('_DOM_', encodeURIComponent(domain))
        .replace('_USR_', encodeURIComponent(editingMailbox));
      method = 'PUT';
    } else {
      url = `<%== url_for('Email.mailboxes.create', domain => '_DOM_') %>`.replace('_DOM_', encodeURIComponent(domain));
      method = 'POST';
      formData.password = password; // Required for new mailbox
    }

    const result = await window.authenticatedFetch(url, {
      method: method,
      body: JSON.stringify(formData),
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' }
    });

    if (result && result.success) {
      window.showToast(result.message || '<%== __("Mailbox saved successfully") %>');
      const modal = bootstrap.Modal.getInstance(document.querySelector('#universalmodal'));
      if (modal) modal.hide();
    } else {
      const error = result?.error || '<%== __("Failed to save mailbox") %>';
      // Show inline error if password-related
      if (error.toLowerCase().includes('password')) {
        showError(passwordInput, passwordError, error);
      } else {
        window.showToast(error, 'danger');
      }
    }
  });

  // Initialize
  if (editingMailbox) {
    loadMailbox();
  }
})();
