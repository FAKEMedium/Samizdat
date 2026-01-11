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
  const limitsRow = document.getElementById('limitsRow');
  const submitBtn = document.getElementById('submitBtn');
  const deleteBtn = document.getElementById('deleteBtn');

  // Update UI for edit mode (sections shown after loadDomain determines if alias domain)
  if (!isNew) {
    domainInput.disabled = true;
    deleteBtn.style.display = 'inline-block';
  }

  // Check for alias_target and customerid query params (creating alias domain from parent)
  const urlParams = new URLSearchParams(window.location.search);
  const aliasTarget = urlParams.get('alias_target');
  const presetCustomerId = urlParams.get('customerid');
  if (aliasTarget && isNew) {
    isAliasDomainCheck.checked = true;
    targetDomainField.style.display = 'block';
    limitsRow.style.display = 'none';
    const opt = document.createElement('option');
    opt.value = aliasTarget;
    opt.textContent = aliasTarget;
    opt.selected = true;
    targetDomainSelect.appendChild(opt);
  }
  if (presetCustomerId && isNew) {
    // Add customer option and select it
    const custOpt = document.createElement('option');
    custOpt.value = presetCustomerId;
    custOpt.textContent = `<%== __("Customer") %> ${presetCustomerId}`;
    custOpt.selected = true;
    customeridSelect.appendChild(custOpt);
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
    limitsRow.style.display = isAliasDomainCheck.checked ? 'none' : 'flex';
    if (isAliasDomainCheck.checked && customeridSelect.value) {
      await loadCustomerDomains(customeridSelect.value);
    }
  });

  async function loadCustomerDomains(customerid, selectedDomain = null) {
    const data = await window.authenticatedFetch(`<%== url_for('Email.domains.available_targets') %>?customerid=${customerid}`);
    if (data && data.domains) {
      targetDomainSelect.innerHTML = '<option value=""><%== __("Select target domain") %></option>';
      data.domains.forEach(d => {
        const opt = document.createElement('option');
        opt.value = d.domain;
        opt.textContent = d.domain + (d.description ? ` (${d.description})` : '');
        if (selectedDomain && d.domain === selectedDomain) opt.selected = true;
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

      // Load limit values
      document.getElementById('aliases').value = d.aliases ?? 0;
      document.getElementById('mailboxes').value = d.mailboxes ?? 0;
      document.getElementById('maxquota').value = d.maxquota ?? 0;
      document.getElementById('quota').value = d.quota ?? 0;

      if (d.customerid) {
        const opt = document.createElement('option');
        opt.value = d.customerid;
        opt.textContent = `<%== __("Customer") %> ${d.customerid}`;
        opt.selected = true;
        customeridSelect.appendChild(opt);
      }

      if (data.alias_domain) {
        // This IS an alias domain - show target field, hide mailboxes/aliases sections
        isAliasDomainCheck.checked = true;
        targetDomainField.style.display = 'block';

        // Load all available target domains for this customer, then select current target
        if (d.customerid) {
          await loadCustomerDomains(d.customerid, data.alias_domain.target_domain);
        } else {
          // Fallback: just show current target
          const opt = document.createElement('option');
          opt.value = data.alias_domain.target_domain;
          opt.textContent = data.alias_domain.target_domain;
          opt.selected = true;
          targetDomainSelect.appendChild(opt);
        }

        // Hide sections not applicable to alias domains
        document.getElementById('aliasDomainsSection').style.display = 'none';
        document.getElementById('mailboxesSection').style.display = 'none';
        document.getElementById('aliasesSection').style.display = 'none';
        document.getElementById('domainAdminsSection')?.style.setProperty('display', 'none');
        limitsRow.style.display = 'none';
      } else {
        // Regular domain - show all sections
        document.getElementById('aliasDomainsSection').style.display = 'block';
        document.getElementById('mailboxesSection').style.display = 'block';
        document.getElementById('aliasesSection').style.display = 'block';
        document.getElementById('domainAdminsSection')?.style.setProperty('display', 'block');

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
      tr.dataset.username = m.username;
      const vacationBtnClass = m.vacation_active ? 'btn-info' : 'btn-outline-info';
      tr.innerHTML = `
        <td>${m.username}</td>
        <td>${m.name || ''}</td>
        <td class="text-end">
          <button class="btn btn-sm ${vacationBtnClass} btn-vacation" title="<%== __('Vacation') %>"><%== icon 'calendar-event', {} %></button>
          <button class="btn btn-sm btn-secondary btn-edit-mailbox"><%== icon 'pencil-fill', {} %></button>
          <button class="btn btn-sm btn-danger btn-delete-mailbox"><%== icon 'trash-fill', {} %></button>
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
      active: document.getElementById('active').checked,
      aliases: parseInt(document.getElementById('aliases').value) || 0,
      mailboxes: parseInt(document.getElementById('mailboxes').value) || 0,
      maxquota: parseInt(document.getElementById('maxquota').value) || 0,
      quota: parseInt(document.getElementById('quota').value) || 0
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

  // Vacation modal
  const vacationModal = new bootstrap.Modal('#vacationModal');

  async function openVacation(email) {
    document.getElementById('vacationEmail').value = email;
    // Load existing vacation settings
    const data = await window.authenticatedFetch(`<%== url_for('Email.vacation.get', email => '_EMAIL_') %>`.replace('_EMAIL_', encodeURIComponent(email)));
    const v = data?.vacation || {};
    const hasExisting = v.email && v.subject; // Has existing vacation record
    document.getElementById('vacationSubject').value = v.subject || '';
    document.getElementById('vacationBody').value = v.body || '';
    document.getElementById('vacationFrom').value = v.activefrom ? v.activefrom.substring(0, 10) : '';
    document.getElementById('vacationUntil').value = v.activeuntil ? v.activeuntil.substring(0, 10) : '';
    document.getElementById('vacationInterval').value = v.interval_time || 0;
    document.getElementById('vacationActive').checked = v.active || false;
    document.getElementById('deleteVacationBtn').style.display = hasExisting ? 'inline-block' : 'none';
    vacationModal.show();
  }

  document.getElementById('saveVacationBtn')?.addEventListener('click', async () => {
    const email = document.getElementById('vacationEmail').value;
    const data = {
      subject: document.getElementById('vacationSubject').value,
      body: document.getElementById('vacationBody').value,
      activefrom: document.getElementById('vacationFrom').value || null,
      activeuntil: document.getElementById('vacationUntil').value || null,
      interval_time: parseInt(document.getElementById('vacationInterval').value) || 0,
      active: document.getElementById('vacationActive').checked
    };
    const result = await window.authenticatedFetch(
      `<%== url_for('Email.vacation.update', email => '_EMAIL_') %>`.replace('_EMAIL_', encodeURIComponent(email)),
      { method: 'PUT', body: JSON.stringify(data), headers: { 'Content-Type': 'application/json' } }
    );
    if (result?.success) {
      window.showToast(result.message);
      vacationModal.hide();
      loadMailboxes(); // Refresh to update vacation button visual state
    } else {
      window.showToast(result?.error || '<%== __("Failed to save vacation settings") %>', 'danger');
    }
  });

  document.getElementById('deleteVacationBtn')?.addEventListener('click', async () => {
    const email = document.getElementById('vacationEmail').value;
    if (!confirm('<%== __("Delete vacation settings?") %>')) return;
    const result = await window.authenticatedFetch(
      `<%== url_for('Email.vacation.delete', email => '_EMAIL_') %>`.replace('_EMAIL_', encodeURIComponent(email)),
      { method: 'DELETE' }
    );
    if (result?.success) {
      window.showToast(result.message);
      vacationModal.hide();
      loadMailboxes();
    } else {
      window.showToast(result?.error || '<%== __("Failed to delete vacation settings") %>', 'danger');
    }
  });

  // Mailbox buttons
  document.getElementById('mailboxesList').addEventListener('click', async (e) => {
    const tr = e.target.closest('tr');
    if (!tr?.dataset.username) return;
    const username = tr.dataset.username;

    if (e.target.closest('.btn-vacation')) {
      await openVacation(username);
      return;
    }

    if (e.target.closest('.btn-edit-mailbox')) {
      await openModal(`<%== url_for('email_mailbox', domain => '_DOM_', username => '_USR_') %>`.replace('_DOM_', encodeURIComponent(editingDomain)).replace('_USR_', encodeURIComponent(username)));
      return;
    }

    if (e.target.closest('.btn-delete-mailbox')) {
      if (!confirm('<%== __("Delete this mailbox?") %>')) return;
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

  // Add alias domain button - navigate to create new domain as alias
  document.getElementById('addAliasDomainBtn')?.addEventListener('click', () => {
    let url = `<%== url_for('email_domain_edit') %>?alias_target=${encodeURIComponent(editingDomain)}`;
    if (customeridSelect.value) {
      url += `&customerid=${encodeURIComponent(customeridSelect.value)}`;
    }
    window.location.href = url;
  });

  // Domain admins functionality
  let allAdmins = [];
  let domainAdmins = [];

  async function loadDomainAdmins() {
    if (isNew) return;

    const data = await window.authenticatedFetch(`<%== url_for('Email.domain_admins.index', domain => '_DOM_') %>`.replace('_DOM_', encodeURIComponent(editingDomain)));
    domainAdmins = data?.admins || [];
    renderDomainAdmins();
  }

  function renderDomainAdmins() {
    const list = document.getElementById('domainAdminsList');
    if (!list) return;

    if (!domainAdmins.length) {
      list.innerHTML = '<li class="list-group-item text-muted"><%== __("No administrators") %></li>';
      return;
    }

    list.innerHTML = domainAdmins.map(a => {
      const href = `<%== url_for('email_admin', username => '_USR_') %>`.replace('_USR_', encodeURIComponent(a.username));
      return `<li class="list-group-item d-flex justify-content-between align-items-center">
        <a href="${href}" data-bs-toggle="modal" data-bs-target="#universalmodal">${a.username}</a>
        <button type="button" class="btn btn-sm btn-outline-danger btn-remove-admin" data-username="${a.username}"><%== icon 'x', {} %></button>
      </li>`;
    }).join('');
  }

  async function fetchAllAdmins() {
    const data = await window.authenticatedFetch('<%== url_for("Email.admins.index") %>?limit=1000');
    allAdmins = data?.data || [];
  }

  function renderAdminSearchResults(searchTerm) {
    const results = document.getElementById('adminSearchResults');
    if (!results) return;

    if (!searchTerm) {
      results.innerHTML = '';
      return;
    }

    const currentAdminUsernames = new Set(domainAdmins.map(a => a.username));
    const filtered = allAdmins
      .filter(a => a.username.toLowerCase().includes(searchTerm.toLowerCase()) && !currentAdminUsernames.has(a.username))
      .slice(0, 5);

    if (!filtered.length) {
      results.innerHTML = '<li class="list-group-item text-muted small"><%== __("No results") %></li>';
      return;
    }

    results.innerHTML = filtered.map(a =>
      `<li class="list-group-item d-flex justify-content-between align-items-center py-1">
        <small>${a.username}</small>
        <button type="button" class="btn btn-sm btn-outline-success btn-add-admin" data-username="${a.username}"><%== icon 'plus', {} %></button>
      </li>`
    ).join('');
  }

  // Admin search input
  document.getElementById('adminSearch')?.addEventListener('input', async (e) => {
    if (!allAdmins.length) await fetchAllAdmins();
    renderAdminSearchResults(e.target.value);
  });

  // Handle add admin from search results
  document.getElementById('adminSearchResults')?.addEventListener('click', async (e) => {
    const addBtn = e.target.closest('.btn-add-admin');
    if (addBtn) {
      const username = addBtn.dataset.username;
      const result = await window.authenticatedFetch(
        `<%== url_for('Email.domain_admins.add', domain => '_DOM_', admin => '_ADM_') %>`.replace('_DOM_', encodeURIComponent(editingDomain)).replace('_ADM_', encodeURIComponent(username)),
        { method: 'POST' }
      );
      if (result?.success) {
        domainAdmins.push({ username });
        renderDomainAdmins();
        document.getElementById('adminSearch').value = '';
        renderAdminSearchResults('');
      } else {
        window.showToast(result?.error || '<%== __("Failed to add admin") %>', 'danger');
      }
    }
  });

  // Handle remove admin from list
  document.getElementById('domainAdminsList')?.addEventListener('click', async (e) => {
    const removeBtn = e.target.closest('.btn-remove-admin');
    if (removeBtn) {
      const username = removeBtn.dataset.username;
      const result = await window.authenticatedFetch(
        `<%== url_for('Email.domain_admins.remove', domain => '_DOM_', admin => '_ADM_') %>`.replace('_DOM_', encodeURIComponent(editingDomain)).replace('_ADM_', encodeURIComponent(username)),
        { method: 'DELETE' }
      );
      if (result?.success) {
        domainAdmins = domainAdmins.filter(a => a.username !== username);
        renderDomainAdmins();
      } else {
        window.showToast(result?.error || '<%== __("Failed to remove admin") %>', 'danger');
      }
    }
  });

  // Domain log functionality
  function formatAction(action) {
    if (!action) return '';
    return action.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
  }

  function formatLogData(data) {
    if (!data) return '';
    try {
      const obj = typeof data === 'string' ? JSON.parse(data) : data;
      return Object.entries(obj).map(([k, v]) => v).join(', ');
    } catch (e) {
      return data;
    }
  }

  async function loadDomainLog() {
    if (isNew) return;

    const data = await window.authenticatedFetch(`<%== url_for('Email.logs.index') %>?domain=${encodeURIComponent(editingDomain)}&limit=10`);
    const logList = document.getElementById('domainLogList');
    const logMore = document.getElementById('domainLogMore');
    const logLink = document.getElementById('domainLogLink');

    if (!logList) return;

    document.getElementById('domainLogSection').style.display = 'block';

    const logs = data?.data || [];
    if (logs.length === 0) {
      logList.innerHTML = '<li class="list-group-item text-muted"><%== __("No activity") %></li>';
      return;
    }

    logList.innerHTML = logs.map(log => {
      const details = formatLogData(log.data);
      return `<li class="list-group-item px-0 py-1">${formatAction(log.action)}${details ? ': ' + details : ''}</li>`;
    }).join('');

    // Show "View all" link if there are any entries (full log has more details)
    logMore.style.display = 'block';
    logLink.href = `<%== url_for('email_log') %>?domain=${encodeURIComponent(editingDomain)}`;
  }

  // Initialize
  loadDomain();
  loadMailboxes();
  loadAliases();
  loadDomainAdmins();
  loadDomainLog();
})();
