(function() {
// Zone record edit form handler (runs in modal context)
const modalDialog = document.querySelector('#modalDialog');
const sourceUrl = modalDialog?.dataset.sourceUrl || '';
const [urlPath, urlQuery] = sourceUrl.split('?');
const match = urlPath.match(/\/zones\/([^/]+)\/records\/([^/]+)/);
const isNew = urlPath.endsWith('/new');
const zoneId = match ? decodeURIComponent(match[1]) : null;
const recordName = !isNew && match ? decodeURIComponent(match[2]) : 'new';
// Parse type from query string
const params = new URLSearchParams(urlQuery || '');
const recordType = params.get('type');

// Store zone name in hidden field and show as suffix
document.getElementById('zone_name').value = zoneId || '';
// zoneId may or may not have trailing dot - normalize for display
const zoneDisplay = zoneId ? (zoneId.endsWith('.') ? zoneId.slice(0, -1) : zoneId) : '';
document.getElementById('zone_suffix').textContent = zoneDisplay ? '.' + zoneDisplay : '';

// Strip zone name from record name for display
function stripZoneName(name) {
  if (!name || !zoneId) return name;
  const zoneWithDot = zoneId.endsWith('.') ? zoneId : zoneId + '.';
  if (name.endsWith(zoneWithDot)) {
    name = name.slice(0, -zoneWithDot.length);
  } else if (name.endsWith(zoneId)) {
    name = name.slice(0, -zoneId.length);
  }
  if (name.endsWith('.')) {
    name = name.slice(0, -1);
  }
  if (name === '') {
    name = '@';
  }
  return name;
}

// Add zone name back to record name for saving
function addZoneName(name) {
  if (!name || !zoneId) return name;
  const zoneWithDot = zoneId.endsWith('.') ? zoneId : zoneId + '.';
  if (name === '@') {
    return zoneWithDot;
  }
  if (name.endsWith(zoneWithDot) || name.endsWith(zoneId)) {
    return name.endsWith('.') ? name : name + '.';
  }
  if (!name.endsWith('.')) {
    name = name + '.';
  }
  return name + zoneWithDot;
}

// Record type configurations
const typeConfig = {
  A: { template: 'simple', label: '<%== __("IPv4 Address") %>', placeholder: '192.0.2.1' },
  AAAA: { template: 'simple', label: '<%== __("IPv6 Address") %>', placeholder: '2001:db8::1' },
  CNAME: { template: 'simple', label: '<%== __("Target") %>', placeholder: 'www.example.com.' },
  NS: { template: 'simple', label: '<%== __("Nameserver") %>', placeholder: 'ns1.example.com.' },
  TXT: { template: 'simple', label: '<%== __("Text") %>', placeholder: '"v=spf1 include:_spf.example.com ~all"' },
  MX: { template: 'mx' },
  SRV: { template: 'srv' },
  CAA: { template: 'caa' },
  SOA: { template: 'soa' }
};

// Parse content into type-specific fields
function parseContent(type, content) {
  if (!content) return {};
  const parts = content.split(/\s+/);

  switch (type) {
    case 'MX':
      // MX content in PowerDNS is just the mail server (priority is separate)
      return { content: content };
    case 'SRV':
      // SRV: priority weight port target (priority handled separately by PowerDNS)
      return {
        srv_weight: parts[0] || '0',
        srv_port: parts[1] || '0',
        content: parts.slice(2).join(' ') || ''
      };
    case 'CAA':
      // CAA: flags tag "value"
      const caaMatch = content.match(/^(\d+)\s+(\w+)\s+"?([^"]*)"?$/);
      if (caaMatch) {
        return {
          caa_flags: caaMatch[1],
          caa_tag: caaMatch[2],
          caa_value: caaMatch[3]
        };
      }
      return { caa_flags: '0', caa_tag: 'issue', caa_value: content };
    case 'SOA':
      // SOA: primary admin serial refresh retry expire minimum
      return {
        soa_primary: parts[0] || '',
        soa_admin: parts[1] || '',
        soa_serial: parts[2] || '1',
        soa_refresh: parts[3] || '10800',
        soa_retry: parts[4] || '3600',
        soa_expire: parts[5] || '604800',
        soa_minimum: parts[6] || '3600'
      };
    default:
      return { content: content };
  }
}

// Combine type-specific fields into content
function combineContent(type) {
  switch (type) {
    case 'MX':
      const priority = document.getElementById('mx_priority')?.value || '10';
      const mailserver = document.getElementById('content')?.value || '';
      return `${priority} ${mailserver}`;
    case 'SRV':
      const weight = document.getElementById('srv_weight')?.value || '0';
      const port = document.getElementById('srv_port')?.value || '0';
      const target = document.getElementById('content')?.value || '';
      return `${weight} ${port} ${target}`;
    case 'CAA':
      const flags = document.getElementById('caa_flags')?.value || '0';
      const tag = document.getElementById('caa_tag')?.value || 'issue';
      const value = document.getElementById('caa_value')?.value || '';
      return `${flags} ${tag} "${value}"`;
    case 'SOA':
      const primary = document.getElementById('soa_primary')?.value || '';
      const admin = document.getElementById('soa_admin')?.value || '';
      const serial = document.getElementById('soa_serial')?.value || '1';
      const refresh = document.getElementById('soa_refresh')?.value || '10800';
      const retry = document.getElementById('soa_retry')?.value || '3600';
      const expire = document.getElementById('soa_expire')?.value || '604800';
      const minimum = document.getElementById('soa_minimum')?.value || '3600';
      return `${primary} ${admin} ${serial} ${refresh} ${retry} ${expire} ${minimum}`;
    default:
      return document.getElementById('content')?.value || '';
  }
}

// Update content preview
function updatePreview() {
  const type = document.getElementById('type').value;
  const preview = document.getElementById('content-preview');
  const previewValue = document.getElementById('preview-value');

  if (['MX', 'SRV', 'CAA', 'SOA'].includes(type)) {
    preview.style.display = 'block';
    previewValue.textContent = combineContent(type);
  } else {
    preview.style.display = 'none';
  }
}

// Switch content fields based on type
function switchTemplate(type, existingContent = null) {
  const contentFields = document.getElementById('content-fields');
  const config = typeConfig[type] || typeConfig['A'];

  // Get template
  const templateId = `tpl-${config.template || 'simple'}`;
  const template = document.getElementById(templateId);

  if (template) {
    contentFields.innerHTML = '';
    contentFields.appendChild(template.content.cloneNode(true));

    // For simple types, update label and placeholder
    if (config.template === 'simple' || !config.template) {
      const label = contentFields.querySelector('.content-label');
      const input = contentFields.querySelector('#content');
      if (label && config.label) label.textContent = config.label;
      if (input && config.placeholder) input.placeholder = config.placeholder;
    }

    // Parse and populate existing content
    if (existingContent) {
      const parsed = parseContent(type, existingContent);
      for (const [key, value] of Object.entries(parsed)) {
        const el = document.getElementById(key);
        if (el) el.value = value;
      }
    }

    // Add input listeners for preview update
    contentFields.querySelectorAll('input, select').forEach(el => {
      el.addEventListener('input', updatePreview);
    });

    updatePreview();
  }
}

// Type change handler
document.getElementById('type').addEventListener('change', (e) => {
  const currentContent = document.getElementById('content')?.value;
  switchTemplate(e.target.value, currentContent);
});

// Load existing record if editing
if (recordName !== 'new') {
  loadRecord();
}

// Form submission handler
document.getElementById('recordForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  await saveRecord();
});

