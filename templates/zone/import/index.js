(function() {
  // Import zone form handler
  const modalDialog = document.querySelector('#modalDialog');

  // Check if opened under a customer context (customerId passed from parent)
  const fixedCustomerId = modalDialog?.dataset.customerId || null;

  // Set placeholder via JS to avoid template indentation issues
  document.getElementById('zone').placeholder = [
    'example.com.\t3600\tIN\tSOA\tns1.example.com. admin.example.com. 2024010101 3600 900 604800 86400',
    'example.com.\t3600\tIN\tNS\tns1.example.com.',
    'example.com.\t3600\tIN\tNS\tns2.example.com.',
    'example.com.\t3600\tIN\tA\t192.0.2.1',
    'ns1.example.com.\t3600\tIN\tA\t192.0.2.1',
    'ns2.example.com.\t3600\tIN\tA\t192.0.2.2',
    'www.example.com.\t3600\tIN\tA\t192.0.2.10',
    'example.com.\t3600\tIN\tMX\t10 mail.example.com.',
    'mail.example.com.\t3600\tIN\tA\t192.0.2.20'
  ].join('\n');

  // Customer search for admin dropdown
  let searchTimeout = null;
  const accountField = document.getElementById('accountField');
  const accountSelect = document.getElementById('account');
  const customerSearch = document.getElementById('customerSearch');

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
        accountSelect.innerHTML = '<option value=""><%== __("No customer assigned") %></option>';
        customerSearch.placeholder = defaultPlaceholder;
        accountSelect.style.boxShadow = '';
      }
    });
  }

  async function searchCustomers(term) {
    try {
      const data = await window.authenticatedFetch(`<%== url_for('Customer.index') %>?simple=1&searchterm=${encodeURIComponent(term)}`);
      if (data && data.customers) {
        accountSelect.innerHTML = '<option value=""><%== __("No customer assigned") %></option>';
        data.customers.forEach(c => {
          const opt = document.createElement('option');
          opt.value = c.customerid;
          opt.textContent = c.name;
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

  checkAdminAccess();

  document.getElementById('importForm').addEventListener('submit', async (e) => {
    e.preventDefault();

    const form = e.target;
    const data = {
      name: document.getElementById('name').value,
      kind: document.getElementById('kind').value,
      zone: document.getElementById('zone').value,
      account: document.getElementById('account').value
    };

    const result = await window.authenticatedFetch('<%== url_for("Zone.import") %>', {
      method: 'POST',
      body: JSON.stringify(data),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      }
    });

    if (result && result.success) {
      window.showToast(result.toast || '<%== __("Zone imported successfully") %>');
      const modal = bootstrap.Modal.getInstance(document.querySelector('#universalmodal'));
      if (modal) modal.hide();
      setTimeout(() => location.reload(), 500);
    } else {
      window.showToast(result?.toast || result?.error || '<%== __("Failed to import zone") %>', 'danger');
    }
  });
})();
