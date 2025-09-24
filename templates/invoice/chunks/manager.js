document.querySelector('#cardcol-<%== $service %> h5.card-header').innerHTML = `<%== __('Invoices') %>`;

// Function to get cookie value
function getCookie(name) {
  const value = `; ${document.cookie}`;
  const parts = value.split(`; ${name}=`);
  if (parts.length === 2) return parts.pop().split(';').shift();
  return null;
}

// Populate form fields from JSON cookie
const invoiceCard = document.querySelector('#cardcol-<%== $service %>');
if (invoiceCard) {
  const filterCookie = getCookie('invoicefilter');
  if (filterCookie) {
    try {
      const filter = JSON.parse(decodeURIComponent(filterCookie));

      // Populate searchterm
      if (filter.searchterm !== undefined) {
        const searchtermInput = invoiceCard.querySelector('input[name="searchterm"]');
        if (searchtermInput) {
          searchtermInput.value = filter.searchterm;
        }
      }

      // Populate paid checkbox
      if (filter.paid !== undefined) {
        const paidCheckbox = invoiceCard.querySelector('input[name="paid"]');
        if (paidCheckbox) {
          paidCheckbox.checked = (filter.paid === 1 || filter.paid === '1' || filter.paid === true);
        }
      }

      // Populate unpaid checkbox
      if (filter.unpaid !== undefined) {
        const unpaidCheckbox = invoiceCard.querySelector('input[name="unpaid"]');
        if (unpaidCheckbox) {
          unpaidCheckbox.checked = (filter.unpaid === 1 || filter.unpaid === '1' || filter.unpaid === true);
        }
      }

      // Populate destroyed checkbox
      if (filter.destroyed !== undefined) {
        const destroyedCheckbox = invoiceCard.querySelector('input[name="destroyed"]');
        if (destroyedCheckbox) {
          destroyedCheckbox.checked = (filter.destroyed === 1 || filter.destroyed === '1' || filter.destroyed === true);
        }
      }
    } catch (e) {
      console.error('Error parsing invoice filter cookie:', e);
    }
  }
}