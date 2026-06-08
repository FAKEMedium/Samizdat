(async function () {
  // Extract handle from URL path
  const pathParts = window.location.pathname.split('/');
  const handle = pathParts[pathParts.length - 1];

  async function fetchContact() {
    const url = `<%== url_for('domain_contacts') %>/${handle}`;
    const data = await window.authenticatedFetch(url);

    document.querySelector('#loading').style.display = 'none';

    if (data && data.contact) {
      populateContact(data.contact);
    } else {
      document.querySelector('#error-message').textContent = '<%== __("Contact not found") %>';
      document.querySelector('#error-message').style.display = 'block';
    }
  }

  function populateContact(contact) {
    document.querySelector('#contact-details').style.display = 'block';

    // Header
    document.querySelector('#contact-handle').textContent = contact.handle;
    const sourceBadge = contact.source === 'epp'
      ? '<span class="badge bg-info">EPP</span>'
      : '<span class="badge bg-success">RealtimeRegister</span>';
    document.querySelector('#source-badge').innerHTML = sourceBadge;

    // Details
    document.querySelector('#detail-handle').textContent = contact.handle || '';
    document.querySelector('#detail-name').textContent = contact.name || '';
    document.querySelector('#detail-organization').textContent = contact.organization || '-';
    document.querySelector('#detail-email').textContent = contact.email || '';
    document.querySelector('#detail-phone').textContent = contact.phone || '-';
    document.querySelector('#detail-fax').textContent = contact.fax || '-';

    // Address
    const street = Array.isArray(contact.street) ? contact.street : [];
    let addressHtml = street.filter(s => s).map(s => `${s}<br>`).join('');
    if (contact.postalCode || contact.city) {
      addressHtml += `${contact.postalCode || ''} ${contact.city || ''}`;
    }
    document.querySelector('#detail-address').innerHTML = addressHtml || '-';

    document.querySelector('#detail-country').textContent = contact.country || '-';

    // EPP-specific fields
    if (contact.orgno) {
      document.querySelector('#orgno-label').style.display = '';
      document.querySelector('#detail-orgno').style.display = '';
      document.querySelector('#detail-orgno').textContent = contact.orgno;
    }
    if (contact.vatno) {
      document.querySelector('#vatno-label').style.display = '';
      document.querySelector('#detail-vatno').style.display = '';
      document.querySelector('#detail-vatno').textContent = contact.vatno;
    }
  }

  // Delete button handler
  document.querySelector('#deleteContact')?.addEventListener('click', async () => {
    if (!confirm('<%== __("Are you sure you want to delete this contact?") %>')) return;

    const result = await window.authenticatedFetch(`<%== url_for('domain_contacts') %>/${handle}`, {
      method: 'DELETE'
    });

    if (result && result.success) {
      window.showToast?.('<%== __("Contact deleted") %>');
      window.location.href = '<%== url_for('domain_contacts') %>';
    } else {
      alert(result?.error || '<%== __("Failed to delete contact") %>');
    }
  });

  // Initial load
  fetchContact();
})();
