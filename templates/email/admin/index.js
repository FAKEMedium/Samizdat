(function() {
  const modalDialog = document.querySelector('#modalDialog');
  const sourceUrl = modalDialog?.dataset.sourceUrl || '';
  // URL pattern: /email/admin or /email/admin/:username
  const adminMatch = sourceUrl.match(/\/email\/admin\/([^/]+)$/);
  const editingAdmin = adminMatch ? decodeURIComponent(adminMatch[1]) : null;

  const form = document.getElementById('adminForm');
  const usernameInput = document.getElementById('username');
  const passwordInput = document.getElementById('password');
  const submitBtn = document.getElementById('submitBtn');
  const modalTitle = document.getElementById('modaltitle');

  // Update title and button for edit mode
  if (editingAdmin) {
    modalTitle.textContent = '<%== __("Edit admin") %>';
    submitBtn.textContent = '<%== __("Save changes") %>';
    usernameInput.disabled = true;
    passwordInput.required = false;
    passwordInput.placeholder = '<%== __("Leave blank to keep current") %>';
  }

  // Load existing admin data when editing
  async function loadAdmin() {
    if (!editingAdmin) return;

    const data = await window.authenticatedFetch(`<%== url_for('Email.admins.get', username => '_USR_') %>`.replace('_USR_', encodeURIComponent(editingAdmin)));
    if (data && data.admin) {
      const a = data.admin;
      usernameInput.value = a.username || '';
      document.getElementById('phone').value = a.phone || '';
      document.getElementById('email_other').value = a.email_other || '';
      document.getElementById('superadmin').checked = a.superadmin === true;
      document.getElementById('active').checked = a.active !== false;
    }
  }

  // Form submission
  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    const formData = {
      username: usernameInput.value,
      phone: document.getElementById('phone').value,
      email_other: document.getElementById('email_other').value,
      superadmin: document.getElementById('superadmin').checked,
      active: document.getElementById('active').checked
    };

    // Only include password if provided
    const password = passwordInput.value;
    if (password) {
      formData.password = password;
    }

    let url, method;
    if (editingAdmin) {
      url = `<%== url_for('Email.admins.update', username => '_USR_') %>`.replace('_USR_', encodeURIComponent(editingAdmin));
      method = 'PUT';
    } else {
      url = '<%== url_for('Email.admins.create') %>';
      method = 'POST';
      formData.password = password; // Required for new admin
    }

    const result = await window.authenticatedFetch(url, {
      method: method,
      body: JSON.stringify(formData),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      }
    });

    if (result && result.success) {
      window.showToast(result.message || '<%== __("Admin saved successfully") %>');
      const modal = bootstrap.Modal.getInstance(document.querySelector('#universalmodal'));
      if (modal) modal.hide();
      setTimeout(() => location.reload(), 500);
    } else {
      window.showToast(result?.error || '<%== __("Failed to save admin") %>', 'danger');
    }
  });

  // Initialize
  if (editingAdmin) {
    loadAdmin();
  }
})();
