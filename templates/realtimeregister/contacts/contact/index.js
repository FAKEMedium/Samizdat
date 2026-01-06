// RealtimeRegister contact detail
const contactDetails = document.getElementById('contactDetails');
const contactActions = document.getElementById('contactActions');
const editContactBtn = document.getElementById('editContactBtn');
const deleteContactBtn = document.getElementById('deleteContactBtn');
const handle = window.location.pathname.split('/').pop();
const apiUrl = `<%== url_for('RTR.contacts.index') %>/${handle}`;
let currentContact = null;

fetch(apiUrl, {
  headers: { 'Accept': 'application/json' },
  credentials: 'same-origin'
})
.then(response => {
  console.log('Response status:', response.status);
  if (!response.ok) {
    throw new Error(`HTTP error! status: ${response.status}`);
  }
  return response.json();
})
.then(data => {
  console.log('Received data:', data);
  if (!data.contact) {
    contactDetails.querySelector('.card-body').innerHTML = '<p class="text-danger"><%== __('Contact not found') %></p>';
    return;
  }

  const contact = data.contact;

  // Update page title with contact handle
  document.title = `<%== __('Contact details') %> - ${contact.handle}`;
  contactDetails.querySelector('h2').innerHTML = `${contact.name || contact.handle}`;
  contactDetails.querySelector('.card-body').innerHTML = `
    <dl class="row">
      <dt class="col-sm-3"><%== __('Handle') %></dt>
      <dd class="col-sm-9">${contact.handle || 'N/A'}</dd>

      <dt class="col-sm-3"><%== __('Name') %></dt>
      <dd class="col-sm-9">${contact.name || 'N/A'}</dd>

      <dt class="col-sm-3"><%== __('Organization') %></dt>
      <dd class="col-sm-9">${contact.organization || 'N/A'}</dd>

      <dt class="col-sm-3"><%== __('Email') %></dt>
      <dd class="col-sm-9">${contact.email ? `<a href="mailto:${contact.email}">${contact.email}</a>` : 'N/A'}</dd>

      <dt class="col-sm-3"><%== __('Phone') %></dt>
      <dd class="col-sm-9">${contact.voice || 'N/A'}</dd>

      <dt class="col-sm-3"><%== __('Customer') %></dt>
      <dd class="col-sm-9">${contact.customer || 'N/A'}</dd>

      <dt class="col-sm-3"><%== __('Created') %></dt>
      <dd class="col-sm-9">${contact.createdDate || 'N/A'}</dd>

      <dt class="col-sm-3"><%== __('Updated') %></dt>
      <dd class="col-sm-9">${contact.updatedDate || 'N/A'}</dd>
    </dl>

    ${contact.addressLine || contact.city || contact.country ? `
      <h3 class="h6 mt-4"><%== __('Address') %></h3>
      <address>
        ${contact.addressLine && contact.addressLine.length > 0 ? contact.addressLine.map(line => `${line}<br>`).join('') : ''}
        ${contact.postalCode ? `${contact.postalCode} ` : ''}${contact.city || ''}<br>
        ${contact.state ? `${contact.state}<br>` : ''}
        ${contact.country || ''}
      </address>
    ` : ''}

    ${contact.registries && contact.registries.length > 0 ? `
      <h3 class="h6 mt-4"><%== __('Registries') %></h3>
      <div>
        ${contact.registries.map(reg => `<span class="badge bg-secondary me-1">${reg}</span>`).join('')}
      </div>
    ` : ''}
  `;

  // Show action buttons and store contact
  currentContact = contact;
  contactActions.classList.remove('d-none');
})
.catch(error => {
  console.error('Error loading contact:', error);
  contactDetails.querySelector('.card-body').innerHTML = '<p class="text-danger"><%== __('Error loading contact details') %></p>';
});

// Edit button handler - opens edit modal
editContactBtn.addEventListener('click', async () => {
  if (!currentContact) return;

  const modalDialog = document.querySelector('#universalmodal #modalDialog');
  if (modalDialog) modalDialog.classList.add('modal-xl');

  // Open edit form with handle parameter
  await window.openModalFromUrl(`<%== url_for('domain_contact_new') %>?handle=${encodeURIComponent(currentContact.handle)}&registries=rr`);
});

// Delete button handler
deleteContactBtn.addEventListener('click', async () => {
  if (!currentContact) return;

  // Confirm deletion
  if (!confirm(`<%== __('Are you sure you want to delete contact') %> "${currentContact.handle}"?`)) {
    return;
  }

  try {
    const response = await fetch(apiUrl, {
      method: 'DELETE',
      headers: { 'Accept': 'application/json' },
      credentials: 'same-origin'
    });

    if (response.ok) {
      window.showToast('<%== __('Contact deleted successfully') %>');
      // Redirect to contacts list
      setTimeout(() => {
        window.location.href = '<%== url_for('RTR.contacts.index') %>';
      }, 500);
    } else {
      const data = await response.json().catch(() => ({}));
      window.showToast(data.error || '<%== __('Failed to delete contact') %>');
    }
  } catch (error) {
    console.error('Error deleting contact:', error);
    window.showToast('<%== __('Error deleting contact') %>');
  }
});
