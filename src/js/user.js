let userid = 0
let username = ""
let displayname = ""
let messages = 0
let superadmin = 0

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
        while (c.charAt(0) === ' ')
            c = c.substring(1)
        if (c.indexOf(name) === 0)
            return c.substring(name.length, c.length)
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

document.addEventListener("DOMContentLoaded", () => {
    checkUsername()
})