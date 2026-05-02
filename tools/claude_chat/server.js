const express = require('express');
const { spawn } = require('child_process');
const path = require('path');
const os = require('os');
const fs = require('fs');

const app = express();
app.use(express.json({ limit: '50mb' }));
app.use(express.static(__dirname));

const VALID_EFFORTS = new Set(['low', 'medium', 'high', 'xhigh', 'max']);
const DEFAULT_CWD = 'C:/Games/possession';
const APPDATA = process.env.APPDATA || path.join(os.homedir(), 'AppData', 'Roaming');
const CLAUDE_EXE = path.join(APPDATA, 'npm', 'node_modules', '@anthropic-ai', 'claude-code', 'bin', 'claude.exe');
const USER_SETTINGS_PATH = path.join(os.homedir(), '.claude', 'settings.json');
const CHAT_CONFIG_PATH = path.join(__dirname, '.config.json');

// ── Config helpers ────────────────────────────────────────────────────────────

function readChatConfig() {
    try { return JSON.parse(fs.readFileSync(CHAT_CONFIG_PATH, 'utf8')); }
    catch { return { skipPerms: true }; }
}

function writeChatConfig(c) {
    fs.writeFileSync(CHAT_CONFIG_PATH, JSON.stringify(c, null, 2), 'utf8');
}

function readUserSettings() {
    try { return JSON.parse(fs.readFileSync(USER_SETTINGS_PATH, 'utf8').replace(/^﻿/, '')); }
    catch { return {}; }
}

function writeUserSettings(s) {
    fs.writeFileSync(USER_SETTINGS_PATH, JSON.stringify(s, null, 2), 'utf8');
}

// ── Config endpoints ──────────────────────────────────────────────────────────

app.get('/config', (req, res) => res.json(readChatConfig()));

app.post('/config', (req, res) => {
    const cfg = readChatConfig();
    Object.assign(cfg, req.body);
    writeChatConfig(cfg);
    res.json(cfg);
});

// ── Permissions endpoints ─────────────────────────────────────────────────────

app.get('/permissions', (req, res) => {
    const s = readUserSettings();
    res.json({ allow: s.permissions?.allow || [] });
});

app.post('/permissions', (req, res) => {
    const { pattern } = req.body;
    if (!pattern) return res.status(400).json({ error: 'pattern required' });
    const s = readUserSettings();
    if (!s.permissions) s.permissions = {};
    if (!s.permissions.allow) s.permissions.allow = [];
    if (!s.permissions.allow.includes(pattern)) s.permissions.allow.push(pattern);
    writeUserSettings(s);
    res.json({ allow: s.permissions.allow });
});

app.delete('/permissions', (req, res) => {
    const { pattern } = req.body;
    const s = readUserSettings();
    if (s.permissions?.allow)
        s.permissions.allow = s.permissions.allow.filter(p => p !== pattern);
    writeUserSettings(s);
    res.json({ allow: s.permissions?.allow || [] });
});

// ── Chat endpoint ─────────────────────────────────────────────────────────────

app.post('/chat', (req, res) => {
    const { message = '', images = [], session_id, effort = 'medium', cwd = DEFAULT_CWD } = req.body;

    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');

    const send = (data) => { try { res.write(`data: ${JSON.stringify(data)}\n\n`); } catch (_) {} };

    const imgDir = path.join(cwd, '.chat_imgs');
    fs.mkdirSync(imgDir, { recursive: true });
    const tempFiles = [];
    let fullMsg = message;
    for (const img of images) {
        const ext = (img.media_type || 'image/png').split('/')[1] || 'png';
        const p = path.join(imgDir, `ci_${Date.now()}_${Math.random().toString(36).slice(2)}.${ext}`);
        fs.writeFileSync(p, Buffer.from(img.data, 'base64'));
        tempFiles.push(p);
        fullMsg = `[Image attached — read this file to view it: ${p}]\n${fullMsg}`;
    }

    if (!fullMsg.trim()) { send({ type: 'error', error: 'Empty message.' }); return res.end(); }

    const safeEffort = VALID_EFFORTS.has(effort) ? effort : 'medium';
    const cfg = readChatConfig();

    res.write(': ping\n\n');

    const flagArr = ['--print', '--output-format', 'stream-json', '--include-partial-messages',
                     '--verbose', '--effort', safeEffort];
    if (cfg.skipPerms !== false) flagArr.push('--dangerously-skip-permissions');
    if (session_id) flagArr.push('--resume', session_id);

    const proc = spawn(CLAUDE_EXE, flagArr, { cwd, stdio: ['pipe', 'pipe', 'pipe'] });
    proc.stdin.write(fullMsg, 'utf8');
    proc.stdin.end();

    let buf = '';
    const blockTypes = {};
    let newSessionId = null;
    let stderrBuf = '';
    let permSent = false;

    proc.stdout.on('data', chunk => {
        buf += chunk.toString('utf8');
        const lines = buf.split('\n');
        buf = lines.pop();
        for (const line of lines) {
            if (!line.trim()) continue;
            try { handleEvent(JSON.parse(line), send, blockTypes, id => { newSessionId = id; }); }
            catch (_) {}
        }
    });

    proc.stderr.on('data', chunk => {
        stderrBuf += chunk.toString();
        // Detect permission blocks in real-time as stderr arrives
        if (!permSent) {
            const permMatch = stderrBuf.match(/Claude requested permissions? to (\w+) to (.+?),/i);
            if (permMatch) {
                permSent = true;
                const action = permMatch[1].charAt(0).toUpperCase() + permMatch[1].slice(1);
                const target = permMatch[2].trim();
                send({ type: 'permission_blocked', action, target, pattern: `${action}(${target})` });
            }
        }
    });

    let done = false;
    res.on('close', () => { if (!done) proc.kill(); });

    proc.on('close', (code) => {
        done = true;
        for (const f of tempFiles) try { fs.unlinkSync(f); } catch (_) {}
        if (stderrBuf) { process.stderr.write(`[claude stderr]\n${stderrBuf}\n`); send({ type: 'debug_stderr', text: stderrBuf.slice(0, 1000) }); }
        if (!permSent && !newSessionId && stderrBuf) {
            send({ type: 'error', error: `claude exited (code ${code}): ${stderrBuf.trim().slice(0, 500)}` });
        }
        send({ type: 'done', session_id: newSessionId });
        res.end();
    });

    proc.on('error', err => {
        done = true;
        send({ type: 'error', error: `Could not launch claude: ${err.message}` });
        res.end();
    });
});

