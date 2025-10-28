document.querySelector('#cardcol-<%== $service %> h5.card-header').innerHTML = `<%== __('DNS Zones') %>`;

// Open new zone modal
document.querySelector('#newZoneManager')?.addEventListener('click', async () => {
  const universalModal = new bootstrap.Modal('#universalmodal');
  const modalDialog = document.querySelector('#universalmodal #modalDialog');
  const modalResponse = await fetch('<%== url_for('zone_new') %>');
  const modalHTML = await modalResponse.text();
  modalDialog.innerHTML = modalHTML;
  universalModal.show();
});