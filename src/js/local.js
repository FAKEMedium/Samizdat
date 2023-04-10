let docid = 0
let suneditor = 0
async function magiclink (event, el) {
    const ref = el || event.relatedTarget;
    const url = ref.href || ref.action;
    const method = ref.method || 'get';
    const target = ref.target;
    var response = await fetch(url, { method: method});
    const body = await response.text();
    return body;
}

async function modalLoad (event) {
    let ref = event.relatedTarget;
    const url = ref.href || ref.action;
    const method = ref.method || 'get';
    const target = ref.target;
    var response = await fetch(url, { method: method});
    const body = await response.text();
    document.getElementById('modalDialog').innerHTML = body;
}
document.addEventListener("DOMContentLoaded", () => {
    const html = document.getElementsByTagName("html")[0];
    html.classList.remove("no-js");
    html.classList.add("js");
    const universalmodal = document.getElementById('universalmodal');
    universalmodal.addEventListener('shown.bs.modal', (event) => modalLoad(event));
    document.querySelectorAll('.magiclink').forEach( el => {
       el.addEventListener('click', (e) => { e.preventDefault(); magiclink(e, el); } );
       el.addEventListener('submit', (e) => { e.preventDefault(); magiclink(e, el); } );
    });
});