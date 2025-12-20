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

// Detect reverse zone
const zoneNorm = (zoneId || '').replace(/\.$/, '');
const isReverseZone = zoneNorm.endsWith('.in-addr.arpa') || zoneNorm.endsWith('.ip6.arpa');

// Filter record type options based on zone type
const typeSelect = document.getElementById('type');
typeSelect.querySelectorAll('option[data-zone]').forEach(opt => {
  const zoneType = opt.dataset.zone;
  if (zoneType === 'both') return;
  if (isReverseZone && zoneType === 'forward') {
    opt.style.display = 'none';
  } else if (!isReverseZone && zoneType === 'reverse') {
    opt.style.display = 'none';
  }
});

// Record type configurations
const typeConfig = {
  A: { template: 'simple', label: '<%== __("IPv4 Address") %>', placeholder: '192.0.2.1' },
  AAAA: { template: 'simple', label: '<%== __("IPv6 Address") %>', placeholder: '2001:db8::1' },
  CNAME: { template: 'simple', label: '<%== __("Target") %>', placeholder: 'www.example.com.' },
  NS: { template: 'simple', label: '<%== __("Nameserver") %>', placeholder: 'ns1.example.com.' },
  PTR: { template: 'simple', label: '<%== __("Hostname") %>', placeholder: 'server.example.com.' },
  TXT: { template: 'simple', label: '<%== __("Text") %>', placeholder: '"v=spf1 include:_spf.example.com ~all"' },
  MX: { template: 'mx' },
  NAPTR: { template: 'naptr' },
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
      // MX content is "priority mailserver" (zone-file style, PowerDNS 4.9+)
      return {
        mx_priority: parts[0] || '10',
        content: parts.slice(1).join(' ') || ''
      };
    case 'NAPTR':
      // NAPTR content: order preference "flags" "service" "regexp" replacement (zone-file style)
      const naptrMatch = content.match(/^(\d+)\s+(\d+)\s+"([^"]*)"\s+"([^"]*)"\s+"([^"]*)"\s+(\S+)$/);
      if (naptrMatch) {
        return {
          naptr_order: naptrMatch[1],
          naptr_preference: naptrMatch[2],
          naptr_flags: naptrMatch[3],
          naptr_service: naptrMatch[4],
          naptr_regexp: naptrMatch[5],
          content: naptrMatch[6]
        };
      }
      return { content: content };
    case 'SRV':
      // SRV content: priority weight port target (zone-file style)
      return {
        srv_priority: parts[0] || '0',
        srv_weight: parts[1] || '0',
        srv_port: parts[2] || '0',
        content: parts.slice(3).join(' ') || ''
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

// Ensure hostname has trailing dot (required by PowerDNS)
function ensureTrailingDot(hostname) {
  if (!hostname) return hostname;
  hostname = hostname.trim();
  return hostname.endsWith('.') ? hostname : hostname + '.';
}

// Combine type-specific fields into content
function combineContent(type) {
  switch (type) {
    case 'MX':
      // MX: server prepends priority to get "priority mailserver"
      return ensureTrailingDot(document.getElementById('content')?.value || '');
    case 'NAPTR':
      // NAPTR: server prepends order to get "order preference flags service regexp replacement"
      const naptrPref = document.getElementById('naptr_preference')?.value || '10';
      const naptrFlags = document.getElementById('naptr_flags')?.value || '';
      const naptrService = document.getElementById('naptr_service')?.value || '';
      const naptrRegexp = document.getElementById('naptr_regexp')?.value || '';
      const naptrReplacement = document.getElementById('content')?.value || '.';
      return `${naptrPref} "${naptrFlags}" "${naptrService}" "${naptrRegexp}" ${naptrReplacement}`;
    case 'SRV':
      // SRV: server prepends priority to get "priority weight port target"
      const weight = document.getElementById('srv_weight')?.value || '0';
      const port = document.getElementById('srv_port')?.value || '0';
      const target = ensureTrailingDot(document.getElementById('content')?.value || '');
      return `${weight} ${port} ${target}`;
    case 'CAA':
      const flags = document.getElementById('caa_flags')?.value || '0';
      const tag = document.getElementById('caa_tag')?.value || 'issue';
      const value = document.getElementById('caa_value')?.value || '';
      return `${flags} ${tag} "${value}"`;
    case 'SOA':
      const primary = ensureTrailingDot(document.getElementById('soa_primary')?.value || '');
      const admin = ensureTrailingDot(document.getElementById('soa_admin')?.value || '');
      const serial = document.getElementById('soa_serial')?.value || '1';
      const refresh = document.getElementById('soa_refresh')?.value || '10800';
      const retry = document.getElementById('soa_retry')?.value || '3600';
      const expire = document.getElementById('soa_expire')?.value || '604800';
      const minimum = document.getElementById('soa_minimum')?.value || '3600';
      return `${primary} ${admin} ${serial} ${refresh} ${retry} ${expire} ${minimum}`;
    case 'CNAME':
    case 'NS':
    case 'PTR':
      return ensureTrailingDot(document.getElementById('content')?.value || '');
    default:
      return document.getElementById('content')?.value || '';
  }
}

// Update content preview (shows full zone-file format)
function updatePreview() {
  const type = document.getElementById('type').value;
  const preview = document.getElementById('content-preview');
  const previewValue = document.getElementById('preview-value');

  if (['MX', 'NAPTR', 'SRV', 'CAA', 'SOA'].includes(type)) {
    preview.style.display = 'block';
    let content = combineContent(type);
    // Add priority prefix for preview (server will do this too)
    if (type === 'MX') {
      const prio = document.getElementById('mx_priority')?.value || '10';
      content = `${prio} ${content}`;
    } else if (type === 'SRV') {
      const prio = document.getElementById('srv_priority')?.value || '0';
      content = `${prio} ${content}`;
    } else if (type === 'NAPTR') {
      const order = document.getElementById('naptr_order')?.value || '100';
      content = `${order} ${content}`;
    }
    previewValue.textContent = content;
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
// Track original content for multi-record type updates
let originalContent = null;

async function loadRecord() {
  const data = await window.authenticatedFetch(sourceUrl, {
    method: 'GET'
  });

  if (data && data.success && data.record) {
    originalContent = data.record.content;  // Store for update
    populateForm(data.record);
  }
}

// Populate form with record data
function populateForm(record) {
  document.getElementById('name').value = stripZoneName(record.name) || '';
  document.getElementById('type').value = record.type || '';
  document.getElementById('ttl').value = record.ttl || 3600;

  // Switch template and populate content fields
  // For MX/SRV/NAPTR, parseContent extracts priority from content (zone-file style)
  switchTemplate(record.type, record.content);
}

// Save record (create or update)
let saving = false;
async function saveRecord() {
  if (saving) return;  // Prevent double submission
  saving = true;

  const submitBtn = document.querySelector('#recordForm button[type="submit"]');
  if (submitBtn) submitBtn.disabled = true;

  const form = document.getElementById('recordForm');
  const type = document.getElementById('type').value;

  // Build data object
  const data = {
    name: addZoneName(document.getElementById('name').value),
    type: type,
    content: combineContent(type),
    ttl: document.getElementById('ttl').value || 3600
  };

  // For updates, include original content so server can remove old record
  if (originalContent && recordName !== 'new') {
    data.original_content = originalContent;
  }

  // Add priority for MX/SRV/NAPTR
  if (type === 'MX') {
    data.priority = document.getElementById('mx_priority')?.value || 10;
  } else if (type === 'SRV') {
    data.priority = document.getElementById('srv_priority')?.value || 0;
  } else if (type === 'NAPTR') {
    data.priority = document.getElementById('naptr_order')?.value || 100;
  }

  // Determine URL and method
  let url, method;
  if (recordName === 'new') {
    url = `<%== url_for('Zone.records.create', zone_id => '_ZID_') %>`.replace('_ZID_', zoneId);
    method = 'POST';
  } else {
    url = `<%== url_for('Zone.records.update', zone_id => '_ZID_', record_id => '_RID_') %>`.replace('_ZID_', zoneId).replace('_RID_', `${recordType}_${recordName}`);
    method = 'PATCH';
  }

  try {
    const result = await window.authenticatedFetch(url, {
      method: method,
      body: JSON.stringify(data),
      headers: { 'Content-Type': 'application/json' }
    });

    if (result && result.success) {
      window.showToast(result.toast || '<%== __("Record saved successfully") %>', 'success');
      const modal = bootstrap.Modal.getInstance(document.querySelector('#universalmodal'));
      if (modal) modal.hide();
      // Update the row in the list instead of reloading
      if (window.updateRecordRow) {
        window.updateRecordRow(data);
      }
    } else {
      window.showToast(result?.error || result?.toast || '<%== __("Failed to save record") %>', 'danger');
    }
  } finally {
    saving = false;
    if (submitBtn) submitBtn.disabled = false;
  }
}

// Initialize with default template if new record
if (recordName === 'new') {
  const defaultType = isReverseZone ? 'PTR' : 'A';
  typeSelect.value = defaultType;
  switchTemplate(defaultType);
}
})();
