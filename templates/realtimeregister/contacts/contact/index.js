// RealtimeRegister contact detail
const contactHandle = '<%= stash('handle') %>';
const contactDetails = document.getElementById('contactDetails');

fetch(window.location.href, {
  headers: { 'Accept': 'application/json' }
})
.then(response => response.json())
.then(data => {
  if (!data.contact) {
    contactDetails.querySelector('.card-body').innerHTML = '<p class="text-danger"><%== __('Contact not found') %></p>';
    return;
  }

  const contact = data.contact;
  contactDetails.querySelector('.card-body').innerHTML = `
    <dl class="row">
      <dt class="col-sm-3"><%== __('Handle') %></dt>
      <dd class="col-sm-9">${contact.handle || 'N/A'}</dd>

      <dt class="col-sm-3"><%== __('Name') %></dt>
      <dd class="col-sm-9">${contact.firstName || ''} ${contact.lastName || ''}</dd>

      <dt class="col-sm-3"><%== __('Organization') %></dt>
      <dd class="col-sm-9">${contact.organization || 'N/A'}</dd>

      <dt class="col-sm-3"><%== __('Email') %></dt>
      <dd class="col-sm-9"><a href="mailto:${contact.email}">${contact.email || 'N/A'}</a></dd>

      <dt class="col-sm-3"><%== __('Phone') %></dt>
      <dd class="col-sm-9">${contact.voice || 'N/A'}</dd>

      <dt class="col-sm-3"><%== __('Fax') %></dt>
      <dd class="col-sm-9">${contact.fax || 'N/A'}</dd>
    </dl>

    ${contact.addressLine1 || contact.city || contact.country ? `
      <h3 class="h6 mt-4"><%== __('Address') %></h3>
      <address>
        ${contact.addressLine1 ? `${contact.addressLine1}<br>` : ''}
        ${contact.addressLine2 ? `${contact.addressLine2}<br>` : ''}
        ${contact.addressLine3 ? `${contact.addressLine3}<br>` : ''}
        ${contact.postalCode ? `${contact.postalCode} ` : ''}${contact.city || ''}<br>
        ${contact.state ? `${contact.state}<br>` : ''}
        ${contact.country || ''}
      </address>
    ` : ''}
  `;
})
.catch(error => {
  console.error('Error loading contact:', error);
  contactDetails.querySelector('.card-body').innerHTML = '<p class="text-danger"><%== __('Error loading contact details') %></p>';
});
