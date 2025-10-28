// Zone record edit form handler (runs in modal context)
const path = window.location.pathname;
const match = path.match(/\/zones\/([^/]+)\/records\/([^/]+)/);
const zoneId = match ? match[1] : null;
const recordId = match ? match[2] : 'new';

// Load existing record if editing
if (recordId !== 'new') {
  loadRecord();
}

// Form submission handler
document.getElementById('recordForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  await saveRecord();
});

// Load record data for editing
async function loadRecord() {
  const data = await window.authenticatedFetch(window.location.pathname, {
    method: 'GET'
  });

  if (data && data.success && data.record) {
    populateForm(data.record);
  }
}

// Populate form with record data
function populateForm(record) {
  document.getElementById('name').value = record.name || '';
  document.getElementById('type').value = record.type || '';
  document.getElementById('content').value = record.content || '';
  document.getElementById('ttl').value = record.ttl || 3600;
  document.getElementById('priority').value = record.priority || 0;
}

// Save record (create or update)
async function saveRecord() {
  const form = document.getElementById('recordForm');
  const formData = new FormData(form);

  // Convert FormData to object
  const data = {};
  for (const [key, value] of formData.entries()) {
    data[key] = value;
  }

  // Determine URL and method
  let url, method;
  if (recordId === 'new') {
    url = `<%== url_for('zone_index') %>/${zoneId}/records`;
    method = 'POST';
  } else {
    url = `<%== url_for('zone_index') %>/${zoneId}/records/${recordId}`;
    method = 'PATCH';
  }

  const result = await window.authenticatedFetch(url, {
    method: method,
    body: JSON.stringify(data),
    headers: { 'Content-Type': 'application/json' }
  });

  if (result && result.success) {
    window.showToast(result.toast || '<%== __("Record saved successfully") %>');
    const modal = bootstrap.Modal.getInstance(document.querySelector('#universalmodal'));
    if (modal) modal.hide();
    // Refresh the records list
    setTimeout(() => location.reload(), 500);
  } else {
    window.showToast(result?.toast || '<%== __("Failed to save record") %>');
  }
}
