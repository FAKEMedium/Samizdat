(async function () {
  const form = document.querySelector('#checkForm');
  const zoneInput = document.querySelector('#zoneName');
  const asyncCheckbox = document.querySelector('#asyncMode');
  const resultsDiv = document.querySelector('#results');
  const loadingDiv = document.querySelector('#loading');
  const jobStatusDiv = document.querySelector('#jobStatus');
  const errorsDiv = document.querySelector('#errors');
  const errorList = document.querySelector('#errorList');

  let currentJobId = null;
  let pollInterval = null;

  form?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const zone = zoneInput.value.trim();
    if (!zone) return;

    // Reset UI
    resultsDiv.classList.add('d-none');
    errorsDiv.classList.add('d-none');
    jobStatusDiv.classList.add('d-none');
    loadingDiv.classList.remove('d-none');

    const isAsync = asyncCheckbox.checked;

    try {
      const result = await window.authenticatedFetch('<%== url_for('Zone.check.run') %>', {
        method: 'POST',
        body: JSON.stringify({ zone, async: isAsync })
      });

      loadingDiv.classList.add('d-none');

      if (result.async && result.job_id) {
        // Async mode - show job status and start polling
        currentJobId = result.job_id;
        document.querySelector('#jobId').textContent = `#${result.job_id}`;
        jobStatusDiv.classList.remove('d-none');
        startPolling();
      } else {
        // Sync mode - show results immediately
        displayResults(result);
      }
    } catch (err) {
      loadingDiv.classList.add('d-none');
      window.showToast('<%== __('Check failed') %>: ' + err.message, 'danger');
    }
  });

  document.querySelector('#refreshJob')?.addEventListener('click', () => {
    if (currentJobId) checkJobStatus();
  });

  function startPolling() {
    if (pollInterval) clearInterval(pollInterval);
    pollInterval = setInterval(checkJobStatus, 2000);
  }

  async function checkJobStatus() {
    if (!currentJobId) return;

    try {
      const result = await window.authenticatedFetch(
        '<%== url_for('Zone.check.status', job_id => '_JID_') %>'.replace('_JID_', currentJobId)
      );

      if (result.status === 'finished' && result.result) {
        clearInterval(pollInterval);
        jobStatusDiv.classList.add('d-none');
        displayResults(result.result);
      } else if (result.status === 'failed') {
        clearInterval(pollInterval);
        jobStatusDiv.classList.add('d-none');
        window.showToast('<%== __('Job failed') %>: ' + (result.error || '<%== __('Unknown error') %>'), 'danger');
      }
    } catch (err) {
      console.error('Polling error:', err);
    }
  }

  function displayResults(data) {
    resultsDiv.classList.remove('d-none');

    // Whois information
    const whois = data.whois || {};
    document.querySelector('#registrar').textContent = whois.registrar || '-';

    const whoisNS = document.querySelector('#whoisNS');
    whoisNS.innerHTML = (whois.nameservers || []).map(ns => `<li>${ns}</li>`).join('') || '<li>-</li>';

    const statusList = document.querySelector('#whoisStatus');
    if (statusList.tagName === 'UL') {
      statusList.innerHTML = (whois.status || []).map(s => `<li class="small">${s}</li>`).join('') || '<li>-</li>';
    }

    // Nameserver checks
    const checksBody = document.querySelector('#checksBody');
    checksBody.innerHTML = '';

    (data.checks || []).forEach(check => {
      const statusBadge = check.reachable
        ? '<span class="badge bg-success"><%== __('OK') %></span>'
        : '<span class="badge bg-danger"><%== __('Failed') %></span>';

      const soaInfo = check.soa
        ? `${check.soa.serial}`
        : '-';

      const nsRecords = check.ns_records?.length
        ? check.ns_records.join(', ')
        : '-';

      const nsMatchBadge = check.ns_match
        ? '<span class="badge bg-success ms-1"><%== icon 'check', {} %></span>'
        : (check.ns_records?.length ? '<span class="badge bg-warning ms-1"><%== icon 'exclamation-triangle', {} %></span>' : '');

      const responseTime = check.response_time_ms
        ? `${check.response_time_ms} ms`
        : '-';

      const errorInfo = check.error
        ? `<small class="text-danger d-block">${check.error}</small>`
        : '';

      checksBody.innerHTML += `
        <tr>
          <td>${check.nameserver}${errorInfo}</td>
          <td><code>${check.ip || '-'}</code></td>
          <td>${soaInfo}</td>
          <td>${nsRecords}${nsMatchBadge}</td>
          <td class="text-end">${responseTime}</td>
          <td>${statusBadge}</td>
        </tr>
      `;
    });

    // Errors
    const errors = data.errors || [];
    if (errors.length > 0) {
      errorsDiv.classList.remove('d-none');
      errorList.innerHTML = errors.map(e => `<li>${e}</li>`).join('');
    } else {
      errorsDiv.classList.add('d-none');
    }
  }
})();
