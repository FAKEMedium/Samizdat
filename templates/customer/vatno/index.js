// VAT lookup modal functionality
const vatlookupInput = document.getElementById('vatlookup-input');
const vatlookupBtn = document.getElementById('vatlookup-btn');
const vatlookupResult = document.getElementById('vatlookup-result');
const vatlookupSpinner = document.getElementById('vatlookup-spinner');
const vatlookupError = document.getElementById('vatlookup-error');
const vatlookupInfo = document.getElementById('vatlookup-info');
const vatName = document.getElementById('vat-name');
const vatAddress = document.getElementById('vat-address');

async function doVatLookup() {
  const vatNumber = vatlookupInput.value.trim().toUpperCase().replace(/\s+/g, '');
  if (!vatNumber) return;

  vatlookupResult.classList.add('d-none');
  vatlookupSpinner.classList.remove('d-none');
  vatlookupBtn.disabled = true;

  try {
    const response = await fetch(`<%== url_for('vatno') %>/${encodeURIComponent(vatNumber)}`, {
      headers: { 'Accept': 'application/json' }
    });
    const result = await response.json();

    vatlookupSpinner.classList.add('d-none');
    vatlookupResult.classList.remove('d-none');

    if (result.valid) {
      vatlookupError.classList.add('d-none');
      vatlookupInfo.classList.remove('d-none');
      vatName.textContent = result.info.name || '';
      vatAddress.textContent = result.info.address || '';
    } else {
      vatlookupInfo.classList.add('d-none');
      vatlookupError.classList.remove('d-none');
      vatlookupError.textContent = result.error || '<%== __('VAT number not valid') %>';
    }
  } catch (e) {
    vatlookupSpinner.classList.add('d-none');
    vatlookupResult.classList.remove('d-none');
    vatlookupInfo.classList.add('d-none');
    vatlookupError.classList.remove('d-none');
    vatlookupError.textContent = '<%== __('Connection error. Please try again.') %>';
  } finally {
    vatlookupBtn.disabled = false;
  }
}

if (vatlookupBtn) {
  vatlookupBtn.addEventListener('click', doVatLookup);
}

if (vatlookupInput) {
  vatlookupInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      doVatLookup();
    }
  });
}

// Pre-fill and auto-lookup if vatno was set before opening modal
if (window.vatnoForLookup && vatlookupInput) {
  vatlookupInput.value = window.vatnoForLookup;
  doVatLookup();
  window.vatnoForLookup = null;
} else if (vatlookupInput) {
  vatlookupInput.focus();
}
