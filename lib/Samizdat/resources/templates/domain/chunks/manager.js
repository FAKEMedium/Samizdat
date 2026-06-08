document.querySelector('#cardcol-<%== $service %> h5.card-header').innerHTML = `<%== __('Domains') %>`;

// Add contact button - opens modal
document.getElementById('addContactBtn')?.addEventListener('click', async (e) => {
  e.preventDefault();
  document.querySelector('#universalmodal #modalDialog')?.classList.add('modal-xl');
  await window.openModalFromUrl('<%== url_for('domain_contact_new') %>');
});