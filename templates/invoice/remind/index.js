document.querySelector('#remindform').addEventListener("submit", (event) => {event.preventDefault()});
document.querySelector('#billingemail').value = billingemail;
document.querySelector('#subject').value = `<%== __x('Invoice reminder, {number}', number => 'number') %>`
  .replace('number', fakturanummer);