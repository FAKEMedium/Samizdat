document.addEventListener('DOMContentLoaded', () => {
  const form = document.querySelector('#contactform');

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
      document.querySelector('#compose').innerHTML = result.sent;
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
});
