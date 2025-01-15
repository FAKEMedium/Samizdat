const form = document.querySelector("#dataform");
form.addEventListener("submit", (event) => {
  event.preventDefault();
});

async function sendData(method) {
  const url = form.action || "";
  const target = form.target || "";
  const formData = new FormData(form);
  const request = {
    method: method,
    headers: {Accept: 'application/json'}
  };
  if (method != 'GET') {
    request.body = formData;
  }
  if (method == 'POST') {
    request.headers.Accept = 'application/json, application/pdf';
  }
  try {
    const response = await fetch(url, request);
    if (response.error) {
      alert(error);
    } else {
      populateForm(await response.json(), method);
    }
  } catch (e) {
    console.error(e);
  }
}

function makecreditInvoice() {
  sendData('PUT');
}

function remindInvoice() {

}

function reprintInvoice() {

}

function resendInvoice() {

}

function markpaidInvoice() {

}