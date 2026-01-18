// Domain sidebar management
function initDomainSidebar(websiteid, domains, primarydomain) {
  renderDomains(domains, primarydomain);

  document.getElementById('addDomainBtn')?.addEventListener('click', () => {
    openAddDomainModal(websiteid);
  });
}

function renderDomains(domains, primarydomain) {
  const list = document.getElementById('domainList');
  if (!list) return;

  list.innerHTML = domains.map(domain => {
    const isPrimary = domain.domainid === primarydomain;
    return `
      <li class="list-group-item d-flex justify-content-between align-items-center py-2">
        <span${isPrimary ? ' class="fw-bold"' : ''}>
          ${domain.domainname}
          ${isPrimary ? '<span class="badge bg-primary ms-1"><%== __("Primary") %></span>' : ''}
        </span>
        ${!isPrimary ? `
          <button type="button" class="btn btn-sm btn-outline-danger btn-delete-domain" data-domainid="${domain.domainid}" data-domainname="${domain.domainname}" title="<%== __('Delete') %>">
            <%== icon 'trash' %>
          </button>
        ` : ''}
      </li>
    `;
  }).join('');

  // Attach event listeners
  list.querySelectorAll('.btn-delete-domain').forEach(btn => {
    btn.addEventListener('click', () => deleteDomain(parseInt(btn.dataset.domainid), btn.dataset.domainname));
  });
}

async function openAddDomainModal(wsid) {
  const modalDialog = document.getElementById('modalDialog');
  const universalModal = new bootstrap.Modal('#universalmodal');

  modalDialog.innerHTML = `
    <div class="modal-content">
      <div class="modal-header">
        <h5 class="modal-title"><%== __('Add Domain') %></h5>
        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body">
        <div class="mb-3">
          <label for="newDomainName" class="form-label"><%== __('Domain Name') %></label>
          <input type="text" class="form-control" id="newDomainName" placeholder="example.com">
        </div>
        <div class="form-check">
          <input type="checkbox" class="form-check-input" id="newDomainIncert" checked>
          <label class="form-check-label" for="newDomainIncert"><%== __('Include in certificate') %></label>
        </div>
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal"><%== __('Cancel') %></button>
        <button type="button" class="btn btn-primary" id="saveDomainBtn"><%== __('Add') %></button>
      </div>
    </div>
  `;

  document.getElementById('saveDomainBtn').onclick = async () => {
    const domainname = document.getElementById('newDomainName').value.trim();
    const incert = document.getElementById('newDomainIncert').checked;

    if (!domainname) {
      showToast('error', '<%== __("Domain name is required") %>');
      return;
    }

    const url = `<%== url_for('Website.domains.create', websiteid => '_ID_') %>`.replace('_ID_', wsid);
    const result = await window.authenticatedFetch(url, {
      method: 'POST',
      body: JSON.stringify({ domainname, incert })
    });

    if (result && result.success) {
      universalModal.hide();
      showToast('success', '<%== __("Domain added") %>');
      loadWebsite();
    } else {
      showToast('error', result?.error || '<%== __("Failed to add domain") %>');
    }
  };

  universalModal.show();
  document.getElementById('newDomainName').focus();
}

async function deleteDomain(domainid, domainname) {
  if (!confirm(`<%== __('Delete domain') %> ${domainname}?`)) {
    return;
  }

  const url = `<%== url_for('Website.domains.delete', websiteid => '_ID_', domainid => '_DID_') %>`
    .replace('_ID_', websiteid)
    .replace('_DID_', domainid);

  const result = await window.authenticatedFetch(url, { method: 'DELETE' });

  if (result && result.success) {
    showToast('success', '<%== __("Domain deleted") %>');
    loadWebsite();
  } else {
    showToast('error', result?.error || '<%== __("Failed to delete domain") %>');
  }
}
