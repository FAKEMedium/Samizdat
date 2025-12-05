document.querySelector('#cardcol-<%== $service %> h5.card-header').innerHTML = `<%== __('DNS Zones') %>`;

async function openZoneManagerModal(url, wide = false) {
  const universalModal = new bootstrap.Modal('#universalmodal');
  const modalDialog = document.querySelector('#universalmodal #modalDialog');
  const modalResponse = await fetch(url);
  const modalHTML = await modalResponse.text();
  modalDialog.dataset.sourceUrl = url;
  modalDialog.innerHTML = modalHTML;

  // Set modal width
  modalDialog.classList.toggle('modal-xl', wide);

  // Extract and execute modal script
  const modalscript = modalDialog.querySelector('#modalscript');
  if (modalscript) {
    const script = document.createElement('script');
    script.id = 'modaljs';
    script.innerHTML = modalscript.innerHTML;
    modalDialog.appendChild(script);
    modalscript.remove();
  }

  universalModal.show();
}

// Open new zone modal
document.querySelector('#newZoneManager')?.addEventListener('click', async () => {
  await openZoneManagerModal('<%== url_for('zone_new') %>');
});

// Open import zone modal
document.querySelector('#importZoneManager')?.addEventListener('click', async () => {
  await openZoneManagerModal('<%== url_for('zone_import_form') %>', true);
});