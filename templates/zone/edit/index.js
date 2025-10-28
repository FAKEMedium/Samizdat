// Zone edit form handler (runs in modal context)
const path = window.location.pathname;
const match = path.match(/\/zones\/([^/]+)\/edit|\/zones\/new/);
const isNew = path.endsWith('/new');
const zoneId = !isNew && match ? match[1] : null;

// Load existing zone if editing
if (!isNew && zoneId) {
  loadZone();
}

// Form submission handler
document.getElementById('zoneForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  await saveZone();
});

// Load zone data for editing
async function loadZone() {
  const data = await window.authenticatedFetch(`<%== url_for('zone_index') %>/${zoneId}`, {
    method: 'GET',
    headers: { 'Accept': 'application/json' }
  });

  if (data && !data.error) {
    populateForm(data);
  }
}

// Populate form with zone data
function populateForm(zone) {
  document.getElementById('name').value = zone.name || '';
  document.getElementById('kind').value = zone.kind || 'Master';
}

// Save zone (create or update)
async function saveZone() {
  const form = document.getElementById('zoneForm');
  const formData = new FormData(form);

  // Convert FormData to object
  const data = {};
  for (const [key, value] of formData.entries()) {
    data[key] = value;
  }

  // Determine URL and method
  let url, method;
  if (isNew) {
    url = '<%== url_for('zone_create') %>';
    method = 'POST';
  } else {
    url = `<%== url_for('zone_index') %>/${zoneId}`;
    method = 'PATCH';
  }

  const result = await window.authenticatedFetch(url, {
    method: method,
    body: JSON.stringify(data),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    }
  });

  if (result && result.success) {
    window.showToast(result.toast || '<%== __("Zone saved successfully") %>');
    const modal = bootstrap.Modal.getInstance(document.querySelector('#universalmodal'));
    if (modal) modal.hide();
    // Refresh the zone list
    setTimeout(() => location.reload(), 500);
  } else {
    window.showToast(result?.toast || '<%== __("Failed to save zone") %>');
  }
}
