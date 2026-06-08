(function() {
  // Zone edit form handler (runs in modal context)
  // Get URL from modal's data attribute (set by openZoneModal or modalLoad)
  const modalDialog = document.querySelector('#modalDialog');
  const sourceUrl = modalDialog?.dataset.sourceUrl || '';
  const match = sourceUrl.match(/\/zones\/([^/]+)\/edit/);
  const isNew = sourceUrl.endsWith('/new');
  const zoneId = !isNew && match ? match[1] : null;

  // Check if opened under a customer context (customerId passed from parent)
  const fixedCustomerId = modalDialog?.dataset.customerId || null;

  // Zone name is immutable after creation - disable when editing
  const nameField = document.getElementById('name');
  if (!isNew && nameField) {
    nameField.disabled = true;
  }

  // Customer search for admin dropdown
  let searchTimeout = null;
  const accountField = document.getElementById('accountField');
  const accountSelect = document.getElementById('account');
  const customerSearch = document.getElementById('customerSearch');

  // Template selector (only for new zones)
  const templateField = document.getElementById('templateField');
  const templateSelect = document.getElementById('templateid');

  // Fetch available templates for new zone
  async function loadTemplates() {
    if (!isNew) return;  // Templates only for new zones

    try {
      let url = '<%== url_for("Zone.templates.index") %>';
      if (fixedCustomerId) {
        url += `?customerid=${fixedCustomerId}`;
      }
      const data = await window.authenticatedFetch(url);
      if (data && data.templates && data.templates.length > 0) {
        templateField.style.display = 'block';
        data.templates.forEach(t => {
          const opt = document.createElement('option');
          opt.value = t.templateid;
          opt.textContent = `${t.name} (${t.record_count} <%== __("records") %>)`;
          if (t.description) opt.title = t.description;
          templateSelect.appendChild(opt);
        });
      }
    } catch (e) {
      // No templates available or access denied
    }
  }

  // Check if user has admin access by testing endpoint
  async function checkAdminAccess() {
    // If under customer context, show field but disable search
    if (fixedCustomerId) {
      accountField.style.display = 'block';
      customerSearch.style.display = 'none';
      accountSelect.disabled = true;
      // Pre-select the customer
      const opt = document.createElement('option');
      opt.value = fixedCustomerId;
      opt.textContent = `<%== __("Customer") %> ${fixedCustomerId}`;
      opt.selected = true;
      accountSelect.appendChild(opt);
      return;
    }

    try {
      const data = await window.authenticatedFetch('<%== url_for('Customer.index') %>?simple=1&searchterm=___');
      // If we get here without error, user has access
      accountField.style.display = 'block';
      setupCustomerSearch();
    } catch (e) {
      // Not admin - field stays hidden
    }
  }

  const defaultPlaceholder = '<%== __("Search customer (min 3 chars)...") %>';

  function setupCustomerSearch() {
    // Smooth transition for visual feedback
    accountSelect.style.transition = 'box-shadow 0.3s ease';

    customerSearch.addEventListener('input', (e) => {
      const value = e.target.value;
      clearTimeout(searchTimeout);

      if (value.length >= 3) {
        searchTimeout = setTimeout(() => searchCustomers(value), 300);
      } else {
        // Clear results but keep current selection
        const currentValue = accountSelect.value;
        const currentText = accountSelect.options[accountSelect.selectedIndex]?.text;
        accountSelect.innerHTML = '<option value=""><%== __("No customer assigned") %></option>';
        if (currentValue) {
          const opt = document.createElement('option');
          opt.value = currentValue;
          opt.textContent = currentText;
          opt.selected = true;
          accountSelect.appendChild(opt);
        }
        customerSearch.placeholder = defaultPlaceholder;
        accountSelect.style.boxShadow = '';
      }
    });
  }

  async function searchCustomers(term) {
    try {
      const data = await window.authenticatedFetch(`<%== url_for('Customer.index') %>?simple=1&searchterm=${encodeURIComponent(term)}`);
      if (data && data.customers) {
        const currentValue = accountSelect.value;
        accountSelect.innerHTML = '<option value=""><%== __("No customer assigned") %></option>';

        data.customers.forEach(c => {
          const opt = document.createElement('option');
          opt.value = c.customerid;
          opt.textContent = c.name;
          if (c.customerid == currentValue) opt.selected = true;
          accountSelect.appendChild(opt);
        });

        // Visual feedback: flash the select and show result count
        const count = data.customers.length;
        customerSearch.placeholder = count > 0
          ? `<%== __("Found") %> ${count} <%== __("customers") %>`
          : '<%== __("No matches found") %>';
        accountSelect.style.boxShadow = '0 0 0 0.25rem rgba(25, 135, 84, 0.5)';
        setTimeout(() => accountSelect.style.boxShadow = '', 1500);
      }
    } catch (e) {
      console.error('Customer search failed:', e);
    }
  }

  // Load zone data for editing
  async function loadZone() {
    const data = await window.authenticatedFetch(sourceUrl, {
      method: 'GET',
      headers: { 'Accept': 'application/json' }
    });

    if (data && !data.error) {
      populateForm(data);
    }
  }

  // Populate form with zone data
  function populateForm(zone) {
    nameField.value = zone.name || '';
    document.getElementById('kind').value = zone.kind || 'Master';

    // If zone has account, add it as option and select it
    if (zone.account) {
      const opt = document.createElement('option');
      opt.value = zone.account;
      opt.textContent = zone.account;  // Will be replaced by search if user searches
      opt.selected = true;
      accountSelect.appendChild(opt);
    }
  }

  // Check admin access and load templates
  checkAdminAccess();
  loadTemplates();

  // Save zone (create or update)
  async function saveZone() {
    const form = document.getElementById('zoneForm');
    const formData = new FormData(form);

    // Convert FormData to object
    const data = {};
    for (const [key, value] of formData.entries()) {
      data[key] = value;
    }

    // Add disabled account field value (not included in FormData when disabled)
    if (fixedCustomerId && accountSelect.disabled) {
      data.account = accountSelect.value;
    }

    // Determine URL and method
    let url, method;
    if (isNew) {
      url = '<%== url_for('Zone.create') %>';
      method = 'POST';
    } else {
      url = `<%== url_for('Zone.update', zone_id => '_ZID_') %>`.replace('_ZID_', zoneId);
      method = 'PATCH';
      delete data.name;       // Zone name is immutable
      delete data.templateid; // Templates only for new zones
    }

    const result = await window.authenticatedFetch(url, {
      method: method,
      body: JSON.stringify(data),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      }
    });

    if (result && result.success) {
      window.showToast(result.toast || '<%== __("Zone saved successfully") %>');
      const modal = bootstrap.Modal.getInstance(document.querySelector('#universalmodal'));
      if (modal) modal.hide();
      // Refresh the zone list
      setTimeout(() => location.reload(), 500);
    } else {
      window.showToast(result?.toast || '<%== __("Failed to save zone") %>');
    }
  }

  // Form submission handler
  document.getElementById('zoneForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    await saveZone();
  });

  // Load existing zone if editing
  if (!isNew && zoneId) {
    loadZone();
  }
})();
