const form = document.querySelector('#dataform');

form.addEventListener('submit', async (event) => {
  event.preventDefault();
  const formData = new FormData(form);
  const response = await fetch(form.action, {
    method: 'POST',
    body: formData,
    headers: {
      'Accept': 'application/json'
    }
  });

  const result = await response.json();

  if (result.success) {
    document.querySelector('#thecontent').innerHTML = `
    <p><%== __x('A confirmation link was mailed to {email}.', email => 'REPLACEEMAIL') %></p>`
    .replace('REPLACEEMAIL', result.email);

    // Scoll to start of content
    const el = document.querySelector('#startdoc');
    if (el) {
      el.scrollIntoView({
        behavior: 'smooth',
        block:    'start'
      });
    }
  } else {
    const feedback = document.querySelectorAll('div.invalid-feedback');
    feedback.forEach( (el) => {
      el.classList.add('d-none');
    });

    for (const [field, error] of Object.entries(result.errors)) {
      const errorDiv = document.querySelector(`#invalid${field}`);
      if (errorDiv) {
        errorDiv.textContent = error;
        errorDiv.classList.remove('d-none');
      }

      // Replace the captcha image if code was wrong
      if (field === 'captcha' && error !== '') {
        const el = document.querySelector(`#captchaimage`);
        if (el) {
          el.src= `/captcha.png?${Math.random()}`;
        }
      }
    }

    for (const [field, value] of Object.entries(result.valid)) {
      const el = document.querySelector(`#${field}`);
      if (el) {
        el.classList.remove('is-invalid');
        el.classList.remove('invalid');
        el.classList.add(value);
      }
    }
  }
});

async function loadData() {
  const url = form.action || "";
  const request = {
    method: 'GET',
    headers: {Accept: 'application/json'}
  };
  try {
    const response = await fetch(url, request);
    if (response.error) {
      alert(error);
    } else {
      const result = await response.json();
      document.querySelector('#ip').innerHTML = `<%== __x('Your ip {ip} will be appended to the confirmation request.', ip => $formdata->{ip}) %>`
        .replace('REPLACEIP', result.ip);
    }
  } catch (e) {
    // Silent error handling
  }
}

loadData();