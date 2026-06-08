// RealtimeRegister domain detail
const domainDetails = document.getElementById('domainDetails');
const domainName = window.location.pathname.split('/').pop();
const apiUrl = `<%== url_for('RTR.domains.index') %>/${domainName}`;
const contactsApiUrl = `<%== url_for('RTR.contacts.index') %>`;

let currentDomain = null;
let contactsCache = null;  // Cache for contacts autocomplete

// Load domain details
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

  currentDomain = data.domain;
  const domain = data.domain;

  // Show edit and renew buttons
  document.getElementById('editDomainBtn').style.display = 'inline-block';
  document.getElementById('renewDomainBtn').style.display = 'inline-block';

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

// Edit button click handler
document.getElementById('editDomainBtn').addEventListener('click', () => {
  if (!currentDomain) return;

  const domain = currentDomain;

  // Populate form with current values
  document.getElementById('autoRenew').checked = domain.autoRenew || false;
  document.getElementById('privacyProtect').checked = domain.privacyProtect || false;
  document.getElementById('registrant').value = domain.registrant || '';

  // Reset and hide designatedAgent checkbox
  document.getElementById('designatedAgent').checked = false;
  document.getElementById('designatedAgentGroup').style.display = 'none';

  // Extract contact handles
  const adminContact = domain.contacts?.find(c => c.role === 'ADMIN');
  const techContact = domain.contacts?.find(c => c.role === 'TECH');
  const billingContact = domain.contacts?.find(c => c.role === 'BILLING');

  document.getElementById('adminContact').value = adminContact?.handle || '';
  document.getElementById('techContact').value = techContact?.handle || '';
  document.getElementById('billingContact').value = billingContact?.handle || '';

  // Populate nameservers
  const nsContainer = document.getElementById('nameserverInputs');
  nsContainer.innerHTML = '';
  if (domain.ns && domain.ns.length > 0) {
    domain.ns.forEach((ns, index) => addNameserverInput(ns));
  } else {
    // Add at least two empty inputs
    addNameserverInput('');
    addNameserverInput('');
  }

  // Show modal
  const modal = new bootstrap.Modal(document.getElementById('editDomainModal'));
  modal.show();
});

// Add nameserver input field
function addNameserverInput(value = '') {
  const nsContainer = document.getElementById('nameserverInputs');
  const index = nsContainer.children.length;
  const div = document.createElement('div');
  div.className = 'input-group mb-2';
  div.innerHTML = `
    <input type="text" class="form-control nameserver-input" name="ns[]" value="${value}" placeholder="ns${index + 1}.example.com">
    <button type="button" class="btn btn-outline-danger remove-ns" title="<%== __('Remove') %>">
      <i class="bi bi-trash"></i>
    </button>
  `;
  nsContainer.appendChild(div);

  // Add remove handler
  div.querySelector('.remove-ns').addEventListener('click', () => div.remove());
}

// Add nameserver button
document.getElementById('addNameserver').addEventListener('click', () => {
  addNameserverInput('');
});

// Show designatedAgent checkbox when registrant changes
document.getElementById('registrant').addEventListener('input', () => {
  const newRegistrant = document.getElementById('registrant').value.trim();
  const originalRegistrant = currentDomain?.registrant || '';
  const designatedAgentGroup = document.getElementById('designatedAgentGroup');
  if (newRegistrant && newRegistrant !== originalRegistrant) {
    designatedAgentGroup.style.display = 'block';
  } else {
    designatedAgentGroup.style.display = 'none';
  }
});

// Fetch and cache contacts for autocomplete
async function fetchContacts() {
  if (contactsCache) return contactsCache;

  try {
    const response = await fetch(`${contactsApiUrl}?limit=250`, {
      headers: { 'Accept': 'application/json' },
      credentials: 'same-origin'
    });
    const data = await response.json();
    // API returns { contacts: { entities: [...], pagination: {...} } }
    contactsCache = data.contacts?.entities || [];
    console.log('Contacts cached:', contactsCache.length);
    return contactsCache;
  } catch (error) {
    console.error('Error fetching contacts:', error);
    return [];
  }
}

// Filter contacts based on query
function filterContacts(query) {
  if (!contactsCache || !query) return [];
  const q = query.toLowerCase();
  return contactsCache.filter(c => {
    const handle = (c.handle || '').toLowerCase();
    const name = (c.name || '').toLowerCase();
    const org = (c.organization || '').toLowerCase();
    return handle.includes(q) || name.includes(q) || org.includes(q);
  }).slice(0, 10);
}

