(async function() {
  const basePath = window.location.pathname.replace(/\/$/, '');
  const pathParts = basePath.split('/');
  const editingDomain = pathParts.length >= 3 ? decodeURIComponent(pathParts[pathParts.length - 1]) : null;
  const isNew = !editingDomain || editingDomain === 'domain';

  const universalModal = new bootstrap.Modal('#universalmodal');
  const modalDialog = document.querySelector('#universalmodal #modalDialog');

  // Form elements
  const form = document.getElementById('domainForm');
  const domainInput = document.getElementById('domain');
  const customeridSelect = document.getElementById('customerid');
  const customerSearch = document.getElementById('customerSearch');
  const isAliasDomainCheck = document.getElementById('isAliasDomain');
  const targetDomainField = document.getElementById('targetDomainField');
  const targetDomainSelect = document.getElementById('targetDomain');
  const submitBtn = document.getElementById('submitBtn');
  const deleteBtn = document.getElementById('deleteBtn');

  // Update UI for edit mode
  if (!isNew) {
    domainInput.disabled = true;
    deleteBtn.style.display = 'inline-block';
    document.getElementById('aliasDomainsSection').style.display = 'block';
    document.getElementById('mailboxesSection').style.display = 'block';
    document.getElementById('aliasesSection').style.display = 'block';
    document.getElementById('domainAdminsSection')?.style.setProperty('display', 'block');
  }

  // Customer search
  let searchTimeout = null;
  customerSearch.addEventListener('input', (e) => {
    const value = e.target.value;
    clearTimeout(searchTimeout);
    if (value.length >= 3) {
      searchTimeout = setTimeout(() => searchCustomers(value), 300);
    }
  });

  async function searchCustomers(term) {
    const data = await window.authenticatedFetch(`<%== url_for('Customer.index') %>?simple=1&searchterm=${encodeURIComponent(term)}`);
    if (data && data.customers) {
      const currentValue = customeridSelect.value;
      customeridSelect.innerHTML = '<option value=""><%== __("Select customer") %></option>';
      data.customers.forEach(c => {
        const opt = document.createElement('option');
        opt.value = c.customerid;
        opt.textContent = c.name;
        if (c.customerid == currentValue) opt.selected = true;
        customeridSelect.appendChild(opt);
      });
    }
  }

  // Toggle alias domain fields
  customeridSelect.addEventListener('change', async () => {
    if (customeridSelect.value && isAliasDomainCheck.checked) {
      await loadCustomerDomains(customeridSelect.value);
    }
  });

  isAliasDomainCheck.addEventListener('change', async () => {
    targetDomainField.style.display = isAliasDomainCheck.checked ? 'block' : 'none';
    if (isAliasDomainCheck.checked && customeridSelect.value) {
      await loadCustomerDomains(customeridSelect.value);
    }
  });

  async function loadCustomerDomains(customerid) {
    const data = await window.authenticatedFetch(`<%== url_for('Email.domains.available_targets') %>?customerid=${customerid}`);
    if (data && data.domains) {
      targetDomainSelect.innerHTML = '<option value=""><%== __("Select target domain") %></option>';
      data.domains.forEach(d => {
        const opt = document.createElement('option');
        opt.value = d.domain;
        opt.textContent = d.domain + (d.description ? ` (${d.description})` : '');
        targetDomainSelect.appendChild(opt);
      });
    }
  }

  // Render alias domains (domains that point to this domain)
  function renderAliasDomains(aliasDomains) {
    const tbody = document.getElementById('aliasDomainsList');
    if (!tbody) return;

    tbody.innerHTML = '';

    if (!aliasDomains || aliasDomains.length === 0) {
      tbody.innerHTML = '<tr><td colspan="2" class="text-muted text-center"><%== __("No alias domains") %></td></tr>';
      return;
    }

    aliasDomains.forEach(a => {
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td>${a.alias_domain}</td>
        <td class="text-end">
          <button class="btn btn-sm btn-danger btn-delete-alias" data-domain="${a.alias_domain}"><%== icon 'trash-fill', {} %></button>
        </td>
      `;
      tbody.appendChild(tr);
    });
  }

  // Load domain data (also includes alias domains that point to this domain)
  async function loadDomain() {
    if (isNew) return;

    const data = await window.authenticatedFetch(`<%== url_for('Email.domains.get', domain => '_DOM_') %>`.replace('_DOM_', encodeURIComponent(editingDomain)));
    if (data && data.domain) {
      const d = data.domain;
      domainInput.value = d.domain || '';
      document.getElementById('description').value = d.description || '';
      document.getElementById('active').checked = d.active !== false;

      if (d.customerid) {
        const opt = document.createElement('option');
        opt.value = d.customerid;
        opt.textContent = `<%== __("Customer") %> ${d.customerid}`;
        opt.selected = true;
        customeridSelect.appendChild(opt);
      }

      if (data.alias_domain) {
        isAliasDomainCheck.checked = true;
        targetDomainField.style.display = 'block';
        const opt = document.createElement('option');
        opt.value = data.alias_domain.target_domain;
        opt.textContent = data.alias_domain.target_domain;
        opt.selected = true;
        targetDomainSelect.appendChild(opt);
      }

      // Render alias domains that point TO this domain
      renderAliasDomains(data.alias_domains);

      // Disable alias domain option if this domain has alias domains pointing to it
      if (data.alias_domains && data.alias_domains.length > 0) {
        isAliasDomainCheck.disabled = true;
        isAliasDomainCheck.parentElement.querySelector('.form-text').textContent =
          '<%== __("Cannot be alias domain (has alias domains pointing to it)") %>';
      }
    }
  }

  // Load mailboxes
  async function loadMailboxes() {
    if (isNew) return;

    const url = `<%== url_for('Email.mailboxes.index', domain => '_DOM_') %>`.replace('_DOM_', encodeURIComponent(editingDomain));
    const data = await window.authenticatedFetch(url);

    const tbody = document.getElementById('mailboxesList');
    tbody.innerHTML = '';

    const mailboxes = data?.data || [];

    if (mailboxes.length === 0) {
      tbody.innerHTML = '<tr><td colspan="3" class="text-muted text-center"><%== __("No mailboxes") %></td></tr>';
      return;
    }

    mailboxes.forEach(m => {
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td>${m.username}</td>
        <td>${m.name || ''}</td>
        <td class="text-end">
          <button class="btn btn-sm btn-secondary btn-edit-mailbox" data-username="${m.username}"><%== icon 'pencil-fill', {} %></button>
          <button class="btn btn-sm btn-danger btn-delete-mailbox" data-username="${m.username}"><%== icon 'trash-fill', {} %></button>
        </td>
      `;
      tbody.appendChild(tr);
    });
  }

  // Load aliases
  async function loadAliases() {
    if (isNew) return;

    const url = `<%== url_for('Email.aliases.index', domain => '_DOM_') %>`.replace('_DOM_', encodeURIComponent(editingDomain));
    const data = await window.authenticatedFetch(url);

    const tbody = document.getElementById('aliasesList');
    tbody.innerHTML = '';

    const aliases = data?.data || [];

    if (aliases.length === 0) {
      tbody.innerHTML = '<tr><td colspan="3" class="text-muted text-center"><%== __("No aliases") %></td></tr>';
      return;
    }

    aliases.forEach(a => {
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td>${a.address}</td>
        <td>${a.goto || ''}</td>
        <td class="text-end">
          <button class="btn btn-sm btn-secondary btn-edit-alias" data-address="${a.address}"><%== icon 'pencil-fill', {} %></button>
          <button class="btn btn-sm btn-danger btn-delete-alias-entry" data-address="${a.address}"><%== icon 'trash-fill', {} %></button>
        </td>
      `;
      tbody.appendChild(tr);
    });
  }

  // Modal helper
  async function openModal(url) {
    const response = await fetch(url);
    const html = await response.text();
    modalDialog.dataset.sourceUrl = url;
    modalDialog.innerHTML = html;

    const modalscript = modalDialog.querySelector('#modalscript');
    if (modalscript) {
      const blob = new Blob([modalscript.innerHTML], { type: 'application/javascript' });
      const blobUrl = URL.createObjectURL(blob);
      const script = document.createElement('script');
      script.src = blobUrl;
      script.onload = () => URL.revokeObjectURL(blobUrl);
      modalDialog.appendChild(script);
      modalscript.remove();
    }

    universalModal.show();
  }

  // Form submission
  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    const formData = {
      domain: domainInput.value,
      description: document.getElementById('description').value,
      customerid: customeridSelect.value,
      active: document.getElementById('active').checked
    };

    if (isAliasDomainCheck.checked && targetDomainSelect.value) {
      formData.isAliasDomain = true;
      formData.targetDomain = targetDomainSelect.value;
    }

    let url, method;
    if (!isNew) {
      url = `<%== url_for('Email.domains.update', domain => '_DOM_') %>`.replace('_DOM_', encodeURIComponent(editingDomain));
      method = 'PUT';
    } else {
      url = '<%== url_for('Email.domains.create') %>';
      method = 'POST';
    }

    const result = await window.authenticatedFetch(url, {
      method: method,
      body: JSON.stringify(formData),
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' }
    });

    if (result && result.success) {
      window.showToast(result.message || '<%== __("Domain saved successfully") %>');
      if (isNew && result.domain) {
        window.location.href = `<%== url_for('email_domain', domain => '_DOM_') %>`.replace('_DOM_', encodeURIComponent(result.domain.domain));
      }
    } else {
      window.showToast(result?.error || '<%== __("Failed to save domain") %>', 'danger');
    }
  });

  // Delete domain
  deleteBtn.addEventListener('click', async () => {
    if (!confirm('<%== __("Delete this domain and all its mailboxes?") %>')) return;

    const result = await window.authenticatedFetch(
      `<%== url_for('Email.domains.delete', domain => '_DOM_') %>`.replace('_DOM_', encodeURIComponent(editingDomain)),
      { method: 'DELETE' }
    );

    if (result && result.success) {
      window.showToast(result.message || '<%== __("Domain deleted") %>');
      window.location.href = '<%== url_for('email_index') %>';
    } else {
      window.showToast(result?.error || '<%== __("Failed to delete domain") %>', 'danger');
    }
  });

  // Mailbox buttons
  document.getElementById('mailboxesList').addEventListener('click', async (e) => {
    const editBtn = e.target.closest('.btn-edit-mailbox');
    if (editBtn) {
      const username = editBtn.dataset.username;
      await openModal(`<%== url_for('email_mailbox', domain => '_DOM_', username => '_USR_') %>`.replace('_DOM_', encodeURIComponent(editingDomain)).replace('_USR_', encodeURIComponent(username)));
      return;
    }

    const deleteBtn = e.target.closest('.btn-delete-mailbox');
    if (deleteBtn) {
      if (!confirm('<%== __("Delete this mailbox?") %>')) return;
      const username = deleteBtn.dataset.username;
      const result = await window.authenticatedFetch(
        `<%== url_for('Email.mailboxes.delete', domain => '_DOM_', username => '_USR_') %>`.replace('_DOM_', encodeURIComponent(editingDomain)).replace('_USR_', encodeURIComponent(username)),
        { method: 'DELETE' }
      );
      if (result && result.success) {
        window.showToast(result.message);
        loadMailboxes();
      } else {
        window.showToast(result?.error || '<%== __("Failed to delete mailbox") %>', 'danger');
      }
    }
  });

  document.getElementById('addMailboxBtn')?.addEventListener('click', async () => {
    await openModal(`<%== url_for('email_mailbox_edit', domain => '_DOM_') %>`.replace('_DOM_', encodeURIComponent(editingDomain)));
  });

  // Alias domain buttons
  document.getElementById('aliasDomainsList')?.addEventListener('click', async (e) => {
    const deleteBtn = e.target.closest('.btn-delete-alias');
    if (deleteBtn) {
      if (!confirm('<%== __("Delete this alias domain?") %>')) return;
      const aliasDomain = deleteBtn.dataset.domain;
      const result = await window.authenticatedFetch(
        `<%== url_for('Email.domains.delete', domain => '_ALIAS_') %>`.replace('_ALIAS_', encodeURIComponent(aliasDomain)),
        { method: 'DELETE' }
      );
      if (result && result.success) {
        window.showToast(result.message);
        loadDomain(); // Reload to refresh alias domains list
      } else {
        window.showToast(result?.error || '<%== __("Failed to delete alias domain") %>', 'danger');
      }
    }
  });

  // Alias buttons
  document.getElementById('aliasesList')?.addEventListener('click', async (e) => {
    const editBtn = e.target.closest('.btn-edit-alias');
    if (editBtn) {
      const address = editBtn.dataset.address;
      await openModal(`<%== url_for('email_alias', domain => '_DOM_', address => '_ADDR_') %>`.replace('_DOM_', encodeURIComponent(editingDomain)).replace('_ADDR_', encodeURIComponent(address)));
      return;
    }

    const deleteBtn = e.target.closest('.btn-delete-alias-entry');
    if (deleteBtn) {
      if (!confirm('<%== __("Delete this alias?") %>')) return;
      const address = deleteBtn.dataset.address;
      const result = await window.authenticatedFetch(
        `<%== url_for('Email.aliases.delete', domain => '_DOM_', address => '_ADDR_') %>`.replace('_DOM_', encodeURIComponent(editingDomain)).replace('_ADDR_', encodeURIComponent(address)),
        { method: 'DELETE' }
      );
      if (result && result.success) {
        window.showToast(result.message);
        loadAliases();
      } else {
        window.showToast(result?.error || '<%== __("Failed to delete alias") %>', 'danger');
      }
    }
  });

  document.getElementById('addAliasBtn')?.addEventListener('click', async () => {
    await openModal(`<%== url_for('email_alias_edit', domain => '_DOM_') %>`.replace('_DOM_', encodeURIComponent(editingDomain)));
  });

  // Initialize
  loadDomain();
  loadMailboxes();
  loadAliases();
})();
