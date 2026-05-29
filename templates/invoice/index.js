let currentPage = 1;

const form = document.querySelector("#dataform");
form.addEventListener("submit", (event) => {
  event.preventDefault();
});

async function sendData(method, page) {
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
  let fetchUrl = window.location.pathname;
  if (method === 'GET' && page) {
    fetchUrl += `?page=${page}`;
  }
  try {
    const response = await fetch(fetchUrl, request);
    if (!response.ok) {
      if (response.status === 401) {
        // Handled by the global fetch interceptor (apidom.js), which opens the
        // login form in #universalmodal. Don't double-handle it here.
        return;
      } else {
        alert('Request failed: ' + response.statusText);
      }
    } else {
      populateForm(await response.json(), method);
    }
  } catch (e) {
    console.error('Request error:', e);
    alert('Request failed');
  }
}

function updateInvoice() {
  sendData('PUT');
}

function getInvoices(page = 1){
  currentPage = page;
  sendData('GET', page);
}

function populateForm(formdata, method) {
  let invoices = formdata.invoices;
  let customer = formdata.customer;
  const isAdmin = formdata.admin ? true : false;

  // Toggle admin-only columns
  document.querySelectorAll('.admin-only').forEach(el => {
    el.classList.toggle('d-none', !isAdmin);
  });

  // Invoices
  let snippet = '';
  let due = 0;
  let notdue = 0;
  let unpaid = 0;
  let paid = 0;
  invoices = invoices.sortBy('-invoicedate', '-invoiceid');
  for (const invoice of invoices) {
    let rowclass = ['text-end'];
    if (invoice.due) {
      due++;
      unpaid++;
      rowclass.push('text-white');
      rowclass.push('bg-danger');
    } else if ('fakturerad' === invoice.state) {
      notdue++;
      unpaid++;
      rowclass.push('text-dark');
      rowclass.push('bg-warning');
    } else if ('bokford' === invoice.state) {
      paid++;
      rowclass.push('text-white');
      rowclass.push('bg-success');
    }
    // Create payment date cell based on state (admin only)
    let paymentCell = '';
    if (isAdmin) {
      if (invoice.state === 'fakturerad') {
        // Show payment button for unpaid invoices
        paymentCell = `<button type="button" class="btn btn-sm btn-outline-primary payment-btn"
          data-invoiceid="${invoice.invoiceid}"
          data-customerid="${invoice.customerid}"
          data-customername="${invoice.customername || ''}"
          data-fakturanummer="${invoice.fakturanummer}"
          data-invoicedate="${invoice.invoicedate ? invoice.invoicedate.substring(0, 10) : ''}"
          data-debt="${invoice.debt || invoice.totalcost}"
          data-totalcost="${invoice.totalcost}"
          data-currency="${invoice.currency || ''}">
          <%== icon 'clipboard-plus' %>
        </button>`;
      } else if (invoice.state === 'bokford') {
        // Show payment date for paid invoices
        paymentCell = invoice.paydate ? invoice.paydate.substring(0, 10) : '';
      }
    }

    // Format last reminder date with badge for count (admin only)
    let reminderCell = '';
    if (isAdmin) {
      if (invoice.lastreminderdate) {
        reminderCell = invoice.lastreminderdate.substring(0, 10);
        if (invoice.remindercount > 0) {
          reminderCell += ` <span class="badge bg-secondary">${invoice.remindercount}</span>`;
        }
      } else if (invoice.remindercount > 0) {
        reminderCell = `<span class="badge bg-secondary">${invoice.remindercount}</span>`;
      }
    }

    snippet += `
                <tr data-invoiceid="${invoice.invoiceid}">
                  <td><a href="<%== invoice->url() %>${invoice.uuid}.pdf"><%== icon 'file-pdf' %></a></td>
                  <td><a class="w-auto" href="<%== url_for('invoice_index') %>/${invoice.invoiceid}">${invoice.fakturanummer}</a></td>
                  <td>${invoice.customername || ''}</td>
                  <td>${invoice.invoicedate.substring(0, 10)}</td>
                  <td class="admin-only${isAdmin ? '' : ' d-none'}">${reminderCell}</td>
                  <td class="admin-only${isAdmin ? '' : ' d-none'}">${paymentCell}</td>
                  <td class="text-end">${invoice.totalcost}</td>
                  <td class="text-end">${invoice.debt || invoice.totalcost}</td>
                </tr>`;
  }
  document.querySelector('#invoices tbody').innerHTML = snippet;

  // Pagination
  const total = formdata.total || 0;
  const limit = formdata.limit || 25;
  const page = formdata.page || 1;
  const totalPages = Math.ceil(total / limit);
  buildPagination(page, totalPages);

  if ('PUT' == method) {
    document.querySelector('#toast-messages').innerHTML = `
<%== web->indent($toast, 1) %>`;

    window.setTimeout(dropToast, 2000);
  }
}

function dropToast(){
  document.querySelector('#toast-messages').innerHTML = '';
}

function buildPagination(page, totalPages) {
  const pagination = document.querySelector('#invoicePagination');
  if (!pagination) return;
  if (totalPages <= 1) {
    pagination.innerHTML = '';
    return;
  }
  let html = '';

  // Previous
  html += `<li class="page-item ${page <= 1 ? 'disabled' : ''}">
    <a class="page-link" href="#" data-page="${page - 1}">&laquo;</a>
  </li>`;

  // Pages
  const startPage = Math.max(1, page - 2);
  const endPage = Math.min(totalPages, page + 2);

  if (startPage > 1) {
    html += `<li class="page-item"><a class="page-link" href="#" data-page="1">1</a></li>`;
    if (startPage > 2) {
      html += `<li class="page-item disabled"><span class="page-link">...</span></li>`;
    }
  }

  for (let i = startPage; i <= endPage; i++) {
    html += `<li class="page-item ${i === page ? 'active' : ''}">
      <a class="page-link" href="#" data-page="${i}">${i}</a>
    </li>`;
  }

  if (endPage < totalPages) {
    if (endPage < totalPages - 1) {
      html += `<li class="page-item disabled"><span class="page-link">...</span></li>`;
    }
    html += `<li class="page-item"><a class="page-link" href="#" data-page="${totalPages}">${totalPages}</a></li>`;
  }

  // Next
  html += `<li class="page-item ${page >= totalPages ? 'disabled' : ''}">
    <a class="page-link" href="#" data-page="${page + 1}">&raquo;</a>
  </li>`;

  pagination.innerHTML = html;

  // Click handlers
  pagination.querySelectorAll('a.page-link').forEach(link => {
    link.addEventListener('click', (e) => {
      e.preventDefault();
      const targetPage = parseInt(link.dataset.page);
      if (targetPage >= 1 && targetPage <= totalPages && targetPage !== page) {
        getInvoices(targetPage);
      }
    });
  });
}

// Refresh function called after payment modal submission
window.refreshInvoiceData = function() {
  getInvoices(currentPage);
};

// Event delegation for payment buttons
document.querySelector('#invoices tbody').addEventListener('click', (e) => {
  const btn = e.target.closest('.payment-btn');
  if (btn && typeof window.openPaymentModal === 'function') {
    window.openPaymentModal({
      invoiceid: btn.dataset.invoiceid,
      customerid: btn.dataset.customerid,
      customerName: btn.dataset.customername,
      fakturanummer: btn.dataset.fakturanummer,
      invoicedate: btn.dataset.invoicedate,
      debt: btn.dataset.debt,
      totalcost: btn.dataset.totalcost,
      currency: btn.dataset.currency
    });
  }
});

getInvoices();