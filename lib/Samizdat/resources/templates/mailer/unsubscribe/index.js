(async function () {
  const urlParams = new URLSearchParams(window.location.search);
  const token = urlParams.get('token');

  const loading = document.querySelector('#loading');
  const confirmSection = document.querySelector('#confirmSection');
  const successSection = document.querySelector('#successSection');
  const errorSection = document.querySelector('#errorSection');
  const errorMessage = document.querySelector('#errorMessage');

  function showError(msg) {
    loading.style.display = 'none';
    confirmSection.style.display = 'none';
    successSection.style.display = 'none';
    errorSection.style.display = 'block';
    errorMessage.textContent = msg;
  }

  function showSuccess() {
    loading.style.display = 'none';
    confirmSection.style.display = 'none';
    errorSection.style.display = 'none';
    successSection.style.display = 'block';
  }

  function showConfirm(email) {
    loading.style.display = 'none';
    errorSection.style.display = 'none';
    successSection.style.display = 'none';
    confirmSection.style.display = 'block';
    document.querySelector('#emailDisplay').textContent = email;
  }

  if (!token) {
    showError('<%== __("Invalid or missing unsubscribe token.") %>');
    return;
  }

  // Verify token and get email
  try {
    const response = await fetch(`<%== url_for('mailer_unsubscribe', token => '_TOKEN_') %>`.replace('_TOKEN_', encodeURIComponent(token)), {
      headers: { 'Accept': 'application/json' }
    });
    const data = await response.json();

    if (data.success && data.email) {
      showConfirm(data.email);
    } else {
      showError(data.error || '<%== __("Invalid or expired token.") %>');
    }
  } catch (e) {
    showError('<%== __("Failed to verify token.") %>');
    return;
  }

  document.querySelector('#unsubscribeBtn').onclick = async () => {
    const reason = document.querySelector('#reason').value;

    try {
      const response = await fetch('<%== url_for("Mailer.unsubscribe.confirm") %>', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ token, reason })
      });
      const data = await response.json();

      if (data.success) {
        showSuccess();
      } else {
        showError(data.error || '<%== __("Failed to unsubscribe.") %>');
      }
    } catch (e) {
      showError('<%== __("Failed to process unsubscription.") %>');
    }
  };
})();
