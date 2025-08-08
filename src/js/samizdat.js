import '../scss/samizdat.scss';
import { Modal, Collapse, Dropdown, Offcanvas, Toast, Tooltip, Popover } from 'bootstrap';
window.bootstrap = { Modal, Collapse, Dropdown, Offcanvas, Toast, Tooltip, Popover };

import './user.js';
import './sortby.js';
import './tablesorter.js';
// import './sendform.js';
import './local.js';
import './serviceworker.js';
import './language.js';
import { sprintf, vsprintf } from 'sprintf-js';
window.sprintf = sprintf;
window.vsprintf = vsprintf;
import './shortbytes.js';

let toastElList = document.querySelectorAll('.toast');
let toastList = [...toastElList].map(toastEl => new Toast(toastEl));