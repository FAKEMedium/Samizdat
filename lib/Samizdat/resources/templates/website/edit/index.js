// Website edit page handler
const pathParts = window.location.pathname.split('/').filter(Boolean);
const isNew = pathParts[pathParts.length - 1] === 'new';
const websiteid = isNew ? null : pathParts[pathParts.length - 1];

// Load website data
loadWebsite();

async function loadWebsite() {
  let url;
  if (isNew) {
    url = `<%== url_for('website_new') %>`;
  } else {
    url = `<%== url_for('website_edit', websiteid => '_ID_') %>`.replace('_ID_', websiteid);
  }
  console.log('Fetching website from:', url);

  const data = await window.authenticatedFetch(url, { method: 'GET' });
  console.log('Website edit data:', data);

  if (data) {
    populateForm(data.website || {}, data.servers || [], data.shells || [], data.domains || [], data.php_enabled, data.serverextra_enabled);

    // Initialize domain sidebar for existing websites
    if (!isNew && typeof initDomainSidebar === 'function') {
      initDomainSidebar(websiteid, data.domains || [], data.website?.primarydomain);
    }
  }
}

function populateForm(website, servers, shells, domains, php_enabled, serverextra_enabled) {
  console.log('Populating form with:', { website, servers: servers.length, shells: shells.length, domains: domains.length });

  // Populate servers dropdown
  const serverSelect = document.getElementById('serverid');
  servers.forEach(server => {
    const option = document.createElement('option');
    option.value = server.serverid;
    option.textContent = `${server.hostname} (${server.servertypename || ''})`;
    if (website.serverid === server.serverid) {
      option.selected = true;
    }
    serverSelect.appendChild(option);
  });

  // Populate shells dropdown
  const shellSelect = document.getElementById('shellid');
  shells.forEach(shell => {
    const option = document.createElement('option');
    option.value = shell.shellid;
    option.textContent = shell.shell;
    if (website.shellid === shell.shellid) {
      option.selected = true;
    }
    shellSelect.appendChild(option);
  });

  // Fill form fields
  if (website.customerid) {
    const customerLink = document.getElementById('customerid');
    customerLink.textContent = website.customerid;
    customerLink.href = `<%== url_for('customer_edit', customerid => '_ID_') %>`.replace('_ID_', website.customerid);
  }
  if (website.home) {
    document.getElementById('home').textContent = website.home;
  }
  if (website.ip4) {
    document.getElementById('ip4').value = website.ip4;
  }
  if (website.ip6) {
    document.getElementById('ip6').value = website.ip6;
  }
  if (website.redirecturl) {
    document.getElementById('redirecturl').value = website.redirecturl;
  }
  document.getElementById('active').checked = website.active > 0;
  document.getElementById('ip_only').checked = website.ip_only > 0;
  document.getElementById('php_enabled').checked = php_enabled > 0;
  document.getElementById('serverextra_enabled').checked = serverextra_enabled > 0;
}

// Handle form submission
document.getElementById('websiteForm').addEventListener('submit', async (e) => {
  e.preventDefault();

  const formData = {
    serverid: parseInt(document.getElementById('serverid').value) || null,
    shellid: parseInt(document.getElementById('shellid').value) || null,
    ip4: document.getElementById('ip4').value || null,
    ip6: document.getElementById('ip6').value || null,
    redirecturl: document.getElementById('redirecturl').value || null,
    active: document.getElementById('active').checked ? 1 : 0,
    ip_only: document.getElementById('ip_only').checked ? 1 : 0,
    php_enabled: document.getElementById('php_enabled').checked ? 1 : 0,
    serverextra_enabled: document.getElementById('serverextra_enabled').checked ? 1 : 0
  };

  let url, method;
  if (isNew) {
    url = '<%== url_for('Website.create') %>';
    method = 'POST';
  } else {
    url = `<%== url_for('Website.update', websiteid => '_ID_') %>`.replace('_ID_', websiteid);
    method = 'PUT';
  }

  const result = await window.authenticatedFetch(url, {
    method: method,
    body: JSON.stringify(formData)
  });

  if (result && result.error) {
    showToast('error', result.error);
  } else if (result && result.website) {
    if (isNew) {
      window.location.href = `<%== url_for('website_edit', websiteid => '_ID_') %>`.replace('_ID_', result.website.websiteid);
    } else {
      showToast('success', '<%== __("Website saved successfully") %>');
    }
  }
});

