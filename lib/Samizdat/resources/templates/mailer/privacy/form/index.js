(function () {
  const customerid = <%= $customerid || 0 %>;

  document.querySelector('#privacyForm').addEventListener('submit', async (e) => {
    e.preventDefault();

    const email = document.querySelector('#email').value.trim();
    if (!email) return;

    const btn = e.target.querySelector('button[type="submit"]');
    btn.disabled = true;
    btn.innerHTML = '<span class="spinner-border spinner-border-sm"></span>';

    const result = await fetch('<%== url_for("Mailer.privacy.request") %>', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
      body: JSON.stringify({ email, customerid })
    }).then(r => r.json());

    btn.disabled = false;
    btn.textContent = '<%== __("Send link") %>';

    if (result?.success) {
      document.querySelector('#privacyForm').classList.add('d-none');
      const msg = document.querySelector('#successMessage');
      msg.textContent = result.toast;
      msg.classList.remove('d-none');
    } else {
      alert(result?.error || '<%== __("An error occurred") %>');
    }
  });
})();
