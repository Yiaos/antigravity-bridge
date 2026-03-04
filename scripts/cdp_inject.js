#!/usr/bin/env node
// cdp_inject.js — 通过 CDP 注入 prompt 到 Antigravity Lexical chat editor
// 用法: AGY_PROMPT="任务描述" node cdp_inject.js
//
// 工作原理:
// 1. 通过 CDP /json/list 找到 Antigravity workbench page
// 2. 连接 WebSocket
// 3. 找到主 chat 的 Lexical editor (editors[last])
// 4. Cmd+A 全选 → Backspace 删除 → Paste prompt → Enter 提交

const WebSocket = require('ws');
const http = require('http');

const PROMPT = process.env.AGY_PROMPT;
if (!PROMPT) { console.error('❌ AGY_PROMPT not set'); process.exit(1); }

const CDP_PORT = process.env.CDP_PORT || 9229;

function getWorkbenchWsUrl() {
    return new Promise((resolve, reject) => {
        http.get(`http://localhost:${CDP_PORT}/json/list`, (res) => {
            let data = '';
            res.on('data', d => data += d);
            res.on('end', () => {
                try {
                    const pages = JSON.parse(data);
                    const wb = pages.find(p =>
                        p.url?.includes('workbench.html') && !p.url?.includes('jetski')
                    );
                    if (wb) resolve(wb.webSocketDebuggerUrl);
                    else reject(new Error('No workbench page found. Is Antigravity open?'));
                } catch (e) { reject(e); }
            });
        }).on('error', reject);
    });
}

function injectPrompt(wsUrl, prompt) {
    return new Promise((resolve, reject) => {
        const ws = new WebSocket(wsUrl);

        ws.on('open', () => {
            // Escape prompt for JS template literal safety
            const safe = prompt.replace(/\\/g, '\\\\').replace(/`/g, '\\`').replace(/\$/g, '\\$');

            ws.send(JSON.stringify({
                id: 1,
                method: 'Runtime.evaluate',
                params: {
                    expression: `
                        (async () => {
                            const editors = document.querySelectorAll('[data-lexical-editor="true"]');
                            const mainChat = editors[editors.length - 1];
                            if (!mainChat) return 'ERROR: no chat editor found (editors=' + editors.length + ')';

                            mainChat.focus();

                            // Select all
                            mainChat.dispatchEvent(new KeyboardEvent('keydown', {
                                key: 'a', code: 'KeyA', keyCode: 65, metaKey: true, bubbles: true
                            }));
                            await new Promise(r => setTimeout(r, 100));

                            // Delete
                            mainChat.dispatchEvent(new KeyboardEvent('keydown', {
                                key: 'Backspace', code: 'Backspace', keyCode: 8, bubbles: true
                            }));
                            await new Promise(r => setTimeout(r, 200));

                            // Paste
                            const dt = new DataTransfer();
                            dt.setData('text/plain', \`${safe}\`);
                            mainChat.dispatchEvent(new ClipboardEvent('paste', {
                                clipboardData: dt, bubbles: true, cancelable: true, composed: true
                            }));
                            await new Promise(r => setTimeout(r, 200));

                            // Verify paste
                            const text = mainChat.innerText || '';
                            if (!text) return 'ERROR: paste failed (editor empty after paste)';

                            // Submit
                            mainChat.dispatchEvent(new KeyboardEvent('keydown', {
                                key: 'Enter', code: 'Enter', keyCode: 13, bubbles: true
                            }));
                            await new Promise(r => setTimeout(r, 300));

                            return 'OK';
                        })()
                    `,
                    awaitPromise: true,
                    returnByValue: true
                }
            }));
        });

        ws.on('message', (data) => {
            const resp = JSON.parse(data);
            if (resp.id === 1) {
                ws.close();
                const val = resp.result?.result?.value || '';
                if (val === 'OK') resolve();
                else reject(new Error(val || resp.result?.exceptionDetails?.text || 'unknown'));
            }
        });

        ws.on('error', reject);
        setTimeout(() => reject(new Error('timeout (15s)')), 15000);
    });
}

(async () => {
    try {
        const wsUrl = await getWorkbenchWsUrl();
        await injectPrompt(wsUrl, PROMPT);
        console.log('✅ Prompt submitted to Antigravity agent');
        process.exit(0);
    } catch (e) {
        console.error('❌ ' + e.message);
        process.exit(1);
    }
})();
