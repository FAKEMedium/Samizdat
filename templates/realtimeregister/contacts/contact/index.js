// RealtimeRegister contact detail
const contactDetails = document.getElementById('contactDetails');

fetch(window.location.href, {
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
})
.catch(error => {
  console.error('Error loading contact:', error);
  contactDetails.querySelector('.card-body').innerHTML = '<p class="text-danger"><%== __('Error loading contact details') %></p>';
});
