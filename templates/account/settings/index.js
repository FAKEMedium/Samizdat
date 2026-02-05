const profileForm = document.getElementById('profileForm');
const saveStatus = document.getElementById('saveStatus');
const settingsApiUrl = '<%= url_for("Account.settings.get") %>';
const givenNameInput = document.getElementById('givenname');
const commonNameInput = document.getElementById('commonname');
const displayNameInput = document.getElementById('displayname');
const countrySelect = document.getElementById('country');
const stateRow = document.getElementById('staterow');
const stateSelect = document.getElementById('stateid');

// Auto-compute displayname from givenname + commonname
function updateDisplayName() {
  const given = givenNameInput.value.trim();
  const common = commonNameInput.value.trim();
  displayNameInput.value = [given, common].filter(Boolean).join(' ');
}
givenNameInput.addEventListener('input', updateDisplayName);
commonNameInput.addEventListener('input', updateDisplayName);

// Country change: show/hide state select for US
countrySelect.addEventListener('change', async () => {
  if (countrySelect.value === 'US') {
    await loadStates();
    stateRow.classList.remove('d-none');
  } else {
    stateRow.classList.add('d-none');
    stateSelect.value = '';
  }
});

// Load states for a country
async function loadStates() {
  if (stateSelect.options.length > 1) return; // Already loaded
  try {
    const response = await fetch('<%= url_for("public_states", cc => "_CC_") %>'.replace('_CC_', 'US'), {
      headers: { Accept: 'application/json' }
    });
    if (!response.ok) return;
    const data = await response.json();
    const states = data.states || [];
    for (const state of states) {
      const option = document.createElement('option');
      option.value = state.stateid;
      option.textContent = state.statename;
      stateSelect.appendChild(option);
    }
  } catch (e) {
    console.error('Failed to load states:', e);
  }
}

// Load current profile data
async function loadProfile() {
  const result = await window.authenticatedFetch(settingsApiUrl, {
    method: 'GET'
  });
  if (result && result.success && result.profile) {
    populateForm(result.profile);
  }
}

// Populate form with profile data
function populateForm(profile) {
  const c = profile.contacts || {};

  givenNameInput.value = c.givenname || '';
  commonNameInput.value = c.commonname || '';
  displayNameInput.value = c.displayname || '';
  document.getElementById('email').value = c.email || '';
  document.getElementById('organization').value = c.organization || '';
  document.getElementById('address').value = c.address || '';
  document.getElementById('pc').value = c.pc || '';
  document.getElementById('city').value = (c.city || '').trim();
  document.getElementById('telephone').value = c.telephone || '';
  document.getElementById('mobile').value = c.mobile || '';
  document.getElementById('website').value = c.website || '';
  document.getElementById('dob').value = c.dob ? c.dob.substring(0, 10) : '';

  // Set country by alpha2 code
  if (c.country_cc) {
    countrySelect.value = c.country_cc;
    // Show state row if US
    if (c.country_cc === 'US') {
      loadStates().then(() => {
        if (c.stateid) stateSelect.value = c.stateid;
        stateRow.classList.remove('d-none');
      });
    }
  }

  // Set language by code, fall back to session language
  document.getElementById('language').value = c.language_code || profile.language || '';
}

// Handle form submission
profileForm.addEventListener('submit', async (e) => {
  e.preventDefault();

  const formData = new FormData(profileForm);
  const profileData = { contacts: {} };

  // Parse form data into contacts section
  for (let [name, value] of formData.entries()) {
    const match = name.match(/^contacts\[(\w+)\]$/);
    if (match) {
      profileData.contacts[match[1]] = value;
    }
  }

  const result = await window.authenticatedFetch(settingsApiUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(profileData)
  });

  if (result) {
    if (result.success) {
      showStatus('success', result.message || '<%== __("Settings saved") %>');
      setTimeout(() => loadProfile(), 1000);
    } else {
      showStatus('error', result.error || '<%== __("Failed to save") %>');
    }
  }
});

// Show status message
function showStatus(type, message) {
  const alertDiv = saveStatus.querySelector('.alert');
  alertDiv.className = `alert alert-${type === 'success' ? 'success' : 'danger'}`;
  alertDiv.textContent = message;
  saveStatus.classList.remove('d-none');
  setTimeout(() => saveStatus.classList.add('d-none'), 5000);
}

// Cancel button handler
document.getElementById('cancelSettings').addEventListener('click', () => {
  loadProfile();
});

loadProfile();
