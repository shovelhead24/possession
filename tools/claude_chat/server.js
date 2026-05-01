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

// Spawn claude.exe directly — avoids PATH and cmd.exe quoting issues entirely
const APPDATA = process.env.APPDATA || path.join(os.homedir(), 'AppData', 'Roaming');
const CLAUDE_EXE = path.join(APPDATA, 'npm', 'node_modules', '@anthropic-ai', 'claude-code', 'bin', 'claude.exe');

app.post('/chat', (req, res) => {
    const { message = '', images = [], session_id, effort = 'medium', cwd = DEFAULT_CWD } = req.body;

    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');

    const send = (data) => { try { res.write(`data: ${JSON.stringify(data)}\n\n`); } catch (_) {} };

    // Write images into the cwd — temp dir is outside Claude's allowed paths and gets blocked
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

    // Heartbeat — keeps the SSE connection alive and prevents premature close
    res.write(': ping\n\n');

    const flagArr = ['--print', '--output-format', 'stream-json', '--include-partial-messages',
                     '--verbose', '--effort', safeEffort];
    if (session_id) flagArr.push('--resume', session_id);
    const proc = spawn(CLAUDE_EXE, flagArr, { cwd, stdio: ['pipe', 'pipe', 'pipe'] });
    proc.stdin.write(fullMsg, 'utf8');
    proc.stdin.end();

    let buf = '';
    const blockTypes = {};
    let newSessionId = null;
    let stderrBuf = '';

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

    proc.stderr.on('data', chunk => { stderrBuf += chunk.toString(); });

    let done = false;
    res.on('close', () => {
        if (!done) proc.kill();
    });

    proc.on('close', (code) => {
        done = true;
        for (const f of tempFiles) try { fs.unlinkSync(f); } catch (_) {}
        if (stderrBuf) process.stderr.write(`[claude stderr]\n${stderrBuf}\n`);
        if (!newSessionId && stderrBuf) {
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
                    send({ type: 'message_start', usage: e.message.usage });
                    break;
                case 'content_block_start':
                    blockTypes[e.index] = e.content_block.type;
                    if (e.content_block.type === 'thinking')
                        send({ type: 'thinking_start' });
                    else if (e.content_block.type === 'tool_use')
                        send({ type: 'tool_start', name: e.content_block.name, index: e.index });
                    break;
                case 'content_block_delta':
                    if (e.delta.type === 'thinking_delta')        send({ type: 'thinking_delta', text: e.delta.thinking });
                    else if (e.delta.type === 'text_delta')        send({ type: 'text_delta', text: e.delta.text });
                    else if (e.delta.type === 'input_json_delta')  send({ type: 'tool_delta', json: e.delta.partial_json, index: e.index });
                    break;
                case 'content_block_stop':
                    if (blockTypes[e.index] === 'thinking') send({ type: 'thinking_end' });
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
    }
}

const PORT = parseInt(process.env.PORT || '5001');
app.listen(PORT, () => {
    const url = `http://localhost:${PORT}`;
    console.log(`\nClaude Chat (Pro)  →  ${url}\n`);
    require('child_process').exec(`start ${url}`);
});
