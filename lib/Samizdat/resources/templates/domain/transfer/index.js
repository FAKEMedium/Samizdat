(async function () {
  const form = document.querySelector('#transferForm');
  const registrantSelect = document.querySelector('#registrant');
  const adminSelect = document.querySelector('#admin');
  const techSelect = document.querySelector('#tech');

  // Load contacts for dropdowns
  async function loadContacts() {
    const data = await window.authenticatedFetch('<%== url_for('domain_contacts') %>');
    if (data && data.contacts) {
      const options = data.contacts.map(c =>
        `<option value="${c.handle}">${c.handle} - ${c.name}</option>`
      ).join('');

      registrantSelect.innerHTML = `<option value=""><%== __('Select contact...') %></option>${options}`;
      adminSelect.innerHTML = `<option value=""><%== __('Same as registrant') %></option>${options}`;
      techSelect.innerHTML = `<option value=""><%== __('Same as registrant') %></option>${options}`;
    }
  }

  // Form submission
  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    const formData = new FormData(form);

    const data = {
      domainname: formData.get('domainname'),
      authcode: formData.get('authcode'),
      period: parseInt(formData.get('period')),
      registrant: formData.get('registrant'),
      admin: formData.get('admin') || formData.get('registrant'),
      tech: formData.get('tech') || formData.get('registrant'),
    };

    const result = await window.authenticatedFetch('<%== url_for('Domain.transfer.create') %>', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });

    if (result && result.success) {
      window.showToast?.('<%== __("Domain transfer initiated") %>');
      window.location.href = '<%== url_for('domain_index') %>';
    } else {
      alert(result?.error || '<%== __("Failed to initiate transfer") %>');
    }
  });

  // Initial load
  loadContacts();
})();