// PHP Config modal
document.getElementById('phpConfigBtn').addEventListener('click', async () => {
  if (isNew) {
    showToast('error', '<%== __("Save the website first") %>');
    return;
  }
  await openConfigModal('phpconfig');
});

// Server Extra modal
document.getElementById('serverextraConfigBtn').addEventListener('click', async () => {
  if (isNew) {
    showToast('error', '<%== __("Save the website first") %>');
    return;
  }
  await openConfigModal('serverextra');
});

async function openConfigModal(type) {
  const modalDialog = document.getElementById('modalDialog');
  const universalModal = new bootstrap.Modal('#universalmodal');

  // Make modal wide
  modalDialog.classList.add('modal-lg');

  // Fetch modal HTML
  const templateUrl = type === 'phpconfig'
    ? `<%== url_for('Website.phpconfig.get', websiteid => '_ID_') %>`.replace('_ID_', websiteid)
    : `<%== url_for('Website.serverextra.get', websiteid => '_ID_') %>`.replace('_ID_', websiteid);

  const response = await fetch(templateUrl);
  const html = await response.text();
  modalDialog.innerHTML = html;

  // Load config data
  const configData = await window.authenticatedFetch(templateUrl, { method: 'GET' });

  if (configData) {
    const textarea = modalDialog.querySelector('textarea');
    if (textarea) {
      textarea.value = configData.config || '';
    }
  }

  // Setup save button handler
  const saveBtn = type === 'phpconfig'
    ? modalDialog.querySelector('#savePhpConfig')
    : modalDialog.querySelector('#saveServerExtra');

  if (saveBtn) {
    saveBtn.onclick = async () => {
      const textarea = modalDialog.querySelector('textarea');
      const config = textarea ? textarea.value : '';

      const saveUrl = type === 'phpconfig'
        ? `<%== url_for('Website.phpconfig.update', websiteid => '_ID_') %>`.replace('_ID_', websiteid)
        : `<%== url_for('Website.serverextra.update', websiteid => '_ID_') %>`.replace('_ID_', websiteid);

      const result = await window.authenticatedFetch(saveUrl, {
        method: 'PUT',
        body: JSON.stringify({ config: config, active: true })
      });

      if (result && result.success) {
        universalModal.hide();
        showToast('success', '<%== __("Configuration saved") %>');
      } else {
        showToast('error', result?.error || '<%== __("Failed to save configuration") %>');
      }
    };
  }

  // Setup delete button handler
  const deleteBtn = type === 'phpconfig'
    ? modalDialog.querySelector('#deletePhpConfig')
    : modalDialog.querySelector('#deleteServerExtra');

  if (deleteBtn) {
    deleteBtn.onclick = async () => {
      if (!confirm('<%== __("Are you sure you want to delete this configuration?") %>')) {
        return;
      }

      const deleteUrl = type === 'phpconfig'
        ? `<%== url_for('Website.phpconfig.delete', websiteid => '_ID_') %>`.replace('_ID_', websiteid)
        : `<%== url_for('Website.serverextra.delete', websiteid => '_ID_') %>`.replace('_ID_', websiteid);

      const result = await window.authenticatedFetch(deleteUrl, {
        method: 'DELETE'
      });

      if (result && result.success) {
        universalModal.hide();
        // Uncheck the corresponding checkbox
        const checkbox = type === 'phpconfig'
          ? document.getElementById('php_enabled')
          : document.getElementById('serverextra_enabled');
        if (checkbox) checkbox.checked = false;
        showToast('success', '<%== __("Configuration deleted") %>');
      } else {
        showToast('error', result?.error || '<%== __("Failed to delete configuration") %>');
      }
    };
  }

  universalModal.show();
}

// Show toast notification
function showToast(type, message) {
  const toastHtml = `
    <div class="toast align-items-center text-white bg-${type === 'success' ? 'success' : 'danger'} border-0"
         role="alert"
         data-bs-autohide="true"
         data-bs-delay="3000">
      <div class="d-flex">
        <div class="toast-body">${message}</div>
        <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast"></button>
      </div>
    </div>
  `;

  const toastContainer = document.getElementById('toast-messages');
  if (toastContainer) {
    toastContainer.innerHTML = toastHtml;
    const toastEl = toastContainer.querySelector('.toast');
    const toast = new bootstrap.Toast(toastEl);
    toast.show();
  }
}
