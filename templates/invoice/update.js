function accountchart {
    this.form.getAttributeNode('action').value = 'printinvoice.cgi';
    if (document.getElementById('accountchart').style.display == 'none') {
        document.getElementById('accountchart').style.display = 'block';
        alert('Fyll i kontolistan för denna kundfordring');
        this.form.getAttributeNode('action').value = '/roomservice/kunddatabas/invoice.cgi';
        return false;
    }
    if (CheckSums())
        return confirm('Gå vidare om du inte behöver uppdatera mer.');
    else {
        this.form.getAttributeNode('action').value = '/roomservice/kunddatabas/invoice.cgi';
        return false;
    }
}