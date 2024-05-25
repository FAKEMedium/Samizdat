import '../scss/samizdat.scss';
import { Modal, Collapse, Dropdown, Offcanvas, Toast } from 'bootstrap';
window.bootstrap = { Modal, Collapse, Dropdown, Offcanvas, Toast };

import './user.js';
import './sortby.js';
import './tablesorter.js';
import './local.js';
import './serviceworker.js';
import { setlanguage } from "./language.js";
import 'sprintf-js';
import './shortbytes.js';

let toastElList = document.querySelectorAll('.toast');
let toastList = [...toastElList].map(toastEl => new Toast(toastEl));