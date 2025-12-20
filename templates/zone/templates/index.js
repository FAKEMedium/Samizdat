(function() {
  const baseUrl = '<%== url_for("Zone.templates.index") %>';
  let currentTemplateId = null;

  const templateList = document.getElementById('templateList');
  const templateEditor = document.getElementById('templateEditor');
  const noSelection = document.getElementById('noSelection');
  const recordsBody = document.querySelector('#recordsTable tbody');
  const recordModal = new bootstrap.Modal('#recordModal');

  // Generate date-based SOA serial (YYYYMMDD01)
  function generateSerial() {
    const now = new Date();
    const y = now.getFullYear();
    const m = String(now.getMonth() + 1).padStart(2, '0');
    const d = String(now.getDate()).padStart(2, '0');
    return `${y}${m}${d}01`;
  }

  // Record type configurations
  const typeConfig = {
    A: { template: 'simple', label: '<%== __("IPv4 Address") %>', placeholder: '192.0.2.1' },
    AAAA: { template: 'simple', label: '<%== __("IPv6 Address") %>', placeholder: '2001:db8::1' },
    CNAME: { template: 'simple', label: '<%== __("Target") %>', placeholder: '@', hint: '<%== __("Use @ for zone apex") %>' },
    NS: { template: 'simple', label: '<%== __("Nameserver") %>', placeholder: 'ns1.example.com. or @', hint: '<%== __("Use @ for zone apex") %>' },
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
        // MX: priority mailserver
        return { mxPriority: parts[0] || '10', recordContent: parts.slice(1).join(' ') || '' };
      case 'SRV':
        // SRV: priority weight port target
        return {
          srvPriority: parts[0] || '0',
          srvWeight: parts[1] || '0',
          srvPort: parts[2] || '0',
          recordContent: parts.slice(3).join(' ') || ''
        };
      case 'CAA':
        // CAA: flags tag "value"
        const caaMatch = content.match(/^(\d+)\s+(\w+)\s+"?([^"]*)"?$/);
        if (caaMatch) {
          return { caaFlags: caaMatch[1], caaTag: caaMatch[2], caaValue: caaMatch[3] };
        }
        return { caaFlags: '0', caaTag: 'issue', caaValue: content };
      case 'SOA':
        // SOA: primary admin serial refresh retry expire minimum
        return {
          soaPrimary: parts[0] || '',
          soaAdmin: parts[1] || '',
          soaSerial: parts[2] || generateSerial(),
          soaRefresh: parts[3] || '10800',
          soaRetry: parts[4] || '3600',
          soaExpire: parts[5] || '604800',
          soaMinimum: parts[6] || '3600'
        };
      default:
        return { recordContent: content };
    }
  }

  // Combine type-specific fields into content
  function combineContent(type) {
    switch (type) {
      case 'MX':
        const priority = document.getElementById('mxPriority')?.value || '10';
        const mailserver = document.getElementById('recordContent')?.value || '';
        return `${priority} ${mailserver}`;
      case 'SRV':
        const srvPri = document.getElementById('srvPriority')?.value || '0';
        const weight = document.getElementById('srvWeight')?.value || '0';
        const port = document.getElementById('srvPort')?.value || '0';
        const target = document.getElementById('recordContent')?.value || '';
        return `${srvPri} ${weight} ${port} ${target}`;
      case 'CAA':
        const flags = document.getElementById('caaFlags')?.value || '0';
        const tag = document.getElementById('caaTag')?.value || 'issue';
        const value = document.getElementById('caaValue')?.value || '';
        return `${flags} ${tag} "${value}"`;
      case 'SOA':
        const primary = document.getElementById('soaPrimary')?.value || '';
        const admin = document.getElementById('soaAdmin')?.value || '';
        const serial = document.getElementById('soaSerial')?.value || generateSerial();
        const refresh = document.getElementById('soaRefresh')?.value || '10800';
        const retry = document.getElementById('soaRetry')?.value || '3600';
        const expire = document.getElementById('soaExpire')?.value || '604800';
        const minimum = document.getElementById('soaMinimum')?.value || '3600';
        return `${primary} ${admin} ${serial} ${refresh} ${retry} ${expire} ${minimum}`;
      default:
        return document.getElementById('recordContent')?.value || '';
    }
  }

  // Update content preview
  function updatePreview() {
    const type = document.getElementById('recordType').value;
    const preview = document.getElementById('contentPreview');
    const previewValue = document.getElementById('previewValue');

    if (['MX', 'SRV', 'CAA', 'SOA'].includes(type)) {
      preview.style.display = 'block';
      previewValue.textContent = combineContent(type);
    } else {
      preview.style.display = 'none';
    }
  }

  // Switch content fields based on type
  function switchTemplate(type, existingContent = null) {
    const contentFields = document.getElementById('contentFields');
    const config = typeConfig[type] || typeConfig['A'];

    // Get template
    const templateId = `tpl-${config.template || 'simple'}`;
    const template = document.getElementById(templateId);

    if (template) {
      contentFields.innerHTML = '';
      contentFields.appendChild(template.content.cloneNode(true));

      // For simple types, update label, placeholder, and hint
      if (config.template === 'simple' || !config.template) {
        const label = contentFields.querySelector('.content-label');
        const input = contentFields.querySelector('#recordContent');
        const hint = contentFields.querySelector('.content-hint');
        if (label && config.label) label.textContent = config.label;
        if (input && config.placeholder) input.placeholder = config.placeholder;
        if (hint && config.hint) hint.textContent = config.hint;
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
  document.getElementById('recordType').addEventListener('change', (e) => {
    switchTemplate(e.target.value);
  });

  // Load all templates
  async function loadTemplates() {
    const data = await window.authenticatedFetch(baseUrl);
    if (data && data.templates) {
      templateList.innerHTML = data.templates.map(t => `
        <a href="#" class="list-group-item list-group-item-action d-flex justify-content-between align-items-center"
           data-id="${t.templateid}">
          <div>
            <strong>${t.name}</strong>
            ${t.description ? `<br><small class="text-muted">${t.description}</small>` : ''}
          </div>
          <span class="badge bg-secondary">${t.record_count}</span>
        </a>
      `).join('') || `<div class="list-group-item text-muted"><%== __('No templates yet') %></div>`;
    }
  }

  // Load single template
  async function loadTemplate(templateid) {
    const data = await window.authenticatedFetch(`${baseUrl}/${templateid}`);
    if (data && data.template) {
      currentTemplateId = templateid;
      document.getElementById('templateName').value = data.template.name;
      document.getElementById('templateDescription').value = data.template.description || '';
      document.getElementById('templateTitle').textContent = data.template.name;

      // Load records
      recordsBody.innerHTML = (data.template.records || []).map(r => `
        <tr data-id="${r.recordid}">
          <td>${r.name}</td>
          <td><span class="badge bg-info">${r.type}</span></td>
          <td class="text-break" style="max-width: 300px;">${r.content}</td>
          <td>${r.ttl}</td>
          <td class="text-end">
            <button class="btn btn-sm btn-outline-secondary btn-edit"><%== icon 'pencil-fill' %></button>
            <button class="btn btn-sm btn-outline-danger btn-delete"><%== icon 'trash-fill' %></button>
          </td>
        </tr>
      `).join('') || `<tr><td colspan="5" class="text-muted text-center"><%== __('No records') %></td></tr>`;

      templateEditor.style.display = 'block';
      noSelection.style.display = 'none';

      // Highlight selected
      templateList.querySelectorAll('.list-group-item').forEach(el => {
        el.classList.toggle('active', el.dataset.id == templateid);
      });
    }
  }

  // Create new template
  async function createTemplate() {
    const result = await window.authenticatedFetch(baseUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: '<%== __("New Template") %>', description: '' })
    });

    if (result && result.success) {
      window.showToast(result.toast);
      await loadTemplates();
      await loadTemplate(result.templateid);
    }
  }

  // Save template
  async function saveTemplate() {
    if (!currentTemplateId) return;

    const result = await window.authenticatedFetch(`${baseUrl}/${currentTemplateId}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: document.getElementById('templateName').value,
        description: document.getElementById('templateDescription').value
      })
    });

    if (result && result.success) {
      window.showToast(result.toast);
      document.getElementById('templateTitle').textContent = document.getElementById('templateName').value;
      await loadTemplates();
    }
  }

  // Delete template
  async function deleteTemplate() {
    if (!currentTemplateId) return;
    if (!confirm('<%== __("Delete this template and all its records?") %>')) return;

    const result = await window.authenticatedFetch(`${baseUrl}/${currentTemplateId}`, {
      method: 'DELETE'
    });

    if (result && result.success) {
      window.showToast(result.toast);
      currentTemplateId = null;
      templateEditor.style.display = 'none';
      noSelection.style.display = 'block';
      await loadTemplates();
    }
  }

  // Duplicate template
  async function duplicateTemplate() {
    if (!currentTemplateId) return;

    const result = await window.authenticatedFetch(`${baseUrl}/${currentTemplateId}/duplicate`, {
      method: 'POST'
    });

    if (result && result.success) {
      window.showToast(result.toast);
      await loadTemplates();
      await loadTemplate(result.templateid);
    }
  }

  // Open record modal
  function openRecordModal(record = null) {
    document.getElementById('recordId').value = record?.recordid || '';
    document.getElementById('recordName').value = record?.name || '@';
    document.getElementById('recordTTL').value = record?.ttl || 3600;
    document.getElementById('recordModalTitle').textContent = record
      ? '<%== __("Edit Record") %>'
      : '<%== __("New Record") %>';

    // Set type and switch template with existing content
    const type = record?.type || 'A';
    document.getElementById('recordType').value = type;
    switchTemplate(type, record?.content || '');

    recordModal.show();
  }

  // Save record
  async function saveRecord() {
    const recordId = document.getElementById('recordId').value;
    const type = document.getElementById('recordType').value;
    const data = {
      name: document.getElementById('recordName').value,
      type: type,
      content: combineContent(type),
      ttl: parseInt(document.getElementById('recordTTL').value) || 3600
    };

    let url, method;
    if (recordId) {
      url = `${baseUrl}/${currentTemplateId}/records/${recordId}`;
      method = 'PATCH';
    } else {
      url = `${baseUrl}/${currentTemplateId}/records`;
      method = 'POST';
    }

    const result = await window.authenticatedFetch(url, {
      method: method,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });

    if (result && result.success) {
      window.showToast(result.toast);
      recordModal.hide();
      await loadTemplate(currentTemplateId);
      await loadTemplates();
    }
  }

  // Delete record
  async function deleteRecord(recordId) {
    if (!confirm('<%== __("Delete this record?") %>')) return;

    const result = await window.authenticatedFetch(`${baseUrl}/${currentTemplateId}/records/${recordId}`, {
      method: 'DELETE'
    });

    if (result && result.success) {
      window.showToast(result.toast);
      await loadTemplate(currentTemplateId);
      await loadTemplates();
    }
  }

  // Event handlers
  document.getElementById('newTemplate').addEventListener('click', createTemplate);
  document.getElementById('duplicateTemplate').addEventListener('click', duplicateTemplate);
  document.getElementById('deleteTemplate').addEventListener('click', deleteTemplate);
  document.getElementById('addRecord').addEventListener('click', () => openRecordModal());

  document.getElementById('templateForm').addEventListener('submit', (e) => {
    e.preventDefault();
    saveTemplate();
  });

  document.getElementById('recordForm').addEventListener('submit', (e) => {
    e.preventDefault();
    saveRecord();
  });

  templateList.addEventListener('click', (e) => {
    const item = e.target.closest('[data-id]');
    if (item) {
      e.preventDefault();
      loadTemplate(item.dataset.id);
    }
  });

  recordsBody.addEventListener('click', async (e) => {
    const btn = e.target.closest('button');
    if (!btn) return;

    const tr = btn.closest('tr');
    const recordId = tr.dataset.id;

    if (btn.classList.contains('btn-edit')) {
      // Fetch record data and open modal
      const data = await window.authenticatedFetch(`${baseUrl}/${currentTemplateId}/records/${recordId}`);
      if (data && data.record) {
        openRecordModal(data.record);
      }
    } else if (btn.classList.contains('btn-delete')) {
      await deleteRecord(recordId);
    }
  });

  // Initial load
  loadTemplates();
})();
