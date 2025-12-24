(async function () {
  const form = document.querySelector('#registerForm');
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

  // Add nameserver input
  document.querySelector('#addNs')?.addEventListener('click', () => {
    const container = document.querySelector('#nameservers');
    const div = document.createElement('div');
    div.className = 'input-group mb-2';
    div.innerHTML = `
      <input type="text" class="form-control" name="ns[]" placeholder="ns.example.com">
      <button type="button" class="btn btn-outline-danger btn-remove-ns"><%== icon 'trash', {} %></button>
    `;
    container.appendChild(div);

    div.querySelector('.btn-remove-ns').addEventListener('click', () => div.remove());
  });

  // Form submission
  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    const formData = new FormData(form);
    const nameservers = formData.getAll('ns[]').filter(ns => ns.trim());

    const data = {
      domainname: formData.get('domainname'),
      period: parseInt(formData.get('period')),
      registrant: formData.get('registrant'),
      admin: formData.get('admin') || formData.get('registrant'),
      tech: formData.get('tech') || formData.get('registrant'),
      nameservers: nameservers,
    };

    const result = await window.authenticatedFetch('<%== url_for('Domain.register.create') %>', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });

    if (result && result.success) {
      window.showToast?.('<%== __("Domain registered") %>');
      window.location.href = '<%== url_for('domain_index') %>';
    } else {
      alert(result?.error || '<%== __("Failed to register domain") %>');
    }
  });

  // Initial load
  loadContacts();
})();
