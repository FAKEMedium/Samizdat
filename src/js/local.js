let docid = 0
let userid = 0
let username = ""
let displayname = ""
let messages = 0
let superadmin = 0
let suneditor = 0

function setCookie(cname, cvalue, exdays) {
    let d = new Date()
    d.setTime(d.getTime() + (exdays*24*60*60*1000))
    let expires = "expires="+ d.toUTCString()
    document.cookie = cname + "=" + cvalue + ";" + expires + ";path=/"
}

function getCookie(cname) {
    let name = cname + "=";
    let decodedCookie = decodeURIComponent(document.cookie);
    let ca = decodedCookie.split(';');
    for(let i = 0; i <ca.length; i++) {
        let c = ca[i];
        while (c.charAt(0) === ' ') {c = c.substring(1);}
        if (c.indexOf(name) === 0) {return c.substring(name.length, c.length);}
    }
    return "";
}

function deleteCookie(cname) {
    document.cookie = cname + "=logout; expires=Sat, 23 Mar 2023 13:40:42 GMT; domain=.fakenews.com; path=/; secure; SameSite=None; Max-Age=0"
}

function decodeBase64(s) {
    let e={},i,b=0,c,x,l=0,a,r='',w=String.fromCharCode,L=s.length;
    let A="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    for(i=0;i<64;i++){e[A.charAt(i)]=i;}
    for(x=0;x<L;x++){
        c=e[s.charAt(x)];b=(b<<6)+c;l+=6;
        while(l>=8){((a=(b>>>(l-=8))&0xff)||(x<(L-2)))&&(r+=w(a));}
    }
    return r;
};


function checkUsername() {
    let userdata = getCookie('samizdata');
    if ('logout' === userdata) return "";
    if (userdata) {
        userdata = decodeBase64(userdata);
        let u = JSON.parse(userdata);
        userid = u.i;
        messages = u.m;
        username = u.n;
        displayname = u.d;
        superadmin = u.s;
        cartcount = parseInt(u.b);
        if ("" !== username) {
            document.querySelectorAll(".auth").forEach(el => { el.classList.toggle("d-none") });
            document.querySelectorAll("#userdropdown a.pp").forEach(el => { el.setAttribute('href', '/') });
            document.querySelectorAll(".username").forEach(el => { el.innerHTML = username });
            document.querySelectorAll(".displayname").forEach(el => { el.innerHTML = displayname });
            document.getElementById('messages').innerHTML = messages;
        }
        if (superadmin) {
            const childlist = document.querySelector("#memberpanel").children;
            for (let i = 0; i < childlist.length; i++) {
                childlist.item(i).classList.add("superadmin");
            }
        }
    }
}

async function magiclink (event, el) {
    const ref = el || event.relatedTarget;
    const url = ref.href || ref.action;
    const method = ref.method;
    const target = ref.target;
    var response;
    if ('get' === method) {
        response = await fetch(url);
    } else {
        response = await fetch(url, { method: method});
    }
    const body = await response.text();
    return body;
}

async function modalLoad (event) {
    let ref = event.relatedTarget;
    const url = ref.href || ref.action;
    const method = ref.method;
    const target = ref.target;
    var response;
    if ('get' === method) {
        response = await fetch(url);
    } else {
        response = await fetch(url, { method: method});
    }
    const body = await response.text();
    document.getElementById('modalDialog').innerHTML = body;
}
document.addEventListener("DOMContentLoaded", () => {
    checkUsername();
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

// https://stackoverflow.com/questions/12982156/select-copy-text-using-javascript-or-jquery
function copy_text(element) {
    var text = document.getElementById(element);
    var selection = window.getSelection();
    var range = document.createRange();
    range.selectNodeContents(text);
    selection.removeAllRanges();
    selection.addRange(range);
    document.execCommand('copy');
}


// Sortera tabeller med klick i kolumnhuvudet
const getCellValue = (tr, idx) => tr.children[idx].innerText || tr.children[idx].textContent;

const comparer = (idx, asc) => (a, b) => ((v1, v2) =>
        v1 !== '' && v2 !== '' && !isNaN(v1) && !isNaN(v2) ? v1 - v2 : v1.toString().localeCompare(v2)
)(getCellValue(asc ? a : b, idx), getCellValue(asc ? b : a, idx));

document.querySelectorAll('th').forEach(
    th => th.addEventListener('click', (() => {
        const table = th.closest('table');
        const tbody = table.querySelector('tbody');
        Array.from(tbody.querySelectorAll('tr'))
            .sort(comparer(Array.from(th.parentNode.children).indexOf(th), this.asc = !this.asc))
            .forEach(tr => tbody.appendChild(tr) );
    })));



// function from http://forums.devshed.com/t39065/s84ded709f924610aa44fff827511aba3.html
// author appears to be Robert Pollard
function sprintf()
{
    if (!arguments || arguments.length < 1 || !RegExp)
    {
        return;
    }
    var str = arguments[0];
    var re = /([^%]*)%('.|0|\x20)?(-)?(\d+)?(\.\d+)?(%|b|c|d|u|f|o|s|x|X)(.*)/;
    var a = b = [], numSubstitutions = 0, numMatches = 0;
    while (a = re.exec(str))
    {
        var leftpart = a[1], pPad = a[2], pJustify = a[3], pMinLength = a[4];
        var pPrecision = a[5], pType = a[6], rightPart = a[7];

        numMatches++;
        if (pType == '%')
        {
            subst = '%';
        }
        else
        {
            numSubstitutions++;
            if (numSubstitutions >= arguments.length)
            {
                alert('Error! Not enough function arguments (' + (arguments.length - 1)
                    + ', excluding the string)\n'
                    + 'for the number of substitution parameters in string ('
                    + numSubstitutions + ' so far).');
            }
            var param = arguments[numSubstitutions];
            var pad = '';
            if (pPad && pPad.substr(0,1) == "'") pad = leftpart.substr(1,1);
            else if (pPad) pad = pPad;
            var justifyRight = true;
            if (pJustify && pJustify === "-") justifyRight = false;
            var minLength = -1;
            if (pMinLength) minLength = parseInt(pMinLength);
            var precision = -1;
            if (pPrecision && pType == 'f')
                precision = parseInt(pPrecision.substring(1));
            var subst = param;
            switch (pType)
            {
                case 'b':
                    subst = parseInt(param).toString(2);
                    break;
                case 'c':
                    subst = String.fromCharCode(parseInt(param));
                    break;
                case 'd':
                    subst = parseInt(param) ? parseInt(param) : 0;
                    break;
                case 'u':
                    subst = Math.abs(param);
                    break;
                case 'f':
                    subst = (precision > -1)
                        ? Math.round(parseFloat(param) * Math.pow(10, precision))
                        / Math.pow(10, precision)
                        : parseFloat(param);
                    break;
                case 'o':
                    subst = parseInt(param).toString(8);
                    break;
                case 's':
                    subst = param;
                    break;
                case 'x':
                    subst = ('' + parseInt(param).toString(16)).toLowerCase();
                    break;
                case 'X':
                    subst = ('' + parseInt(param).toString(16)).toUpperCase();
                    break;
            }
            var padLeft = minLength - subst.toString().length;
            if (padLeft > 0)
            {
                var arrTmp = new Array(padLeft+1);
                var padding = arrTmp.join(pad?pad:" ");
            }
            else
            {
                var padding = "";
            }
        }
        str = leftpart + padding + subst + rightPart;
    }
    return str;
}
