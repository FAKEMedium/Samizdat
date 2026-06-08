(function() {
  // Contact form handler (runs in modal context)
  // Form elements - check they exist (modal may not be fully loaded)
  const contactFields = document.getElementById('contactFields');
  const submitBtn = document.getElementById('submitBtn');
  const customerSelect = document.getElementById('customer');
  const customerSearch = document.getElementById('customerSearch');
  const customerField = document.getElementById('customerField');
  const registryCheckboxes = document.querySelectorAll('input[name="registries"]');

  // Exit early if form elements don't exist
  if (!customerSelect || !customerSearch || !contactFields || !submitBtn) {
    console.warn('Contact form elements not found');
    return;
  }

  // Check if we're in edit mode
  const editHandle = '<%== $edit_handle // '' %>';
  const isEditMode = editHandle !== '';
  let originalEmail = '';  // Store original email to detect changes

  // Pre-select registries from stash (passed via URL param to controller)
  const preselectedRegistries = '<%== $preselected_registries // '' %>'.split(',').filter(Boolean);
  if (preselectedRegistries.length > 0) {
    registryCheckboxes.forEach(cb => {
      cb.checked = preselectedRegistries.includes(cb.value);
    });
  }

  // Update submit button state based on customer AND registry selection
  function updateSubmitState() {
    if (isEditMode) {
      // In edit mode, just need registry selection
      const hasRegistry = Array.from(registryCheckboxes).some(cb => cb.checked);
      submitBtn.disabled = !hasRegistry;
      return;
    }
    const hasCustomer = customerSelect.value !== '';
    const hasRegistry = Array.from(registryCheckboxes).some(cb => cb.checked);
    submitBtn.disabled = !hasCustomer || !hasRegistry;
    contactFields.disabled = !hasCustomer;
  }

  // Edit mode: hide customer selection, load contact data
  if (isEditMode) {
    customerField.style.display = 'none';
    contactFields.disabled = false;
    submitBtn.textContent = '<%== __("Update Contact") %>';

    // Load contact data using OpenAPI endpoint
    window.authenticatedFetch(`<%== url_for('Domain.contact.get', handle => '__HANDLE__') %>`.replace('__HANDLE__', encodeURIComponent(editHandle)))
      .then(data => {
        if (data && data.contact) {
          populateFormFromContact(data.contact);
          updateSubmitState();
        }
      })
      .catch(e => console.error('Failed to load contact:', e));
  }

  // Listen for registry checkbox changes
  registryCheckboxes.forEach(cb => {
    cb.addEventListener('change', updateSubmitState);
  });

  // Show designatedAgent checkbox when email changes in edit mode (RR registry)
  document.getElementById('email').addEventListener('input', () => {
    if (!isEditMode) return;
    const newEmail = document.getElementById('email').value.trim();
    const designatedAgentGroup = document.getElementById('designatedAgentGroup');
    const rrSelected = preselectedRegistries.includes('rr');
    if (rrSelected && newEmail && newEmail !== originalEmail) {
      designatedAgentGroup.style.display = 'block';
    } else {
      designatedAgentGroup.style.display = 'none';
      document.getElementById('designatedAgent').checked = false;
    }
  });

  // Customer search
  let searchTimeout = null;
  const defaultPlaceholder = '<%== __("Search customer (min 3 chars)...") %>';

  customerSelect.style.transition = 'box-shadow 0.3s ease';

  customerSearch.addEventListener('input', (e) => {
    const value = e.target.value;
    clearTimeout(searchTimeout);

    if (value.length >= 3) {
      searchTimeout = setTimeout(() => searchCustomers(value), 300);
    } else {
      customerSelect.innerHTML = '<option value=""><%== __("Select customer first...") %></option>';
      customerSearch.placeholder = defaultPlaceholder;
      customerSelect.style.boxShadow = '';
    }
  });

  async function searchCustomers(term) {
    try {
      const data = await window.authenticatedFetch(`<%== url_for('Customer.index') %>?simple=1&searchterm=${encodeURIComponent(term)}`);
      if (data && data.customers) {
        customerSelect.innerHTML = '<option value=""><%== __("Select customer first...") %></option>';

        data.customers.forEach(c => {
          const opt = document.createElement('option');
          opt.value = c.customerid;
          opt.textContent = c.name;
          customerSelect.appendChild(opt);
        });

        const count = data.customers.length;
        customerSearch.placeholder = count > 0
          ? `<%== __("Found") %> ${count} <%== __("customers") %>`
          : '<%== __("No matches found") %>';
        customerSelect.style.boxShadow = '0 0 0 0.25rem rgba(25, 135, 84, 0.5)';
        setTimeout(() => customerSelect.style.boxShadow = '', 1500);
      }
    } catch (e) {
      console.error('Customer search failed:', e);
    }
  }

  // When customer is selected, fetch details and populate form
  customerSelect.addEventListener('change', async () => {
    const customerId = customerSelect.value;

    if (!customerId) {
      // No customer selected - disable form
      clearForm();
      updateSubmitState();
      return;
    }

    try {
      const data = await window.authenticatedFetch(`<%== url_for('Customer.index') %>/${customerId}`);
      if (data && data.customer) {
        populateForm(data.customer);
        updateSubmitState();
      }
    } catch (e) {
      console.error('Failed to load customer:', e);
    }
  });

  function clearForm() {
    document.getElementById('handleSE').value = '';
    document.getElementById('handleNU').value = '';
    document.getElementById('handleRR').value = '';
    document.getElementById('name').value = '';
    document.getElementById('organization').value = '';
    document.getElementById('orgno').value = '';
    document.getElementById('vatno').value = '';
    document.getElementById('email').value = '';
    document.getElementById('voice').value = '';
    document.getElementById('street').value = '';
    document.getElementById('postalCode').value = '';
    document.getElementById('city').value = '';
    document.getElementById('state').value = '';
    document.getElementById('country').value = '';
  }

  // Generate random 16-char alphanumeric handle
  function generateHandle() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return Array.from({ length: 16 }, () => chars[Math.floor(Math.random() * chars.length)]).join('');
  }

  function populateForm(customer) {
    // Generate same random handle for all registries
    const handle = generateHandle();
    document.getElementById('handleSE').value = handle;
    document.getElementById('handleNU').value = handle;
    document.getElementById('handleRR').value = handle;

    // Name: firstname + lastname or company
    const fullName = [customer.firstname, customer.lastname].filter(Boolean).join(' ') || customer.company || '';
    document.getElementById('name').value = fullName;

    // Organization
    document.getElementById('organization').value = customer.company || '';

    // Org number and VAT
    document.getElementById('orgno').value = customer.orgno || '';
    document.getElementById('vatno').value = customer.vatno || '';

    // Email
    document.getElementById('email').value = customer.contactemail || '';

    // Phone - format for RTR (needs +CC.NNNN format)
    const phone = customer.phone1 || customer.phone2 || '';
    document.getElementById('voice').value = phone;

    // Address
    document.getElementById('street').value = customer.address || '';

    // Postal code and city
    document.getElementById('postalCode').value = customer.zip || '';
    document.getElementById('city').value = customer.city || '';

    // State (not always available)
    document.getElementById('state').value = '';

    // Country
    if (customer.country) {
      document.getElementById('country').value = customer.country.toUpperCase();
    }
  }

  // Populate form from existing contact data (for edit mode)
  function populateFormFromContact(contact) {
    // Set handle in the appropriate registry field and make it readonly
    const handle = contact.handle || '';
    preselectedRegistries.forEach(reg => {
      const fieldId = 'handle' + reg.toUpperCase();
      const field = document.getElementById(fieldId);
      if (field) {
        field.value = handle;
        field.readOnly = true; // Handle can't be changed in edit mode
      }
    });

    document.getElementById('name').value = contact.name || '';
    document.getElementById('organization').value = contact.organization || '';
    document.getElementById('orgno').value = contact.orgno || '';
    document.getElementById('vatno').value = contact.vatno || '';
    document.getElementById('email').value = contact.email || '';
    originalEmail = contact.email || '';  // Store for change detection
    document.getElementById('voice').value = contact.phone || contact.voice || '';

    // Address - join array with newlines for textarea
    const street = contact.street || contact.addressLine || [];
    document.getElementById('street').value = Array.isArray(street) ? street.join('\n') : street;

    document.getElementById('postalCode').value = contact.postalCode || '';
    document.getElementById('city').value = contact.city || '';
    document.getElementById('state').value = contact.state || '';
    document.getElementById('country').value = (contact.country || '').toUpperCase();

    // For SE/NU registries, orgno cannot be edited
    const seNuSelected = preselectedRegistries.some(r => r === 'se' || r === 'nu');
    if (seNuSelected) {
      document.getElementById('orgno').readOnly = true;
      document.getElementById('orgno').title = '<%== __("Org number cannot be changed for SE/NU contacts") %>';
    }
  }

  // Save contact
  async function saveContact() {
    const form = document.getElementById('contactForm');
    const formData = new FormData(form);

    // Get selected registries with their handles
    const selectedRegistries = [];
    registryCheckboxes.forEach(cb => {
      if (cb.checked) {
        const reg = cb.value;
        const handleField = document.getElementById('handle' + reg.toUpperCase());
        const handle = handleField ? handleField.value.trim() : '';
        if (!handle) {
          window.showToast(`<%== __("Handle required for") %> ${reg.toUpperCase()}`);
          return;
        }
        selectedRegistries.push({ registry: reg, handle: handle });
      }
    });

    if (selectedRegistries.length === 0) {
      window.showToast('<%== __("Please select at least one registry") %>');
      return;
    }

    // Build contact data object (field names match model expectations)
    // Split street textarea by newlines into array
    const streetLines = formData.get('street').split('\n').map(s => s.trim()).filter(Boolean);

    const data = {
      name: formData.get('name'),
      organization: formData.get('organization') || undefined,
      orgno: formData.get('orgno') || undefined,
      vatno: formData.get('vatno') || undefined,
      email: formData.get('email'),
      phone: formData.get('voice'),
      street: streetLines,
      postalCode: formData.get('postalCode'),
      city: formData.get('city'),
      state: formData.get('state') || undefined,
      country: formData.get('country'),
      registries: selectedRegistries  // Now contains [{registry, handle}, ...]
    };

    // Remove undefined values (but keep registries array)
    Object.keys(data).forEach(key => {
      if (data[key] === undefined || data[key] === '') {
        delete data[key];
      }
    });

    // Include designatedAgent when email changes in edit mode (for RR)
    if (isEditMode && data.email !== originalEmail) {
      data.designatedAgent = document.getElementById('designatedAgent').checked;
    }

    // Use PUT for edit, POST for create - use OpenAPI operationIds
    const url = isEditMode
      ? `<%== url_for('Domain.contact.update', handle => '__HANDLE__') %>`.replace('__HANDLE__', encodeURIComponent(editHandle))
      : '<%== url_for('Domain.contact.create') %>';
    const method = isEditMode ? 'PUT' : 'POST';

    const result = await window.authenticatedFetch(url, {
      method: method,
      body: JSON.stringify(data),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      }
    });

    if (result && result.success) {
      const successMsg = isEditMode
        ? '<%== __("Contact updated successfully") %>'
        : '<%== __("Contact created successfully") %>';
      window.showToast(result.toast || successMsg);
      const modal = bootstrap.Modal.getInstance(document.querySelector('#universalmodal'));
      if (modal) modal.hide();
      // Refresh the page
      setTimeout(() => location.reload(), 500);
    } else {
      const failMsg = isEditMode
        ? '<%== __("Failed to update contact") %>'
        : '<%== __("Failed to create contact") %>';
      window.showToast(result?.error || result?.toast || failMsg);
    }
  }

  // Form submission handler
  document.getElementById('contactForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    await saveContact();
  });
})();