// Setup autocomplete for contact input fields
function initContactAutocomplete() {
  const contactInputIds = ['registrant', 'adminContact', 'techContact', 'billingContact'];

  contactInputIds.forEach(inputId => {
    const input = document.getElementById(inputId);
    if (!input) return;

    // Add autocomplete attribute
    input.setAttribute('autocomplete', 'off');

    // Create dropdown
    const dropdownId = `${inputId}-dropdown`;
    let dropdown = document.getElementById(dropdownId);
    if (!dropdown) {
      dropdown = document.createElement('div');
      dropdown.id = dropdownId;
      dropdown.className = 'list-group position-absolute w-100 shadow';
      dropdown.style.cssText = 'max-height: 200px; overflow-y: auto; z-index: 1055; display: none; top: 100%;';
      input.parentNode.style.position = 'relative';
      input.parentNode.appendChild(dropdown);
    }

    let selectedIdx = -1;

    function showDropdown(contacts) {
      if (!contacts.length) {
        dropdown.style.display = 'none';
        return;
      }
      dropdown.innerHTML = contacts.map((c, i) =>
        `<a href="#" class="list-group-item list-group-item-action py-1 ${i === selectedIdx ? 'active' : ''}" data-handle="${c.handle}">
          <strong>${c.handle}</strong>
          ${c.name ? `<small class="text-muted d-block">${c.name}${c.organization ? ` - ${c.organization}` : ''}</small>` : ''}
        </a>`
      ).join('');
      dropdown.style.display = 'block';

      dropdown.querySelectorAll('a').forEach(a => {
        a.addEventListener('mousedown', (e) => {
          e.preventDefault();
          input.value = a.dataset.handle;
          dropdown.style.display = 'none';
        });
      });
    }

    input.addEventListener('input', async () => {
      const q = input.value.trim();
      if (q.length < 1) {
        dropdown.style.display = 'none';
        return;
      }
      await fetchContacts();
      selectedIdx = -1;
      showDropdown(filterContacts(q));
    });

    input.addEventListener('keydown', (e) => {
      const items = dropdown.querySelectorAll('a');
      if (!items.length || dropdown.style.display === 'none') return;

      if (e.key === 'ArrowDown') {
        e.preventDefault();
        selectedIdx = Math.min(selectedIdx + 1, items.length - 1);
        items.forEach((el, i) => el.classList.toggle('active', i === selectedIdx));
        items[selectedIdx]?.scrollIntoView({ block: 'nearest' });
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        selectedIdx = Math.max(selectedIdx - 1, 0);
        items.forEach((el, i) => el.classList.toggle('active', i === selectedIdx));
        items[selectedIdx]?.scrollIntoView({ block: 'nearest' });
      } else if (e.key === 'Enter') {
        if (selectedIdx >= 0 && items[selectedIdx]) {
          e.preventDefault();
          input.value = items[selectedIdx].dataset.handle;
          dropdown.style.display = 'none';
          selectedIdx = -1;
        }
      } else if (e.key === 'Escape') {
        dropdown.style.display = 'none';
      }
    });

    input.addEventListener('blur', () => {
      setTimeout(() => { dropdown.style.display = 'none'; }, 150);
    });

    input.addEventListener('focus', async () => {
      const q = input.value.trim();
      if (q.length >= 1) {
        await fetchContacts();
        showDropdown(filterContacts(q));
      }
    });
  });
}

// Initialize autocomplete when modal is shown
document.getElementById('editDomainModal')?.addEventListener('shown.bs.modal', initContactAutocomplete);

// Renew button click handler
document.getElementById('renewDomainBtn').addEventListener('click', () => {
  if (!currentDomain) return;

  const modalDialog = document.getElementById('modalDialog');
  const universalModal = new bootstrap.Modal('#universalmodal');

  modalDialog.innerHTML = `
    <div class="modal-content">
      <div class="modal-header">
        <h5 class="modal-title"><%== __('Renew Domain') %></h5>
        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
      </div>
      <div class="modal-body">
        <p><%== __('Renew') %> <strong>${currentDomain.domainName}</strong></p>
        <p class="text-muted small"><%== __('Current expiry') %>: ${currentDomain.expiryDate || 'N/A'}</p>
        <div class="mb-3">
          <label for="renewPeriod" class="form-label"><%== __('Renewal period') %></label>
          <select class="form-select" id="renewPeriod">
% for my $m (12..23) {
            <option value="<%= $m %>"<%= $m == 12 ? ' selected' : '' %>><%= $m %> <%== __('months') %></option>
% }
% for my $y (2..5) {
            <option value="<%= $y * 12 %>"><%= $y %> <%== __('years') %></option>
% }
          </select>
        </div>
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal"><%== __('Cancel') %></button>
        <button type="button" class="btn btn-primary" id="confirmRenewBtn">
          <span class="spinner-border spinner-border-sm d-none" role="status"></span>
          <%== __('Renew') %>
        </button>
      </div>
    </div>
  `;

  document.getElementById('confirmRenewBtn').addEventListener('click', async () => {
    const btn = document.getElementById('confirmRenewBtn');
    const spinner = btn.querySelector('.spinner-border');
    const period = parseInt(document.getElementById('renewPeriod').value);

    btn.disabled = true;
    spinner.classList.remove('d-none');

    try {
      const response = await fetch(`${apiUrl}/renew`, {
        method: 'POST',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json'
        },
        credentials: 'same-origin',
        body: JSON.stringify({ period })
      });

      const result = await response.json();

      if (response.ok && result.success) {
        universalModal.hide();
        window.location.reload();
      } else {
        alert(result.error || '<%== __('Failed to renew domain') %>');
      }
    } catch (error) {
      console.error('Error renewing domain:', error);
      alert('<%== __('Error renewing domain') %>');
    } finally {
      btn.disabled = false;
      spinner.classList.add('d-none');
    }
  });

  universalModal.show();
});

