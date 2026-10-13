import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { existsSync, mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve } from 'node:path';

// jsdom cannot measure wrapping or page breaks. Exercise the shipped engine in
// a real browser without adding a browser automation dependency to the app.
const chrome = [process.env.CHROME_BIN,
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/usr/bin/chromium', '/usr/bin/chromium-browser', '/usr/bin/google-chrome',
].find(path => path && existsSync(path));
const assets = new URL('../../lib/features/training/presentation/assets/sop_editor/', import.meta.url);
const delay = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));
let server, browser, profile, socket, call;

before(async () => {
  assert.ok(chrome, 'Set CHROME_BIN to a Chromium browser to run the page-layout tests.');
  server = createServer((request, response) => {
    const file = { '/engine.js': 'sop-engine.js', '/style.css': 'sop-document.css' }[request.url];
    response.setHeader('Content-Type', `${file?.endsWith('.js') ? 'text/javascript' : file ? 'text/css' : 'text/html'}; charset=utf-8`);
    response.end(file ? readFileSync(new URL(file, assets)) :
      '<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="/style.css"></head>' +
      '<body><div id="editor"></div><script>window.messages=[];window.links=[];' +
      'window.TiptapBridge={postMessage:s=>messages.push(JSON.parse(s))};' +
      'window.TrainingSopLinks={postMessage:s=>links.push(JSON.parse(s))};</script>' +
      '<script src="/engine.js"></script></body></html>');
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  profile = mkdtempSync(resolve(tmpdir(), 'kaizen-sop-layout-'));
  browser = spawn(chrome, ['--headless', '--disable-gpu', '--no-first-run', '--remote-debugging-port=0',
    `--user-data-dir=${profile}`, 'about:blank'], { stdio: 'ignore' });
  const portFile = resolve(profile, 'DevToolsActivePort');
  for (let attempt = 0; attempt < 150 && !existsSync(portFile); attempt++) await delay(100);
  const port = readFileSync(portFile, 'utf8').split('\n')[0];
  const target = await (await fetch(`http://127.0.0.1:${port}/json/new?about:blank`, { method: 'PUT' })).json();
  socket = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise(resolve => socket.addEventListener('open', resolve, { once: true }));
  let id = 0;
  const pending = new Map();
  socket.addEventListener('message', event => {
    const message = JSON.parse(event.data);
    if (message.id) { pending.get(message.id)?.(message); pending.delete(message.id); }
  });
  call = (method, params = {}) => new Promise((resolve, reject) => {
    const next = ++id;
    const timeout = setTimeout(() => { pending.delete(next); reject(new Error(`Timed out: ${method}`)); }, 15000);
    pending.set(next, message => {
      clearTimeout(timeout);
      if (message.error) reject(new Error(JSON.stringify(message.error)));
      else resolve(message.result);
    });
    socket.send(JSON.stringify({ id: next, method, params }));
  });
});

after(async () => {
  socket?.close();
  server?.close();
  if (browser) {
    const exited = new Promise(resolve => browser.once('exit', resolve));
    browser.kill();
    await exited;
  }
  if (profile) rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
});

async function evaluate(expression) {
  const result = await call('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
  assert.equal(result.exceptionDetails, undefined, JSON.stringify(result.exceptionDetails));
  return result.result.value;
}

async function settle() {
  await evaluate('new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))');
}

async function open(content, editable = true) {
  await call('Page.navigate', { url: `http://127.0.0.1:${server.address().port}` });
  for (let attempt = 0; attempt < 100; attempt++) {
    if (await evaluate('!!window.TiptapEngine')) break;
    await delay(25);
  }
  await evaluate(`window.command=(name,payload={})=>{
    const id='layout_'+messages.length;
    TiptapEngine.handleCommand(JSON.stringify({type:'command',id,name,payload}));
    const response=messages.find(message=>message.id===id);
    if(!response?.success)throw new Error(JSON.stringify(response));
    return response.payload;
  };command('init',{content:${JSON.stringify(content)},editable:${editable}});
  TrainingSopDocument.configure({width:390,textScale:1});`);
  await settle();
}

// Verify actual rendered text fragments, including fragments inside a paragraph
// spanning several pages. Checking block rectangles alone would miss clipping.
async function expectInsidePages() {
  const result = await evaluate(`(() => {
    const root=document.querySelector('#editor'), origin=root.getBoundingClientRect().top;
    const mm=96/25.4, stride=297*mm+24, invalid=[];
    const iterator=document.createNodeIterator(document.querySelector('.tiptap'),NodeFilter.SHOW_TEXT);
    let node;
    while(node=iterator.nextNode()) {
      if(!node.textContent.trim())continue;
      const range=document.createRange();range.selectNodeContents(node);
      for(const rect of range.getClientRects()) {
        const page=Math.max(0,Math.floor((rect.top-origin)/stride));
        if(rect.top<origin+page*stride+4.5*mm-0.75 || rect.bottom>origin+page*stride+279*mm+0.75)
          invalid.push({text:node.textContent.slice(0,40),top:rect.top,bottom:rect.bottom,page});
      }
    }
    return {invalid,pages:Number(root.dataset.sopPageCount),sheets:[...document.querySelectorAll('.sop-page')]
      .map(page=>({width:page.getBoundingClientRect().width,height:page.getBoundingClientRect().height,top:page.getBoundingClientRect().top})),
      html:command('getContent',{format:'html'}).content};
  })()`);
  assert.deepEqual(result.invalid, [], 'Text must not enter the page margins or gaps');
  assert.equal(result.sheets.length, result.pages);
  result.sheets.forEach((sheet, index) => {
    assert.ok(Math.abs(sheet.width - 210 * 96 / 25.4) < 0.1);
    assert.ok(Math.abs(sheet.height - 297 * 96 / 25.4) < 0.1);
    if (index) assert.ok(Math.abs(sheet.top - result.sheets[index - 1].top - sheet.height - 24) < 0.1);
  });
  assert.doesNotMatch(result.html, /sop-page|ProseMirror-widget|data-sop-page-count/);
  return result;
}

test('long styled paragraphs paginate between lines and reflow without changing saved HTML', async () => {
  await open('<h1 style="color:#087f5b">Procedure</h1><p><strong>' +
    'Long formatted instruction. '.repeat(800) + '</strong><br><br>Final line.</p><p></p><p>End.</p>');
  const original = await expectInsidePages();
  assert.ok(original.pages > 2);
  assert.match(original.html, /<br><br>/);
  assert.match(original.html, /<p><\/p>/);
  const events = await evaluate("messages.filter(m=>m.name==='stateChanged').length");
  await evaluate('TrainingSopDocument.configure({width:320,textScale:1.5})');
  await settle();
  const enlarged = await expectInsidePages();
  assert.ok(enlarged.pages > original.pages);
  assert.equal(enlarged.html, original.html);
  assert.equal(await evaluate("messages.filter(m=>m.name==='stateChanged').length"), events,
    'Layout must not trigger content autosave');
  assert.equal(await evaluate('getComputedStyle(document.querySelector("h1")).color'), 'rgb(8, 127, 91)');
  await evaluate("command('setContent',{content:'<p>Short procedure.</p>'})");
  await settle();
  assert.equal((await expectInsidePages()).pages, 1, 'Removing text must remove unused pages');
});

test('tables paginate between rows, keep merged cells, and remain editable after reflow', async () => {
  const rows = Array.from({ length: 40 }, (_, index) => index % 2 === 0 ?
    `<tr><td rowspan="2"><p>Group ${index / 2}</p></td><td><p>${'Detailed instruction. '.repeat(8)}</p></td></tr>` :
    `<tr><td><p><a href="https://example.com">Review ${index}</a></p></td></tr>`).join('');
  await open('<h2>Checks</h2><table><tbody>' + rows + '</tbody></table><p>End.</p>');
  const original = await expectInsidePages();
  assert.ok(original.pages > 2);
  assert.equal((original.html.match(/rowspan="2"/g) ?? []).length, 20);
  assert.equal(await evaluate(`(() => {
    const rows=[...document.querySelectorAll('.tiptap tr:not(.sop-page-spacer)')];
    const root=document.querySelector('#editor').getBoundingClientRect().top,stride=297*96/25.4+24;
    return rows.filter((row,i)=>i%2===0 && Math.floor((row.getBoundingClientRect().top-root)/stride)!==
      Math.floor((rows[i+1].getBoundingClientRect().bottom-root)/stride)).length;
  })()`), 0, 'A merged row group that fits must stay on one page');
  await evaluate(`(() => {
    let position;__tiptapEngineInstance.editor.state.doc.descendants((node,pos)=>{
      if(position===undefined&&node.isText&&node.text.startsWith('Detailed'))position=pos;
    });command('insertText',{text:'Updated ',range:{from:position,to:position}});
  })()`);
  await settle();
  const edited = await expectInsidePages();
  assert.match(edited.html, /Updated Detailed/);
  assert.match(edited.html, /href="https:\/\/example.com"/);
  await evaluate('__tiptapEngineInstance.editor.commands.undo()');
  await settle();
  assert.equal((await expectInsidePages()).html, original.html, 'Undo must undo the edit, without page-layout history');
});

test('template formatting, nested lists, images and read-only documents use the same pages', async () => {
  const image = 'data:image/svg+xml,' + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="600" height="2400"><rect width="600" height="2400" fill="purple"/></svg>');
  const content = '<p data-sop-role="eyebrow">STANDARD OPERATING PROCEDURE</p>' +
    '<h1 data-sop-template="reference-v1" data-sop-role="title">Dental Terminologies</h1>' +
    '<p data-sop-role="overview">An introduction.</p><h2>Procedure</h2><div class="instructions"><ol>' +
    Array.from({ length: 55 }, (_, index) => `<li><p>Step ${index + 1}: ${'Follow this instruction. '.repeat(4)}</p></li>`).join('') +
    `</ol><p><img src="${image}" width="600" height="2400" alt="Diagram"></p></div><p>End.</p>`;
  await open(content, false);
  await evaluate('Promise.all([...document.images].map(image=>image.decode().catch(()=>{})))');
  await settle();
  const result = await expectInsidePages();
  assert.ok(result.pages > 2);
  assert.match(result.html, /data-sop-template="reference-v1"/);
  assert.equal(await evaluate('getComputedStyle(document.querySelector("h1")).color'), 'rgb(255, 255, 255)');
  assert.equal(await evaluate('getComputedStyle(document.querySelector("h2")).color'), 'rgb(96, 75, 140)');
  assert.equal(await evaluate('__tiptapEngineInstance.editor.isEditable'), false);
  assert.equal(await evaluate('document.querySelectorAll(".tiptap li").length'), 55);
  const bounds = await evaluate('(()=>{const image=document.querySelector(".tiptap img");return {height:image.getBoundingClientRect().height,width:image.getBoundingClientRect().width};})()');
  assert.ok(bounds.height <= 267 * 96 / 25.4 + 0.1, 'Oversized images must fit inside a page');
  assert.equal(await evaluate(`(() => {
    const rect=document.querySelector('.tiptap img').getBoundingClientRect();
    const root=document.querySelector('#editor').getBoundingClientRect().top,mm=96/25.4,stride=297*mm+24;
    const page=Math.floor((rect.top-root)/stride);
    return rect.top>=root+page*stride+4.5*mm-.5 && rect.bottom<=root+page*stride+279*mm+.5;
  })()`), true);
  for (let repeat = 0; repeat < 3; repeat++) {
    await evaluate(`command('setContent',{content:${JSON.stringify(result.html)}})`);
    await settle();
    const reloaded = await expectInsidePages();
    assert.equal(reloaded.pages, result.pages);
    assert.equal(reloaded.html, result.html);
  }
});

test('oversized table cells flow across pages and edits retain their selection', async () => {
  await open('<h2>Long instructions</h2><table><tbody><tr><td><p>' +
    'Detailed content in the first cell. '.repeat(250) + '</p></td><td><p>' +
    'Other instructions. '.repeat(120) + '</p></td></tr><tr><td><p>Final row</p></td>' +
    '<td><p>Complete</p></td></tr></tbody></table><p>After table.</p>');
  const original = await expectInsidePages();
  assert.ok(original.pages > 2);
  const position = await evaluate(`(() => {
    let position;__tiptapEngineInstance.editor.state.doc.descendants((node,pos)=>{
      if(node.isText&&node.text==='After table.')position=pos;
    });command('insertText',{text:'Updated ',range:{from:position,to:position}});
    return __tiptapEngineInstance.editor.state.selection.from;
  })()`);
  await settle();
  assert.match((await expectInsidePages()).html, /Updated After table/);
  assert.equal(await evaluate('__tiptapEngineInstance.editor.state.selection.from'), position);
});

test('a heading stays with the start of a long paragraph and layout waits for composition', async () => {
  await open('<p style="height:950px">Preface</p><h2>Procedure</h2><h3>Instructions</h3><p>' +
    'Continue with these instructions. '.repeat(400) + '</p>');
  await expectInsidePages();
  assert.equal(await evaluate(`(() => {
    const editor=__tiptapEngineInstance.editor;
    let paragraph;editor.state.doc.descendants((node,pos)=>{
      if(node.isTextblock&&node.textContent.startsWith('Continue'))paragraph=pos+1;
    });
    const origin=document.querySelector('#editor').getBoundingClientRect().top,stride=297*96/25.4+24;
    return Math.floor((document.querySelector('h2').getBoundingClientRect().top-origin)/stride)===
      Math.floor((editor.view.coordsAtPos(paragraph).top-origin)/stride);
  })()`), true);
  const pages = await evaluate('document.querySelector("#editor").dataset.sopPageCount');
  await evaluate(`__tiptapEngineInstance.editor.view.input.composing=true;
    TrainingSopDocument.configure({width:390,textScale:1.6});`);
  await settle();
  assert.equal(await evaluate('document.querySelector("#editor").dataset.sopPageCount'), pages);
  await evaluate(`__tiptapEngineInstance.editor.view.dom.dispatchEvent(new CompositionEvent('compositionend'));
    new Promise(resolve=>setTimeout(()=>{__tiptapEngineInstance.editor.view.input.composing=false;resolve();},30))`);
  await delay(80);
  await settle();
  const result = await expectInsidePages();
  assert.ok(result.pages > Number(pages));
});

test('touching a later page places the native caret there and typing edits that position', async () => {
  await open(Array.from({ length: 70 }, (_, index) =>
    `<p><strong>Step ${index + 1}</strong>: Follow these instructions carefully.</p>`).join(''));
  await call('Emulation.setTouchEmulationEnabled', { enabled: true });
  try {
    const point = await evaluate(`(() => {
      const editor=__tiptapEngineInstance.editor,target=editor.view.dom.querySelectorAll('p')[40];
      target.scrollIntoView({block:'center'});
      const rect=target.getBoundingClientRect(),x=rect.left+110,y=rect.top+8;
      return {x,y,pos:editor.view.posAtCoords({left:x,top:y}).pos,scrollY,scale:visualViewport.scale,
        html:editor.getHTML()};
    })()`);
    assert.ok(point.scrollY > 1000);
    await call('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: point.x, y: point.y }] });
    await call('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    await settle();
    const focused = await evaluate(`({focused:__tiptapEngineInstance.editor.view.hasFocus(),
      pos:__tiptapEngineInstance.editor.state.selection.from,scrollY,scale:visualViewport.scale,
      html:__tiptapEngineInstance.editor.getHTML()})`);
    assert.equal(focused.focused, true);
    assert.equal(focused.pos, point.pos);
    assert.equal(focused.scale, point.scale);
    assert.ok(Math.abs(focused.scrollY - point.scrollY) < 1, 'Focus must not jump to the first page');
    assert.equal(focused.html, point.html);
    await call('Input.insertText', { text: 'EDITED ' });
    await settle();
    const edited = await evaluate('__tiptapEngineInstance.editor.state.doc.textBetween(0,__tiptapEngineInstance.editor.state.doc.content.size,"\\n")');
    assert.match(edited.split('\n')[40], /EDITED /);
    await expectInsidePages();
  } finally { await call('Emulation.setTouchEmulationEnabled', { enabled: false }); }
});

test('native word selection and cursor moves publish the matching toolbar state', async () => {
  await open('<p>Plain <strong>formatted</strong> end.</p>');
  assert.equal(await evaluate('getComputedStyle(document.documentElement).touchAction'), 'manipulation');
  const initial = await evaluate('({html:command("getContent",{format:"html"}).content,scale:visualViewport.scale})');
  const point = await evaluate(`(() => {
    const rect=document.querySelector('strong').getBoundingClientRect();
    return {x:rect.left+rect.width/2,y:rect.top+rect.height/2};
  })()`);
  await call('Input.dispatchMouseEvent', { type: 'mousePressed', button: 'left', clickCount: 2, ...point });
  await call('Input.dispatchMouseEvent', { type: 'mouseReleased', button: 'left', clickCount: 2, ...point });
  await settle();
  assert.equal(await evaluate('getSelection().toString()'), 'formatted');
  assert.equal(await evaluate('messages.filter(m=>m.name==="stateChanged").at(-1).payload.commandStates.toggleBold.isActive'), true);
  const plain = await evaluate(`(() => {
    const range=document.createRange();range.selectNode(document.querySelector('p').firstChild);
    const rect=range.getBoundingClientRect();return {x:rect.left+5,y:rect.top+rect.height/2};
  })()`);
  await call('Input.dispatchMouseEvent', { type: 'mousePressed', button: 'left', clickCount: 1, ...plain });
  await call('Input.dispatchMouseEvent', { type: 'mouseReleased', button: 'left', clickCount: 1, ...plain });
  await settle();
  assert.equal(await evaluate('messages.filter(m=>m.name==="stateChanged").at(-1).payload.commandStates.toggleBold.isActive'), false);
  assert.equal(await evaluate('command("getContent",{format:"html"}).content'), initial.html);
  assert.equal(await evaluate('visualViewport.scale'), initial.scale);
});

test('a mobile tap replaces selected text with the tapped caret and typing preserves the previous text', async () => {
  await call('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 1, mobile: true });
  await call('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 2 });
  try {
    await open('<p>Alpha beta</p><p>Second line remains.</p>');
    const original = await evaluate('({scale:visualViewport.scale,html:command("getContent",{format:"html"}).content})');
    const point = paragraph => evaluate(`(() => {
      const view=__tiptapEngineInstance.editor.view,rect=document.querySelectorAll('p')[${paragraph}].getBoundingClientRect();
      const left=rect.left+15,top=rect.top+rect.height/2;
      return {x:left,y:top,
        pos:view.posAtCoords({left,top}).pos};
    })()`);
    const tap = async target => {
      await call('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{x:target.x,y:target.y}] });
      await call('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
      await settle();
    };
    const first = await point(0);
    await tap(first);
    await delay(80);
    await tap(first);
    assert.equal(await evaluate('getSelection().toString()'), 'Alpha');
    assert.equal(await evaluate('links.filter(message=>typeof message.hasSelection==="boolean").at(-1)?.hasSelection'), true);
    const second = await point(1);
    await tap(second);
    const caret = await evaluate('({from:__tiptapEngineInstance.editor.state.selection.from,to:__tiptapEngineInstance.editor.state.selection.to,collapsed:getSelection().isCollapsed})');
    assert.deepEqual(caret, {from:second.pos,to:second.pos,collapsed:true});
    assert.equal(await evaluate('links.filter(message=>typeof message.hasSelection==="boolean").at(-1)?.hasSelection'), false);
    assert.equal(await evaluate('visualViewport.scale'), original.scale);
    assert.equal(await evaluate('command("getContent",{format:"html"}).content'), original.html);
    await call('Input.insertText', {text:'CHECK '});
    await settle();
    assert.equal(await evaluate('document.querySelectorAll("p")[0].textContent'), 'Alpha beta');
    assert.match(await evaluate('document.querySelectorAll("p")[1].textContent'), /CHECK /);
  } finally {
    await call('Emulation.setTouchEmulationEnabled', { enabled: false });
    await call('Emulation.clearDeviceMetricsOverride');
  }
});

for (const editable of [true, false]) test(`mobile double taps preserve scale and pinches zoom in and out in ${editable ? 'editor' : 'reader'} mode`, async () => {
  await call('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 1, mobile: true });
  await call('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 2 });
  try {
    await open(Array.from({ length: 30 }, (_, index) => `<p>Step ${index + 1}: Read this instruction.</p>`).join(''), editable);
    const initial = await evaluate('({scale:visualViewport.scale,html:command("getContent",{format:"html"}).content})');
    const doubleTap = async () => {
      const point = await evaluate(`(() => {
        const rect=document.querySelector('p').getBoundingClientRect();
        return {x:rect.left+40,y:rect.top+rect.height/2};
      })()`);
      for (let tap = 0; tap < 2; tap++) {
        await call('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [point] });
        await call('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
        if (tap === 0) await delay(80);
      }
      await settle();
    };
    await doubleTap();
    const tapped = await evaluate('visualViewport.scale');
    assert.ok(Math.abs(tapped - initial.scale) < 0.01, `Double tap must preserve scale: ${initial.scale} -> ${tapped}`);
    assert.match(await evaluate('document.querySelector("meta[name=viewport]").content'), /maximum-scale=4,user-scalable=yes/);
    assert.equal(await evaluate('command("getContent",{format:"html"}).content'), initial.html);
    await call('Input.synthesizePinchGesture', { x: 195, y: 200, scaleFactor: 2, gestureSourceType: 'touch' });
    await settle();
    const pinched = await evaluate('({scale:visualViewport.scale,viewport:document.querySelector("meta[name=viewport]").content})');
    assert.ok(pinched.scale > initial.scale + 0.05, `Native pinch zoom remains enabled: ${JSON.stringify(pinched)}`);
    assert.equal(await evaluate('links.filter(message=>typeof message.zoomed==="boolean").at(-1)?.zoomed'), true);
    await doubleTap();
    const stillZoomed = await evaluate('visualViewport.scale');
    assert.ok(Math.abs(stillZoomed - pinched.scale) < 0.01, `Double tap must preserve zoomed scale: ${pinched.scale} -> ${stillZoomed}`);
    await call('Input.synthesizePinchGesture', { x: 195, y: 200, scaleFactor: 0.5, gestureSourceType: 'touch' });
    await settle();
    const restored = await evaluate('visualViewport.scale');
    assert.ok(Math.abs(restored - initial.scale) < 0.01, `Pinch out must restore page-fit size: ${pinched.scale} -> ${restored}`);
    assert.equal(await evaluate('links.filter(message=>typeof message.zoomed==="boolean").at(-1)?.zoomed'), false);
    assert.equal(await evaluate('command("getContent",{format:"html"}).content'), initial.html);
  } finally {
    await call('Emulation.setTouchEmulationEnabled', { enabled: false });
    await call('Emulation.clearDeviceMetricsOverride');
  }
});
