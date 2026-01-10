document.querySelector('#cardcol-<%== $service %> h5.card-header').innerHTML = `<%== __('Mail') %>`;

(function() {
  const card = document.getElementById('cardcol-<%== $service %>');
  const form = card.querySelector('form[name="searchemail"]');
  if (!form) return;

  const searchInput = form.querySelector('input[name="searchterm"]');
  const basePath = '<%== url_for("email_index") %>';

  const placeholders = {
    domain: '<%== __('Search for mail domain') %>...',
    mailbox: '<%== __('Search for mailbox') %>...',
    admin: '<%== __('Search for admin') %>...'
  };

  function getSelectedType() {
    const checked = form.querySelector('input[name="searchwhat"]:checked');
    return checked ? checked.value : 'domain';
  }

  function updatePlaceholder() {
    searchInput.placeholder = placeholders[getSelectedType()];
  }

  function doSearch() {
    const type = getSelectedType();
    const term = searchInput.value;
    let url = basePath + '?type=' + type + 's';
    if (term) url += '&searchterm=' + encodeURIComponent(term);
    window.location.href = url;
  }

  // Radio button changes
  form.querySelectorAll('input[name="searchwhat"]').forEach(radio => {
    radio.addEventListener('change', updatePlaceholder);
  });

  // Search button click
  const searchBtn = form.querySelector('button');
  if (searchBtn) {
    searchBtn.addEventListener('click', doSearch);
  }

  // Enter key in search field
  searchInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      doSearch();
    }
  });

  // Add domain button
  const newDomainBtn = card.querySelector('#newDomainBtn');
  if (newDomainBtn) {
    newDomainBtn.addEventListener('click', () => {
      window.location.href = basePath + '/domain';
    });
  }

  // Add admin button
  const newAdminBtn = card.querySelector('#newAdminBtn');
  if (newAdminBtn) {
    newAdminBtn.addEventListener('click', () => {
      window.location.href = basePath + '/admin';
    });
  }
})();