// Load record data for editing
async function loadRecord() {
  const data = await window.authenticatedFetch(sourceUrl, {
    method: 'GET'
  });

  if (data && data.success && data.record) {
    populateForm(data.record);
  }
}

// Populate form with record data
function populateForm(record) {
  document.getElementById('name').value = stripZoneName(record.name) || '';
  document.getElementById('type').value = record.type || '';
  document.getElementById('ttl').value = record.ttl || 3600;

  // Switch template and populate content fields
  switchTemplate(record.type, record.content);
}

// Save record (create or update)
async function saveRecord() {
  const form = document.getElementById('recordForm');
  const type = document.getElementById('type').value;

  // Build data object
  const data = {
    name: addZoneName(document.getElementById('name').value),
    type: type,
    content: combineContent(type),
    ttl: document.getElementById('ttl').value || 3600
  };

  // Add priority for MX/SRV
  if (type === 'MX') {
    data.priority = document.getElementById('mx_priority')?.value || 10;
  } else if (type === 'SRV') {
    data.priority = document.getElementById('srv_priority')?.value || 0;
  }

  // Determine URL and method
  let url, method;
  if (recordName === 'new') {
    url = `<%== url_for('zone_index') %>/${zoneId}/records`;
    method = 'POST';
  } else {
    url = `<%== url_for('zone_index') %>/${zoneId}/records/${recordType}_${recordName}`;
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
    // Update the row in the list instead of reloading
    if (window.updateRecordRow) {
      window.updateRecordRow(data);
    }
  } else {
    window.showToast(result?.toast || '<%== __("Failed to save record") %>');
  }
}

// Initialize with default template if new record
if (recordName === 'new') {
  switchTemplate('A');
}
})();
