// RealtimeRegister pricelist
const pricelistContent = document.getElementById('pricelistContent');
const currencySelect = document.getElementById('currencySelect');
const apiUrl = '<%== url_for('RTR.pricelist.index') %>';
const defaultCurrency = '<%== $default_currency %>';

// Format price from cents to currency
function formatPrice(cents, currency) {
  const amount = cents / 100;
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: currency }).format(amount);
}

async function loadPricelist(currency) {
  pricelistContent.innerHTML = '<div class="spinner-border" role="status"><span class="visually-hidden"><%== __('Loading...') %></span></div>';

  try {
    const url = currency ? `${apiUrl}?currency=${currency}` : apiUrl;
    const data = await window.authenticatedFetch(url);

    if (!data || !data.pricelist) {
      pricelistContent.innerHTML = '<p class="text-danger"><%== __('Failed to load price list') %></p>';
      return;
    }

    const pricelist = data.pricelist;
    let html = '';

    // Current prices
    if (pricelist.prices && pricelist.prices.length > 0) {
      html += `<h3 class="h6"><%== __('Current Prices') %></h3>`;
      html += `<div class="table-responsive"><table class="table table-sm table-striped">
        <thead><tr><th><%== __('Product') %></th><th><%== __('Action') %></th><th class="text-end"><%== __('Price') %></th></tr></thead>
        <tbody>`;
      for (const p of pricelist.prices) {
        html += `<tr><td>${p.product}</td><td>${p.action}</td><td class="text-end">${formatPrice(p.price, p.currency)}</td></tr>`;
      }
      html += `</tbody></table></div>`;
    }

    // Price changes
    if (pricelist.priceChanges && pricelist.priceChanges.length > 0) {
      html += `<h3 class="h6 mt-4"><%== __('Upcoming Price Changes') %></h3>`;
      html += `<div class="table-responsive"><table class="table table-sm table-striped">
        <thead><tr><th><%== __('Product') %></th><th><%== __('Action') %></th><th class="text-end"><%== __('New Price') %></th><th><%== __('Effective Date') %></th></tr></thead>
        <tbody>`;
      for (const p of pricelist.priceChanges) {
        html += `<tr><td>${p.product}</td><td>${p.action}</td><td class="text-end">${formatPrice(p.price, p.currency)}</td><td>${p.effectiveDate || ''}</td></tr>`;
      }
      html += `</tbody></table></div>`;
    }

    // Promos
    if (pricelist.promos && pricelist.promos.length > 0) {
      html += `<h3 class="h6 mt-4"><%== __('Promotions') %></h3>`;
      html += `<div class="table-responsive"><table class="table table-sm table-striped">
        <thead><tr><th><%== __('Product') %></th><th><%== __('Action') %></th><th class="text-end"><%== __('Price') %></th><th><%== __('Period') %></th><th><%== __('Status') %></th></tr></thead>
        <tbody>`;
      for (const p of pricelist.promos) {
        const status = p.active ? '<span class="badge bg-success"><%== __('Active') %></span>' : '<span class="badge bg-secondary"><%== __('Inactive') %></span>';
        const period = `${p.startDate || ''} - ${p.endDate || ''}`;
        html += `<tr><td>${p.product}</td><td>${p.action}</td><td class="text-end">${formatPrice(p.price, p.currency)}</td><td>${period}</td><td>${status}</td></tr>`;
      }
      html += `</tbody></table></div>`;
    }

    if (!html) {
      html = '<p class="text-muted"><%== __('No price data available') %></p>';
    }

    pricelistContent.innerHTML = html;
  } catch (error) {
    console.error('Error loading pricelist:', error);
    pricelistContent.innerHTML = '<p class="text-danger"><%== __('Error loading price list') %></p>';
  }
}

// Currency selector (only exists if multiple currencies configured)
if (currencySelect) {
  currencySelect.addEventListener('change', () => {
    loadPricelist(currencySelect.value);
  });
}

// Initial load
loadPricelist(currencySelect ? currencySelect.value : defaultCurrency);
