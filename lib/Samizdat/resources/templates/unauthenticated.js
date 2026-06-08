function clickLogin(){
  const node = document.querySelector('#loginbutton');
  node.dispatchEvent(new Event('click'));
}
setTimeout(  clickLogin, 1000);