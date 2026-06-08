(async function () {
  const basePath = window.location.pathname.replace(/\/$/, '');
  const form = document.querySelector('#databaseForm');
  const isNew = basePath.endsWith('/new');

  // Form elements
  const databaseidInput = document.querySelector('#databaseid');
  const customeridInput = document.querySelector('#customerid');
  const databasenameInput = document.querySelector('#databasename');
  const databasetypeidSelect = document.querySelector('#databasetypeid');
  const usernameInput = document.querySelector('#username');
  const passwordInput = document.querySelector('#password');
  const deleteBtn = document.querySelector('#deleteBtn');
  const submitLabel = document.querySelector('#submitLabel');

  // Password toggle
  document.querySelector('#togglePassword')?.addEventListener('click', () => {
    const type = passwordInput.type === 'password' ? 'text' : 'password';
    passwordInput.type = type;
  });

  // Password generator
  document.querySelector('#generatePassword')?.addEventListener('click', () => {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*';
    let password = '';
    for (let i = 0; i < 16; i++) {
      password += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    passwordInput.value = password;
    passwordInput.type = 'text';
  });

  async function fetchFormData() {
    const data = await window.authenticatedFetch(basePath);
    if (data) {
      populate(data);
    }
  }

  function populate(formdata) {
    const db = formdata.database || {};
    const types = formdata.types || [];

    // Populate type dropdown
    databasetypeidSelect.innerHTML = '';
    for (const type of types) {
      const opt = document.createElement('option');
      opt.value = type.databasetypeid;
      opt.textContent = type.databasetypename;
      databasetypeidSelect.appendChild(opt);
    }

    // Populate form fields
    if (db.databaseid) {
      databaseidInput.value = db.databaseid;
      deleteBtn.style.display = 'block';
      submitLabel.textContent = '<%== __("Update") %>';
    } else {
      submitLabel.textContent = '<%== __("Create") %>';
    }

    customeridInput.value = db.customerid || formdata.customerid || '';
    databasenameInput.value = db.databasename || '';
    databasetypeidSelect.value = db.databasetypeid || (types[0]?.databasetypeid || '');
    usernameInput.value = db.username || '';

    // Disable database name edit for existing databases
    if (db.databaseid) {
      databasenameInput.readOnly = true;
    }
  }

  // Form submit
  form?.addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!form.checkValidity()) {
      form.classList.add('was-validated');
      return;
    }

    const databaseid = databaseidInput.value;
    const payload = {
      customerid: parseInt(customeridInput.value) || null,
      databasetypeid: parseInt(databasetypeidSelect.value),
      databasename: databasenameInput.value,
      username: usernameInput.value,
    };

    // Only include password if set
    if (passwordInput.value) {
      payload.password = passwordInput.value;
    }

    let url, method;
    if (databaseid) {
      url = '<%== url_for("database_index") %>/' + databaseid;
      method = 'PUT';
    } else {
      url = '<%== url_for("database_index") %>';
      method = 'POST';
    }

    const result = await window.authenticatedFetch(url, {
      method: method,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });

    if (result && result.database) {
      // Redirect to customer databases or main list
      const customerid = result.database.customerid;
      if (customerid) {
        window.location.href = '<%== url_for("customer_index") %>/' + customerid + '/databases';
      } else {
        window.location.href = '<%== url_for("database_index") %>';
      }
    }
  });

  // Delete button
  deleteBtn?.addEventListener('click', async () => {
    if (!confirm('<%== __("Are you sure you want to delete this database?") %>')) {
      return;
    }

    const databaseid = databaseidInput.value;
    const url = '<%== url_for("database_index") %>/' + databaseid;

    const result = await window.authenticatedFetch(url, { method: 'DELETE' });
    if (result && result.success) {
      const customerid = customeridInput.value;
      if (customerid) {
        window.location.href = '<%== url_for("customer_index") %>/' + customerid + '/databases';
      } else {
        window.location.href = '<%== url_for("database_index") %>';
      }
    }
  });

  // Initial load
  fetchFormData();
})();
