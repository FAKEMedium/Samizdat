(function() {
  // Contact creation form handler (runs in modal context)
  const modalDialog = document.querySelector('#modalDialog');

  // Form elements
  const contactFields = document.getElementById('contactFields');
  const submitBtn = document.getElementById('submitBtn');
  const customerSelect = document.getElementById('customer');
  const customerSearch = document.getElementById('customerSearch');

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
      contactFields.disabled = true;
      submitBtn.disabled = true;
      clearForm();
      return;
    }

    try {
      const data = await window.authenticatedFetch(`<%== url_for('Customer.index') %>/${customerId}`);
      if (data && data.customer) {
        populateForm(data.customer);
        contactFields.disabled = false;
        submitBtn.disabled = false;
      }
    } catch (e) {
      console.error('Failed to load customer:', e);
    }
  });

  function clearForm() {
    document.getElementById('handle').value = '';
    document.getElementById('name').value = '';
    document.getElementById('organization').value = '';
    document.getElementById('email').value = '';
    document.getElementById('voice').value = '';
    document.getElementById('addressLine0').value = '';
    document.getElementById('addressLine1').value = '';
    document.getElementById('postalCode').value = '';
    document.getElementById('city').value = '';
    document.getElementById('state').value = '';
    document.getElementById('country').value = '';
  }

  function populateForm(customer) {
    // Generate handle from customer id and name
    const nameSlug = (customer.firstname || customer.company || 'contact')
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .substring(0, 20);
    document.getElementById('handle').value = `${customer.customerid}-${nameSlug}`;

    // Name: firstname + lastname or company
    const fullName = [customer.firstname, customer.lastname].filter(Boolean).join(' ') || customer.company || '';
    document.getElementById('name').value = fullName;

    // Organization
    document.getElementById('organization').value = customer.company || '';

    // Email
    document.getElementById('email').value = customer.contactemail || '';

    // Phone - format for RTR (needs +CC.NNNN format)
    const phone = customer.phone1 || customer.phone2 || '';
    document.getElementById('voice').value = phone;

    // Address
    document.getElementById('addressLine0').value = customer.address || '';
    document.getElementById('addressLine1').value = '';

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

  // Save contact
  async function saveContact() {
    const form = document.getElementById('contactForm');
    const formData = new FormData(form);

    // Build contact data object
    const data = {
      handle: formData.get('handle'),
      name: formData.get('name'),
      organization: formData.get('organization') || undefined,
      email: formData.get('email'),
      voice: formData.get('voice'),
      addressLine: [formData.get('addressLine0')],
      postalCode: formData.get('postalCode'),
      city: formData.get('city'),
      state: formData.get('state') || undefined,
      country: formData.get('country')
    };

    // Add second address line if provided
    const addressLine1 = formData.get('addressLine1');
    if (addressLine1) {
      data.addressLine.push(addressLine1);
    }

    // Remove undefined values
    Object.keys(data).forEach(key => {
      if (data[key] === undefined || data[key] === '') {
        delete data[key];
      }
    });

    const result = await window.authenticatedFetch('<%== url_for('RTR.contacts.create') %>', {
      method: 'POST',
      body: JSON.stringify(data),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      }
    });

    if (result && result.success) {
      window.showToast(result.toast || '<%== __("Contact created successfully") %>');
      const modal = bootstrap.Modal.getInstance(document.querySelector('#universalmodal'));
      if (modal) modal.hide();
      // Refresh the contact list
      setTimeout(() => location.reload(), 500);
    } else {
      window.showToast(result?.error || result?.toast || '<%== __("Failed to create contact") %>');
    }
  }

  // Form submission handler
  document.getElementById('contactForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    await saveContact();
  });
})();
