async function sendData() {
  const request = {
    method: 'GET',
    headers: {Accept: 'application/json'}
  };
  try {
    const response = await fetch(window.location, request);
    if (!response.ok) {
      if (response.status === 401) {
        const data = await response.json();
        if (window.handle401Error) {
          window.handle401Error(data.error || '<%== __("Authentication required") %>');
        } else {
          window.location.href = '<%== url_for('account_login') %>';
        }
      } else {
        alert('Request failed: ' + response.statusText);
      }
    } else {
      populate(await response.json());
    }
  } catch (e) {
    console.error('Request error:', e);
    alert('Request failed');
  }
}

function getQuotas() {
  sendData();
}

function populate(formdata) {
  let quotas = formdata.data || [];
  let snippet = '';

  for (const quota of quotas) {
    const bytesInMB = quota.bytes ? (quota.bytes / (1024 * 1024)).toFixed(2) : 0;
    snippet += `
      <tr data-username="${quota.username}">
        <td>${quota.username}</td>
        <td>${bytesInMB} MB</td>
        <td>${quota.messages || 0}</td>
      </tr>`;
  }
  document.querySelector('#quotas tbody').innerHTML = snippet;
}

// Load data
getQuotas();