// Save domain changes
document.getElementById('saveDomainBtn').addEventListener('click', async () => {
  const saveBtn = document.getElementById('saveDomainBtn');
  const spinner = saveBtn.querySelector('.spinner-border');

  // Show loading state
  saveBtn.disabled = true;
  spinner.classList.remove('d-none');

  try {
    // Collect form data
    const updateData = {};

    // Boolean fields - only include if changed
    const autoRenew = document.getElementById('autoRenew').checked;
    const privacyProtect = document.getElementById('privacyProtect').checked;

    if (autoRenew !== currentDomain.autoRenew) {
      updateData.autoRenew = autoRenew;
    }
    if (privacyProtect !== currentDomain.privacyProtect) {
      updateData.privacyProtect = privacyProtect;
    }

    // Registrant - only include if changed
    const registrant = document.getElementById('registrant').value.trim();
    if (registrant && registrant !== currentDomain.registrant) {
      updateData.registrant = registrant;
      // Include designatedAgent when changing registrant
      updateData.designatedAgent = document.getElementById('designatedAgent').checked;
    }

    // Nameservers - collect all non-empty values
    const nsInputs = document.querySelectorAll('.nameserver-input');
    const nameservers = Array.from(nsInputs)
      .map(input => input.value.trim())
      .filter(ns => ns);

    // Compare with current nameservers
    const currentNs = currentDomain.ns || [];
    if (JSON.stringify(nameservers) !== JSON.stringify(currentNs)) {
      updateData.ns = nameservers;
    }

    // Contacts - build contacts object if any changed
    const adminHandle = document.getElementById('adminContact').value.trim();
    const techHandle = document.getElementById('techContact').value.trim();
    const billingHandle = document.getElementById('billingContact').value.trim();

    const currentAdmin = currentDomain.contacts?.find(c => c.role === 'ADMIN')?.handle || '';
    const currentTech = currentDomain.contacts?.find(c => c.role === 'TECH')?.handle || '';
    const currentBilling = currentDomain.contacts?.find(c => c.role === 'BILLING')?.handle || '';

    const contacts = {};
    let contactsChanged = false;

    if (adminHandle !== currentAdmin) {
      contacts.admin = adminHandle ? [adminHandle] : [];
      contactsChanged = true;
    }
    if (techHandle !== currentTech) {
      contacts.tech = techHandle ? [techHandle] : [];
      contactsChanged = true;
    }
    if (billingHandle !== currentBilling) {
      contacts.billing = billingHandle ? [billingHandle] : [];
      contactsChanged = true;
    }

    if (contactsChanged) {
      updateData.contacts = contacts;
    }

    // Check if anything changed
    if (Object.keys(updateData).length === 0) {
      alert('<%== __('No changes to save') %>');
      return;
    }

    console.log('Updating domain with:', updateData);

    // Send update request
    const response = await fetch(apiUrl, {
      method: 'POST',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json'
      },
      credentials: 'same-origin',
      body: JSON.stringify(updateData)
    });

    const result = await response.json();

    if (response.ok && result.success) {
      // Close modal and reload page
      bootstrap.Modal.getInstance(document.getElementById('editDomainModal')).hide();
      window.location.reload();
    } else {
      alert(result.error || '<%== __('Failed to update domain') %>');
    }
  } catch (error) {
    console.error('Error updating domain:', error);
    alert('<%== __('Error updating domain') %>');
  } finally {
    saveBtn.disabled = false;
    spinner.classList.add('d-none');
  }
});
