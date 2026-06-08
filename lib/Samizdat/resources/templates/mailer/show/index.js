(async function () {
  const mailid = window.location.pathname.split('/').pop();
  let currentBounces = [];

  async function fetchMail() {
    const data = await window.authenticatedFetch(
      `<%== url_for('Mailer.show', mailid => '_ID_') %>`.replace('_ID_', mailid)
    );
    if (data) {
      populate(data);
    }
  }

  async function fetchBounces() {
    const data = await window.authenticatedFetch(
      `<%== url_for('Mailer.mail.bounces', mailid => '_ID_') %>`.replace('_ID_', mailid)
    );
    if (data) {
      currentBounces = data.bounces || [];
      populateBounces(currentBounces);
    }
  }

  function populate(data) {
    const m = data.mail || {};
    const contents = data.contents || [];
    const stats = data.stats || {};

    const statusBadge = {
      draft: 'bg-secondary',
      scheduled: 'bg-info',
      sending: 'bg-warning',
      completed: 'bg-success',
      cancelled: 'bg-danger'
    };
    document.querySelector('#mailInfo').innerHTML = '<p><strong><%== __("Name") %>:</strong> ' + (m.name || '') + '</p>'
      + '<p><strong><%== __("Status") %>:</strong> <span class="badge ' + (statusBadge[m.status] || 'bg-secondary') + '">' + (m.status || '') + '</span></p>'
      + '<p><strong><%== __("Created") %>:</strong> ' + (m.created ? new Date(m.created).toLocaleString() : '') + '</p>';

    // Progress bar
    const total = stats.total || 0;
    const sent = stats.sent || 0;
    const failed = stats.failed || 0;
    const bounced = stats.bounced || 0;
    const pending = stats.pending || 0;
    const progress = total > 0 ? Math.round((sent / total) * 100) : 0;

    let statsHtml = '';
    if (total > 0 && m.status !== 'draft') {
      statsHtml += '<div class="mb-3">'
        + '<div class="d-flex justify-content-between small mb-1">'
        + '<span>' + sent + ' / ' + total + ' <%== __("sent") %></span>'
        + '<span>' + progress + '%</span>'
        + '</div>'
        + '<div class="progress" style="height: 20px;">'
        + '<div class="progress-bar bg-success" style="width: ' + progress + '%">' + sent + '</div>';
      if (failed > 0) {
        const failedPct = Math.round((failed / total) * 100);
        statsHtml += '<div class="progress-bar bg-danger" style="width: ' + failedPct + '%">' + failed + '</div>';
      }
      if (pending > 0) {
        const pendingPct = Math.round((pending / total) * 100);
        statsHtml += '<div class="progress-bar bg-secondary" style="width: ' + pendingPct + '%"></div>';
      }
      statsHtml += '</div></div>';
    }

    statsHtml += '<ul class="list-unstyled mb-0">'
      + '<li><%== __("Total") %>: <strong>' + total + '</strong></li>'
      + '<li><%== __("Pending") %>: ' + pending + '</li>'
      + '<li class="text-success"><%== __("Sent") %>: ' + sent + '</li>'
      + '<li class="text-danger"><%== __("Failed") %>: ' + failed + '</li>'
      + '<li class="text-warning"><%== __("Bounced") %>: ' + bounced + '</li>'
      + '</ul>';
    document.querySelector('#statsContent').innerHTML = statsHtml;

    // Show bounces section if there are any
    const bouncesSection = document.querySelector('#bouncesSection');
    if (bouncesSection && bounced > 0) {
      bouncesSection.style.display = 'block';
      fetchBounces();
    }

    if (contents.length > 0) {
      let tabsHtml = '';
      let contentHtml = '';

      contents.forEach((c, i) => {
        const active = i === 0 ? 'active' : '';
        const show = i === 0 ? 'show active' : '';
        tabsHtml += `
          <li class="nav-item" role="presentation">
            <button class="nav-link ${active}" id="tab-${c.languageid}" data-bs-toggle="tab"
              data-bs-target="#content-${c.languageid}" type="button" role="tab">
              ${c.languageid === 1 ? 'EN' : c.languageid === 2 ? 'SV' : 'Lang ' + c.languageid}
            </button>
          </li>`;
        contentHtml += `
          <div class="tab-pane fade ${show}" id="content-${c.languageid}" role="tabpanel">
            <p><strong><%== __('Subject') %>:</strong> ${c.subject}</p>
            <pre class="bg-light p-2 rounded">${c.body_md}</pre>
          </div>`;
      });

      document.querySelector('#contentTabs').innerHTML = tabsHtml;
      document.querySelector('#contentTabContent').innerHTML = contentHtml;
    } else {
      document.querySelector('#contentTabs').innerHTML = '';
      document.querySelector('#contentTabContent').innerHTML = '<p class="text-muted"><%== __("No content defined yet") %></p>';
    }

    const queueBtn = document.querySelector('#queueBtn');
    if (m.status === 'draft' && contents.length > 0) {
      queueBtn.disabled = false;
    }
  }

  function populateBounces(bounces) {
    const tbody = document.querySelector('#bouncesTable tbody');
    if (!tbody) return;

    if (bounces.length === 0) {
      tbody.innerHTML = '<tr><td colspan="5" class="text-muted"><%== __("No bounces") %></td></tr>';
      return;
    }

    const typeClass = { hard: 'text-danger', soft: 'text-warning', complaint: 'text-danger', delayed: 'text-info' };

    let html = '';
    for (const b of bounces) {
      html += '<tr>'
        + '<td><input type="checkbox" class="bounce-check" data-addressid="' + b.addressid + '"' + (b.suggest_remove ? ' checked' : '') + '></td>'
        + '<td>' + b.email + '</td>'
        + '<td><span class="' + (typeClass[b.bounce_type] || '') + '">' + b.bounce_type + '</span></td>'
        + '<td><small>' + (b.bounce_code || '') + '</small></td>'
        + '<td><small class="text-muted">' + (b.diagnostic || '').substring(0, 50) + '</small></td>'
        + '</tr>';
    }
    tbody.innerHTML = html;

    // Update remove button count
    updateRemoveCount();
  }

  function updateRemoveCount() {
    const checked = document.querySelectorAll('.bounce-check:checked').length;
    const btn = document.querySelector('#removeMarkedBtn');
    if (btn) {
      btn.textContent = '<%== __("Remove marked") %> (' + checked + ')';
      btn.disabled = checked === 0;
    }
  }

  document.querySelector('#bouncesTable')?.addEventListener('change', (e) => {
    if (e.target.classList.contains('bounce-check')) {
      updateRemoveCount();
    }
  });

  document.querySelector('#removeMarkedBtn')?.addEventListener('click', async () => {
    const checked = document.querySelectorAll('.bounce-check:checked');
    const addressids = [...checked].map(cb => parseInt(cb.dataset.addressid)).filter(id => id);

    if (addressids.length === 0) return;
    if (!confirm('<%== __("Remove") %> ' + addressids.length + ' <%== __("addresses") %>?')) return;

    const result = await window.authenticatedFetch('<%== url_for("Mailer.addresses.bulk_delete") %>', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ addressids })
    });

    if (result?.success) {
      window.showToast(result.toast, 'success');
      fetchBounces();
      fetchMail();
    }
  });

  document.querySelector('#editBtn')?.addEventListener('click', () => {
    window.openModalFromUrl(
      `<%== url_for('Mailer.edit', mailid => '_ID_') %>`.replace('_ID_', mailid)
    );
  });

  document.querySelector('#copyBtn')?.addEventListener('click', async () => {
    const result = await window.authenticatedFetch(
      `<%== url_for('Mailer.copy', mailid => '_ID_') %>`.replace('_ID_', mailid),
      { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' }
    );
    if (result?.success) {
      window.showToast(result.toast, 'success');
      if (result.mail?.mailid) {
        window.location.href = `<%== url_for('mailer_show', mailid => '_ID_') %>`.replace('_ID_', result.mail.mailid);
      }
    }
  });

  document.querySelector('#queueBtn')?.addEventListener('click', async () => {
    if (!confirm('<%== __("Queue this mail for sending?") %>')) return;

    const result = await window.authenticatedFetch(
      `<%== url_for('Mailer.queue', mailid => '_ID_') %>`.replace('_ID_', mailid),
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ include_recipients: true })
      }
    );

    if (result?.success) {
      window.showToast(result.toast, 'success');
      fetchMail();
    }
  });

  document.querySelector('#deleteBtn')?.addEventListener('click', async () => {
    if (!confirm('<%== __("Delete this mail?") %>')) return;

    const result = await window.authenticatedFetch(
      `<%== url_for('Mailer.delete', mailid => '_ID_') %>`.replace('_ID_', mailid),
      { method: 'DELETE' }
    );

    if (result?.success) {
      window.showToast(result.toast, 'success');
      window.location.href = '<%== url_for("mailer_index") %>';
    }
  });

  fetchMail();
})();