function handleEvent(ev, send, blockTypes, setSession) {
    switch (ev.type) {
        case 'system':
            if (ev.subtype === 'init') {
                setSession(ev.session_id);
                send({ type: 'init', model: ev.model, session_id: ev.session_id });
            }
            break;
        case 'rate_limit_event':
            send({ type: 'rate_limit', status: ev.rate_limit_info.status, resetsAt: ev.rate_limit_info.resetsAt, limitType: ev.rate_limit_info.rateLimitType });
            break;
        case 'stream_event': {
            const e = ev.event;
            switch (e.type) {
                case 'message_start':
                    send({ type: 'message_start', usage: e.message.usage }); break;
                case 'content_block_start':
                    blockTypes[e.index] = e.content_block.type;
                    if (e.content_block.type === 'thinking')      send({ type: 'thinking_start' });
                    else if (e.content_block.type === 'tool_use') send({ type: 'tool_start', name: e.content_block.name, index: e.index });
                    break;
                case 'content_block_delta':
                    if (e.delta.type === 'thinking_delta')       send({ type: 'thinking_delta', text: e.delta.thinking });
                    else if (e.delta.type === 'text_delta')       send({ type: 'text_delta', text: e.delta.text });
                    else if (e.delta.type === 'input_json_delta') send({ type: 'tool_delta', json: e.delta.partial_json, index: e.index });
                    break;
                case 'content_block_stop':
                    if (blockTypes[e.index] === 'thinking')      send({ type: 'thinking_end' });
                    else if (blockTypes[e.index] === 'tool_use') send({ type: 'tool_end', index: e.index });
                    break;
                case 'message_delta':
                    if (e.usage?.output_tokens != null) send({ type: 'usage', output_tokens: e.usage.output_tokens });
                    break;
            }
            break;
        }
        case 'result':
            send({ type: 'result', cost: ev.total_cost_usd, duration_ms: ev.duration_ms,
                   input_tokens: ev.usage?.input_tokens, output_tokens: ev.usage?.output_tokens,
                   cache_read: ev.usage?.cache_read_input_tokens });
            break;
        case 'user': {
            // Tool results come back as user events — scan for permission errors
            const content = ev.message?.content || [];
            for (const block of content) {
                if (block.type === 'tool_result') {
                    const text = Array.isArray(block.content)
                        ? block.content.map(c => c.text||'').join('')
                        : (block.content||'');
                    if (text.includes("requested permissions") || text.includes("hasn't been granted")) {
                        const m = text.match(/permissions? to (\w+) to (.+?)[,\.]/i);
                        if (m) {
                            const action = m[1].charAt(0).toUpperCase() + m[1].slice(1);
                            const target = m[2].trim();
                            send({ type: 'permission_blocked', action, target, pattern: `${action}(${target})` });
                        } else {
                            send({ type: 'permission_blocked', action: 'Tool', target: text.slice(0,120), pattern: '' });
                        }
                    }
                }
            }
            break;
        }
        default:
            send({ type: 'debug_event', raw: ev });
            break;
    }
}

const PORT = parseInt(process.env.PORT || '5001');
app.listen(PORT, () => {
    const url = `http://localhost:${PORT}`;
    console.log(`\nClaude Chat (Pro)  →  ${url}\n`);
    require('child_process').exec(`start ${url}`);
});
