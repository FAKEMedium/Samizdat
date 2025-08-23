async function magiclink (event, el) {
    try {
        const ref = el || event.relatedTarget;
        const url = ref.href || ref.action;
        const method = ref.method || 'get';
        const response = await fetch(url, { method: method});
        return await response.text();
    } catch (e) {
        return '';
    }
}

async function modalLoad(event) {
    try {
        let ref = event.relatedTarget;
        const url = ref.href || ref.action;
        const method = ref.method || 'get';
        const response = await fetch(url, { method: method});
        const body = await response.text();
        let modaldialog = document.querySelector('#modalDialog');
        modaldialog.innerHTML = "\n" + body;
        let modalscript = document.querySelector('#modalscript');
        let script = document.createElement('script');
        script.id = 'modaljs';
        script.innerHTML = modalscript.innerHTML;
        modaldialog.appendChild(script);
        document.querySelector('#modalscript').remove();
    } catch (e) {
        // Silent error handling
    }
}

document.querySelectorAll("html").forEach(docroot => {
    docroot.classList.remove("no-js");
    docroot.classList.add("js");
});
const universalmodal = document.querySelector('#universalmodal');
universalmodal.addEventListener('shown.bs.modal', (event) => modalLoad(event));