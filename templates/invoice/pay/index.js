// Payment modal JS - initializes payment widgets with invoice data
const payModalContent = document.getElementById('pay-modal-content');
if (payModalContent) {
  const amount = payModalContent.dataset.amount;
  const currency = payModalContent.dataset.currency;
  const invoiceid = payModalContent.dataset.invoiceid;
  const fakturanummer = payModalContent.dataset.fakturanummer;

  // Set global payment context for payment widget scripts
  window.paymentContext = { amount, currency, invoiceid, fakturanummer };

  // Payment method radio toggle
  const radios = payModalContent.querySelectorAll('input[name="paymethod"]');
  const panels = payModalContent.querySelectorAll('.pay-panel');

  function showPanel(methodId) {
    panels.forEach(panel => {
      const isActive = panel.id === 'paypanel-' + methodId;
      panel.hidden = !isActive;
    });
  }

  radios.forEach(radio => {
    radio.addEventListener('change', () => showPanel(radio.value));
    if (radio.checked) showPanel(radio.value);
  });
}
