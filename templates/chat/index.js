const wsUrl = '<%== url_for("chat_stream_ws")->to_abs %>';
const apiList = '<%== url_for("Chat.conversations.index") %>';
const apiSave = '<%== url_for("Chat.conversations.save") %>';
const apiGetTemplate = '<%== url_for("Chat.conversations.get", id => "__ID__") =~ s/__ID__//r %>';
const apiDeleteTemplate = '<%== url_for("Chat.conversations.delete", id => "__ID__") =~ s/__ID__//r %>';

const messagesEl = document.querySelector('#chatMessages');
const form = document.querySelector('#chatForm');
const input = document.querySelector('#chatInput');
const sendBtn = document.querySelector('#sendBtn');
const saveBtn = document.querySelector('#saveBtn');
const newChatBtn = document.querySelector('#newChatBtn');
const conversationListEl = document.querySelector('#conversationList');

let conversationHistory = [];
let ws = null;
let currentAssistantEl = null;
let currentAssistantText = '';

function connectWs() {
  ws = new WebSocket(wsUrl);
  ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    if (data.type === 'delta') {
      currentAssistantText += data.text;
      if (currentAssistantEl) {
        const contentEl = currentAssistantEl.querySelector('.message-content');
        if (contentEl) contentEl.innerHTML = renderMarkdown(currentAssistantText);
        messagesEl.scrollTop = messagesEl.scrollHeight;
      }
    } else if (data.type === 'done') {
      if (currentAssistantText) {
        conversationHistory.push({ role: 'assistant', content: currentAssistantText });
        if (currentAssistantEl) currentAssistantEl.dataset.raw = currentAssistantText;
      }
      currentAssistantEl = null;
      currentAssistantText = '';
      sendBtn.disabled = false;
      input.focus();
    } else if (data.type === 'error') {
      appendMessage('system', data.error);
      sendBtn.disabled = false;
    }
  };
  ws.onclose = () => {
    setTimeout(connectWs, 2000);
  };
}

function appendMessage(role, content) {
  const div = document.createElement('div');
  div.className = `message ${role}`;
  if (role === 'assistant') {
    const contentEl = document.createElement('div');
    contentEl.className = 'message-content';
    contentEl.innerHTML = renderMarkdown(content);
    div.appendChild(contentEl);
    const copyBtn = document.createElement('button');
    copyBtn.className = 'btn btn-sm btn-outline-secondary mt-1 copy-btn';
    copyBtn.textContent = '<%== __("Copy") %>';
    copyBtn.addEventListener('click', () => {
      navigator.clipboard.writeText(div.dataset.raw || content);
      copyBtn.textContent = '<%== __("Copied") %>';
      setTimeout(() => copyBtn.textContent = '<%== __("Copy") %>', 2000);
    });
    div.appendChild(copyBtn);
  } else {
    div.innerHTML = escapeHtml(content);
  }
  messagesEl.appendChild(div);
  messagesEl.scrollTop = messagesEl.scrollHeight;
  return div;
}

function sendMessage(text) {
  if (!text.trim() || !ws || ws.readyState !== WebSocket.OPEN) return;

  conversationHistory.push({ role: 'user', content: text });
  appendMessage('user', text);

  currentAssistantText = '';
  currentAssistantEl = appendMessage('assistant', '');

  sendBtn.disabled = true;
  ws.send(JSON.stringify({ messages: conversationHistory }));
}

function clearChat() {
  conversationHistory = [];
  messagesEl.innerHTML = '';
  input.focus();
}

// Conversation management

async function loadConversationList() {
  try {
    const response = await fetch(apiList, {
      headers: { Accept: 'application/json' }
    });
    const data = await response.json();
    const conversations = data.conversations || [];

    conversationListEl.innerHTML = conversations.map(c => `
      <div class="list-group-item list-group-item-action d-flex justify-content-between align-items-start">
        <div class="me-auto text-truncate" style="cursor: pointer;" data-load="${c.id}">
          <small>${escapeHtml(c.title || '<%== __("Untitled") %>')}</small>
          <br><small class="text-muted">${c.updated ? new Date(c.updated).toLocaleDateString() : ''}</small>
        </div>
        <button class="btn btn-sm btn-outline-danger ms-1" data-delete="${c.id}">x</button>
      </div>
    `).join('');

    // Bind events via delegation
    conversationListEl.querySelectorAll('[data-load]').forEach(el => {
      el.addEventListener('click', () => loadConversation(el.dataset.load));
    });
    conversationListEl.querySelectorAll('[data-delete]').forEach(el => {
      el.addEventListener('click', () => deleteConversation(el.dataset.delete));
    });
  } catch (e) {
    console.error('Failed to load conversations:', e);
  }
}

async function loadConversation(id) {
  try {
    const response = await fetch(apiGetTemplate + id, {
      headers: { Accept: 'application/json' }
    });
    const conv = await response.json();
    if (conv.messages) {
      clearChat();
      conversationHistory = conv.messages;
      conv.messages.forEach(m => appendMessage(m.role, m.content));
    }
  } catch (e) {
    console.error('Failed to load conversation:', e);
  }
}

async function saveConversation() {
  if (!conversationHistory.length) return;

  const title = conversationHistory[0].content.substring(0, 80);
  try {
    const response = await fetch(apiSave, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify({ title, messages: conversationHistory })
    });
    const result = await response.json();
    if (result.success) {
      loadConversationList();
    }
  } catch (e) {
    console.error('Failed to save conversation:', e);
  }
}

async function deleteConversation(id) {
  try {
    await fetch(apiDeleteTemplate + id, {
      method: 'DELETE',
      headers: { Accept: 'application/json' }
    });
    loadConversationList();
  } catch (e) {
    console.error('Failed to delete conversation:', e);
  }
}

// Event listeners

form.addEventListener('submit', (e) => {
  e.preventDefault();
  const text = input.value;
  input.value = '';
  sendMessage(text);
});

input.addEventListener('keydown', (e) => {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    form.dispatchEvent(new Event('submit'));
  }
});

if (saveBtn) saveBtn.addEventListener('click', (e) => {
  e.preventDefault();
  saveConversation();
});

if (newChatBtn) newChatBtn.addEventListener('click', (e) => {
  e.preventDefault();
  clearChat();
});

// Markdown rendering

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

function renderMarkdown(text) {
  let html = text.replace(/```(\w*)\n([\s\S]*?)```/g, (m, lang, code) => {
    return `<pre><code class="${escapeHtml(lang)}">${escapeHtml(code.trim())}</code></pre>`;
  });
  html = html.replace(/`([^`]+)`/g, '<code>$1</code>');
  html = html.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
  html = html.replace(/\*(.+?)\*/g, '<em>$1</em>');
  html = html.replace(/^### (.+)$/gm, '<h5>$1</h5>');
  html = html.replace(/^## (.+)$/gm, '<h4>$1</h4>');
  html = html.replace(/^# (.+)$/gm, '<h3>$1</h3>');
  html = html.replace(/^- (.+)$/gm, '<li>$1</li>');
  html = html.replace(/(<li>.*<\/li>)/gs, '<ul>$1</ul>');
  html = html.replace(/\n/g, '<br>');
  html = html.replace(/(<\/(pre|h[3-5]|ul|li)>)<br>/g, '$1');
  html = html.replace(/<br>(<(pre|h[3-5]|ul))/g, '$1');
  return html;
}

// Init
connectWs();
loadConversationList();
