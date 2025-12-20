// RealtimeRegister domain detail
const domainDetails = document.getElementById('domainDetails');
const domainName = window.location.pathname.split('/').pop();
const apiUrl = `<%== url_for('RTR.domains.index') %>/${domainName}`;

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
  if (!data.domain) {
    domainDetails.querySelector('.card-body').innerHTML = '<p class="text-danger"><%== __('Domain not found') %></p>';
    return;
  }

  const domain = data.domain;

  // Extract contact handles by role
  const adminContact = domain.contacts?.find(c => c.role === 'ADMIN');
  const techContact = domain.contacts?.find(c => c.role === 'TECH');
  const billingContact = domain.contacts?.find(c => c.role === 'BILLING');

  // Update page title with domain name
  document.title = `<%== __('Domain details') %> - ${domain.domainName}`;
  domainDetails.querySelector('h2').innerHTML = `${domain.domainName}`;
  domainDetails.querySelector('.card-body').innerHTML = `
    <dl class="row">
      <dt class="col-sm-3"><%== __('Domain Name') %></dt>
      <dd class="col-sm-9">${domain.domainName || 'N/A'}</dd>

      <dt class="col-sm-3"><%== __('Status') %></dt>
      <dd class="col-sm-9">${domain.status && domain.status.length > 0 ? domain.status.map(s => `<span class="badge bg-${s === 'OK' ? 'success' : 'warning'}">${s}</span>`).join(' ') : 'N/A'}</dd>

      <dt class="col-sm-3"><%== __('Created') %></dt>
      <dd class="col-sm-9">${domain.createdDate || 'N/A'}</dd>

      <dt class="col-sm-3"><%== __('Expires') %></dt>
      <dd class="col-sm-9">${domain.expiryDate || 'N/A'}</dd>

      <dt class="col-sm-3"><%== __('Updated') %></dt>
      <dd class="col-sm-9">${domain.updatedDate || 'N/A'}</dd>

      <dt class="col-sm-3"><%== __('Registrant') %></dt>
      <dd class="col-sm-9">${domain.registrant ? `<a href="<%== url_for('rtr_contacts') %>/${domain.registrant}">${domain.registrant}</a>` : 'N/A'}</dd>

      <dt class="col-sm-3"><%== __('Admin') %></dt>
      <dd class="col-sm-9">${adminContact ? `<a href="<%== url_for('rtr_contacts') %>/${adminContact.handle}">${adminContact.handle}</a>` : 'N/A'}</dd>

      <dt class="col-sm-3"><%== __('Tech') %></dt>
      <dd class="col-sm-9">${techContact ? `<a href="<%== url_for('rtr_contacts') %>/${techContact.handle}">${techContact.handle}</a>` : 'N/A'}</dd>

      <dt class="col-sm-3"><%== __('Billing') %></dt>
      <dd class="col-sm-9">${billingContact ? `<a href="<%== url_for('rtr_contacts') %>/${billingContact.handle}">${billingContact.handle}</a>` : 'N/A'}</dd>

      <dt class="col-sm-3"><%== __('Auto Renew') %></dt>
      <dd class="col-sm-9"><span class="badge bg-${domain.autoRenew ? 'success' : 'secondary'}">${domain.autoRenew ? '<%== __('Yes') %>' : '<%== __('No') %>'}</span></dd>

      <dt class="col-sm-3"><%== __('Privacy Protection') %></dt>
      <dd class="col-sm-9"><span class="badge bg-${domain.privacyProtect ? 'success' : 'secondary'}">${domain.privacyProtect ? '<%== __('Enabled') %>' : '<%== __('Disabled') %>'}</span></dd>

      <dt class="col-sm-3"><%== __('Registry') %></dt>
      <dd class="col-sm-9">${domain.registry || 'N/A'}</dd>
    </dl>

    ${domain.ns && domain.ns.length > 0 ? `
      <h3 class="h6 mt-4"><%== __('Name Servers') %></h3>
      <ul>
        ${domain.ns.map(ns => `<li>${ns}</li>`).join('')}
      </ul>
    ` : ''}

    ${domain.keyData && domain.keyData.length > 0 ? `
      <h3 class="h6 mt-4"><%== __('DNSSEC Key Data') %></h3>
      <div class="table-responsive">
        <table class="table table-sm">
          <thead>
            <tr>
              <th><%== __('Flags') %></th>
              <th><%== __('Protocol') %></th>
              <th><%== __('Algorithm') %></th>
              <th><%== __('Public Key') %></th>
            </tr>
          </thead>
          <tbody>
            ${domain.keyData.map(key => `
              <tr>
                <td>${key.flags}</td>
                <td>${key.protocol}</td>
                <td>${key.algorithm}</td>
                <td><code class="text-break">${key.publicKey}</code></td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      </div>
    ` : ''}
  `;
})
.catch(error => {
  console.error('Error loading domain:', error);
  domainDetails.querySelector('.card-body').innerHTML = '<p class="text-danger"><%== __('Error loading domain details') %></p>';
});
