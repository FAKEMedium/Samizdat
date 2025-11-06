// RealtimeRegister domain detail
const domainName = '<%= stash('domain') %>';
const domainDetails = document.getElementById('domainDetails');

fetch(window.location.href, {
  headers: { 'Accept': 'application/json' }
})
.then(response => response.json())
.then(data => {
  if (!data.domain) {
    domainDetails.querySelector('.card-body').innerHTML = '<p class="text-danger"><%== __('Domain not found') %></p>';
    return;
  }

  const domain = data.domain;
  domainDetails.querySelector('.card-body').innerHTML = `
    <dl class="row">
      <dt class="col-sm-3"><%== __('Domain Name') %></dt>
      <dd class="col-sm-9">${domain.domainName || 'N/A'}</dd>

      <dt class="col-sm-3"><%== __('Status') %></dt>
      <dd class="col-sm-9"><span class="badge bg-${domain.status === 'ok' ? 'success' : 'warning'}">${domain.status || 'N/A'}</span></dd>

      <dt class="col-sm-3"><%== __('Created') %></dt>
      <dd class="col-sm-9">${domain.createdDate || 'N/A'}</dd>

      <dt class="col-sm-3"><%== __('Expires') %></dt>
      <dd class="col-sm-9">${domain.expiryDate || 'N/A'}</dd>

      <dt class="col-sm-3"><%== __('Updated') %></dt>
      <dd class="col-sm-9">${domain.updatedDate || 'N/A'}</dd>

      <dt class="col-sm-3"><%== __('Registrant') %></dt>
      <dd class="col-sm-9">${domain.registrant || 'N/A'}</dd>

      <dt class="col-sm-3"><%== __('Admin') %></dt>
      <dd class="col-sm-9">${domain.admin || 'N/A'}</dd>

      <dt class="col-sm-3"><%== __('Tech') %></dt>
      <dd class="col-sm-9">${domain.tech || 'N/A'}</dd>

      <dt class="col-sm-3"><%== __('Billing') %></dt>
      <dd class="col-sm-9">${domain.billing || 'N/A'}</dd>
    </dl>

    ${domain.ns && domain.ns.length > 0 ? `
      <h3 class="h6 mt-4"><%== __('Name Servers') %></h3>
      <ul>
        ${domain.ns.map(ns => `<li>${ns}</li>`).join('')}
      </ul>
    ` : ''}
  `;
})
.catch(error => {
  console.error('Error loading domain:', error);
  domainDetails.querySelector('.card-body').innerHTML = '<p class="text-danger"><%== __('Error loading domain details') %></p>';
});
