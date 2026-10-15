import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { JSDOM } from 'jsdom';

const assets = new URL('../../lib/features/training/presentation/assets/sop_editor/', import.meta.url);
const engineJs = readFileSync(new URL('sop-engine.js', assets), 'utf8');
const css = readFileSync(new URL('sop-document.css', assets), 'utf8');
const html = '<h2 style="text-align:center">Procedure</h2>' +
  '<p>First<br><br>Second</p><p></p>' +
  '<table style="width:100%;border:2px solid purple"><tbody>' +
  '<tr><th colspan="2" style="background-color:rgb(220, 200, 240)"><p>Checks</p></th></tr>' +
  '<tr><td rowspan="2"><p>Safety</p></td><td><p><a href="https://example.com/sop" title="Guide">Guide</a></p></td></tr>' +
  '<tr><td><p><span style="color:rgb(180, 20, 30);font-size:18px">Inspection</span></p></td></tr>' +
  '</tbody></table><p><img src="data:image/png;base64,AA==" width="200" alt="Diagram"></p>';

// The API stores this template as semantic markers rather than inline colours.
const referenceSop = '<p data-sop-role="eyebrow"><strong>STANDARD OPERATING PROCEDURE</strong></p>' +
  '<h1 data-sop-template="reference-v1" data-sop-role="title"><strong>Dental Terminologies Standard Operating Procedure</strong></h1>' +
  '<p data-sop-role="overview">An overview of dental terminology.</p>' +
  '<h2><strong>Purpose</strong></h2><p>Establish consistent terminology.</p>' +
  '<h2><strong>Scope</strong></h2><p>All dental staff.</p>' +
  '<ul data-sop-role="cards"><li><p>Anatomy</p></li></ul>' +
  '<ol data-sop-role="steps"><li><p>Identify the tooth.</p></li></ol>' +
  '<table data-sop-role="approval"><tbody><tr><th><p>Approved by</p></th></tr>' +
  '<tr><td><p>Clinical lead</p></td></tr></tbody></table>';

function create(content = html, editable = true, iosAlias = false) {
  const dom = new JSDOM('<html><head><meta name="viewport"></head><body><div id="editor"></div></body></html>', {
    runScripts: 'outside-only', pretendToBeVisual: true,
  });
  const messages = [];
  const links = [];
  dom.window.TiptapBridge = { postMessage: value => messages.push(JSON.parse(value)) };
  if (iosAlias) dom.window.webkit = { messageHandlers: { TiptapEngine: dom.window.TiptapBridge } };
  dom.window.TrainingSopLinks = { postMessage: value => links.push(JSON.parse(value)) };
  dom.window.eval(engineJs);
  let index = 0;
  const command = (name, payload = {}) => {
    const id = `test_${index++}`;
    dom.window.TiptapEngine.handleCommand(JSON.stringify({ type: 'command', id, name, payload }));
    const response = messages.find(value => value.id === id);
    assert.ok(response, `Missing response: ${name}`);
    assert.equal(response.success, true, JSON.stringify(response));
    return response.payload;
  };
  dom.window.TrainingSopDocument.installStyles(css, '');
  command('init', { content, editable });
  dom.window.TrainingSopDocument.configure({ width: 320, textScale: 1 });
  return { dom, command, messages, links, close() { command('destroy'); dom.window.close(); } };
}

function canonicalHtml(document, html) {
  const template = document.createElement('template');
  template.innerHTML = html;
  template.content.querySelectorAll('*').forEach(element => {
    const attributes = Array.from(element.attributes, attribute => [attribute.name, attribute.value])
      .sort(([a], [b]) => a.localeCompare(b));
    attributes.forEach(([name]) => element.removeAttribute(name));
    attributes.forEach(([name, value]) => element.setAttribute(name, value));
  });
  return template.innerHTML;
}

test('tables, merged cells, hyperlinks, styles, and images survive repeated HTML reloads', () => {
  const e = create();
  try {
    const first = e.command('getContent', { format: 'html' }).content;
    assert.match(first, /<table/);
    assert.match(first, /colspan="2"/);
    assert.match(first, /rowspan="2"/);
    assert.match(first, /href="https:\/\/example.com\/sop"/);
    assert.match(first, /text-align: center/);
    assert.match(first, /font-size: 18px/);
    assert.match(first, /data:image\/png;base64,AA==/);
    assert.match(first, /First<br><br>Second/);
    assert.match(first, /<p><\/p>/);
    for (let repeat = 0; repeat < 4; repeat++) {
      e.command('setContent', { content: first });
      assert.equal(e.command('getContent', { format: 'html' }).content, first);
    }
    const rendered = e.dom.window.document.querySelector('.tiptap');
    assert.equal(rendered.querySelectorAll('table').length, 1);
    assert.equal(rendered.querySelectorAll('tr').length, 3);
    assert.equal(rendered.querySelector('th').colSpan, 2);
    assert.equal(rendered.querySelector('td').rowSpan, 2);
  } finally { e.close(); }
});

test('editing text inside a table preserves its structure and neighbouring links', () => {
  const e = create();
  try {
    let position;
    e.dom.window.__tiptapEngineInstance.editor.state.doc.descendants((node, pos) => {
      if (node.isText && node.text === 'Inspection') position = pos;
    });
    const initialEvents = e.messages.filter(message => message.name === 'stateChanged').length;
    e.command('insertText', { text: 'Updated ', range: { from: position, to: position } });
    assert.ok(e.messages.filter(message => message.name === 'stateChanged').length > initialEvents,
      'An edit must emit its changed document for Flutter autosave');
    const saved = e.command('getContent', { format: 'html' }).content;
    assert.match(saved, /Updated /);
    assert.match(saved, /<table/);
    assert.match(saved, /rowspan="2"/);
    assert.match(saved, /href="https:\/\/example.com\/sop"/);
  } finally { e.close(); }
});

test('A4 dimensions, page-fit viewport, zoom, and source stylesheet are applied', () => {
  const e = create();
  try {
    e.dom.window.TrainingSopDocument.installStyles(css, 'th { color: rgb(10, 20, 30); }');
    e.dom.window.TrainingSopDocument.configure({ width: 320, textScale: 1.4 });
    const document = e.dom.window.document;
    const paper = document.getElementById('editor');
    assert.equal(e.dom.window.getComputedStyle(paper).width, '210mm');
    assert.equal(e.dom.window.getComputedStyle(paper.querySelector('.sop-page')).height, '297mm');
    assert.match(document.querySelector('meta[name="viewport"]').content, /maximum-scale=4,user-scalable=yes/);
    assert.equal(document.documentElement.style.getPropertyValue('--sop-text-scale'), '1.4');
    assert.equal(e.dom.window.getComputedStyle(document.querySelector('th')).color, 'rgb(10, 20, 30)');
  } finally { e.close(); }
});

test('link taps send the URL to the app and prevent replacing the editor', () => {
  const e = create(html, false);
  try {
    const link = e.dom.window.document.querySelector('.tiptap a');
    const click = new e.dom.window.MouseEvent('click', { bubbles: true, cancelable: true });
    link.dispatchEvent(click);
    assert.equal(click.defaultPrevented, true);
    assert.deepEqual(e.links, [{ href: 'https://example.com/sop' }]);
    assert.equal(e.dom.window.__tiptapEngineInstance.editor.isEditable, false);
    assert.equal(e.dom.window.location.href, 'about:blank');
  } finally { e.close(); }
});

test('a document with styled spans, lists, quotes and hard breaks keeps its formatting', () => {
  const content = '<div class="procedure"><h1>Title</h1><p><strong>Bold</strong> <em>Italic</em>' +
    ' <u>Underline</u><br><br>Spacing</p><p></p><ul><li><p>List</p></li></ul>' +
    '<blockquote><p>Quote</p></blockquote><p><mark>Highlight</mark><sup>2</sup><sub>n</sub></p></div>';
  const e = create(content);
  try {
    const saved = e.command('getContent', { format: 'html' }).content;
    for (const fragment of ['class="procedure"', '<strong>Bold</strong>', '<em>Italic</em>',
      '<u>Underline</u>', '<br><br>', '<p></p>', '<ul>', '<blockquote>', '<mark>', '<sup>', '<sub>']) {
      assert.ok(saved.includes(fragment), fragment);
    }
  } finally { e.close(); }
});

test('reference SOP template markers and colours survive editing and repeated reloads', () => {
  const e = create(referenceSop);
  try {
    const document = e.dom.window.document;
    const style = selector => e.dom.window.getComputedStyle(document.querySelector(selector));
    const expectTemplate = () => {
      assert.equal(document.querySelector('h1').dataset.sopTemplate, 'reference-v1');
      assert.equal(style('[data-sop-role="eyebrow"]').backgroundColor, 'rgb(96, 75, 140)');
      assert.equal(style('h1').color, 'rgb(255, 255, 255)');
      assert.equal(style('[data-sop-role="overview"]').backgroundColor, 'rgb(96, 75, 140)');
      assert.equal(style('h2').color, 'rgb(96, 75, 140)');
      const serialized = e.command('getContent', { format: 'html' }).content;
      assert.equal((serialized.match(/data-sop-role=/g) ?? []).length, 6);
    };
    expectTemplate();
    let position;
    e.dom.window.__tiptapEngineInstance.editor.state.doc.descendants((node, pos) => {
      if (node.isText && node.text === 'Establish consistent terminology.') position = pos;
    });
    e.command('insertText', { text: 'Updated: ', range: { from: position, to: position } });
    const saved = e.command('getContent', { format: 'html' }).content;
    assert.match(saved, /Updated: Establish consistent terminology/);
    for (let repeat = 0; repeat < 3; repeat++) {
      e.command('setContent', { content: saved });
      expectTemplate();
      assert.equal(canonicalHtml(document, e.command('getContent', { format: 'html' }).content),
        canonicalHtml(document, saved));
    }
  } finally { e.close(); }
});

test('ordinary SOPs keep their own colours without adopting the reference template', () => {
  const e = create('<h1 style="color:#087f5b">Safety procedure</h1><h2>Scope</h2>' +
    '<p data-sop-role="overview">A document without a template marker.</p>');
  try {
    const document = e.dom.window.document;
    const style = element => e.dom.window.getComputedStyle(element);
    assert.equal(style(document.querySelector('h1')).color, 'rgb(8, 127, 91)');
    assert.equal(style(document.querySelector('h2')).color, 'rgb(21, 19, 26)');
    assert.equal(style(document.querySelector('p')).backgroundColor, 'rgba(0, 0, 0, 0)');
  } finally { e.close(); }
});

test('editing and command replies use the registered Flutter channel after the iOS alias disappears', () => {
  const e = create('<p>Alpha beta</p>', true, true);
  try {
    e.dom.window.webkit.messageHandlers = {};
    e.command('insertText', { text: 'Updated ', range: { from: 1, to: 1 } });
    assert.match(e.command('getContent', { format: 'html' }).content, /Updated Alpha beta/);
    assert.ok(e.messages.some(message => message.name === 'stateChanged' &&
      JSON.stringify(message.payload.doc).includes('Updated Alpha beta')));
  } finally { e.close(); }
});

test('the first touch focuses without scrolling and retains the tapped caret after toolbar updates', async () => {
  const e = create('<p>Alpha beta</p>');
  try {
    const editor = e.dom.window.__tiptapEngineInstance.editor;
    const view = editor.view;
    const options = [];
    const focus = view.dom.focus.bind(view.dom);
    view.dom.focus = option => { options.push(option); focus(option); };
    view.posAtCoords = coordinates => {
      assert.equal(coordinates.left, 20);
      assert.equal(coordinates.top, 30);
      return { pos: 7, inside: 0 };
    };
    const target = view.dom.querySelector('p');
    const touch = { screenX: 20, screenY: 30, clientX: 20, clientY: 30 };
    const dispatch = (type, touches) => {
      const event = new e.dom.window.Event(type, { bubbles: true, cancelable: true });
      Object.defineProperties(event, { touches: { value: touches }, changedTouches: { value: [touch] } });
      target.dispatchEvent(event);
      return event;
    };
    dispatch('touchstart', [touch]);
    assert.equal(dispatch('touchend', []).defaultPrevented, true);
    assert.equal(editor.state.selection.from, 7);
    assert.equal(view.hasFocus(), true);
    assert.equal(options[0].preventScroll, true);
    e.command('getState');
    await new Promise(resolve => e.dom.window.requestAnimationFrame(() => e.dom.window.requestAnimationFrame(resolve)));
    assert.equal(view.hasFocus(), true, 'A canExec blur probe must not blur the native editor');
    assert.equal(e.command('getContent', { format: 'html' }).content, '<p>Alpha beta</p>');
    assert.equal(e.dom.window.getSelection().anchorNode.textContent, 'Alpha beta');
    assert.equal(e.dom.window.getSelection().anchorOffset, 6);
    e.command('blur');
    await new Promise(resolve => e.dom.window.requestAnimationFrame(resolve));
    assert.equal(view.hasFocus(), false, 'An explicit blur must still dismiss editing');
  } finally { e.close(); }
});

test('later editing taps place the caret without native focus zoom and leave selection drags alone', () => {
  const e = create('<p>Alpha beta gamma</p>');
  try {
    const view = e.dom.window.__tiptapEngineInstance.editor.view;
    let now = 0, position = 3;
    e.dom.window.Date.now = () => now;
    view.posAtCoords = () => ({ pos: position, inside: 0 });
    const options = [];
    const focus = view.dom.focus.bind(view.dom);
    // Browsers read the getter used by ProseMirror's preventScroll detection;
    // jsdom's focus implementation does not inspect focus options itself.
    view.dom.focus = option => { options.push(option?.preventScroll); focus(option); };
    const touch = { screenX: 20, screenY: 30, clientX: 20, clientY: 30 };
    const dispatch = (type, touches, changed = touch) => {
      const event = new e.dom.window.Event(type, { bubbles: true, cancelable: true });
      Object.defineProperties(event, { touches: { value: touches }, changedTouches: { value: [changed] } });
      view.dom.querySelector('p').dispatchEvent(event);
      return event;
    };
    for (const caret of [3, 8, 13]) {
      now += 600;
      position = caret;
      dispatch('touchstart', [touch]);
      assert.equal(dispatch('touchend', []).defaultPrevented, true, 'Every short tap suppresses browser focus');
      assert.equal(view.state.selection.from, caret);
      assert.equal(view.hasFocus(), true);
    }
    assert.ok(options.every(preventScroll => preventScroll), 'Focus must never request scroll or zoom');

    now += 600;
    dispatch('touchstart', [touch]);
    dispatch('touchmove', [{ ...touch, screenX: 80 }]);
    assert.equal(dispatch('touchend', []).defaultPrevented, false);
    dispatch('touchstart', [touch]);
    now += 600;
    assert.equal(dispatch('touchend', []).defaultPrevented, false, 'Long presses retain native handling');
    dispatch('touchstart', [touch, { ...touch, screenX: 80 }]);
    assert.equal(dispatch('touchend', []).defaultPrevented, false, 'Pinches retain native handling');

    e.dom.window.__tiptapEngineInstance.editor.commands.setTextSelection({ from: 1, to: 6 });
    dispatch('touchstart', [touch]);
    dispatch('touchmove', [{ ...touch, screenX: 80 }]);
    assert.equal(dispatch('touchend', []).defaultPrevented, false, 'Selected text handles retain native handling');
    assert.equal(view.state.doc.textBetween(view.state.selection.from, view.state.selection.to), 'Alpha');
    now += 600;
    position = 15;
    dispatch('touchstart', [touch]);
    assert.equal(dispatch('touchend', []).defaultPrevented, true, 'A tap replaces the selected range');
    assert.equal(view.state.selection.empty, true);
    assert.equal(view.state.selection.from, 15);
    assert.equal(e.dom.window.getSelection().isCollapsed, true);
    assert.equal(e.command('getContent', { format: 'html' }).content, '<p>Alpha beta gamma</p>');
  } finally { e.close(); }
});

test('rapid taps on different words move the caret and small handle drags keep their selection', () => {
  const e = create('<p>Alpha beta gamma</p>');
  try {
    const editor = e.dom.window.__tiptapEngineInstance.editor;
    let now = 0, position = 3;
    e.dom.window.Date.now = () => now;
    editor.view.posAtCoords = () => ({ pos: position, inside: 0 });
    const touch = { screenX: 20, screenY: 30, clientX: 20, clientY: 30 };
    const dispatch = (type, touches) => {
      const event = new e.dom.window.Event(type, { bubbles: true, cancelable: true });
      Object.defineProperties(event, { touches: { value: touches }, changedTouches: { value: [touch] } });
      editor.view.dom.querySelector('p').dispatchEvent(event);
      return event;
    };
    for (const caret of [3, 8, 13]) {
      position = caret;
      dispatch('touchstart', [touch]);
      assert.equal(dispatch('touchend', []).defaultPrevented, true);
      assert.equal(editor.state.selection.empty, true);
      assert.equal(editor.state.selection.from, caret);
      now += 80;
    }
    editor.commands.setTextSelection({ from: 1, to: 6 });
    editor.view.focus();
    dispatch('touchstart', [touch]);
    dispatch('touchmove', [{ ...touch, screenX: 24 }]);
    assert.equal(dispatch('touchend', []).defaultPrevented, true, 'Finger jitter remains a normal tap');
    assert.equal(editor.state.selection.empty, true);
    assert.equal(editor.state.selection.from, position);

    editor.commands.setTextSelection({ from: 1, to: 6 });
    editor.view.focus();
    dispatch('touchstart', [touch]);
    dispatch('touchmove', [{ ...touch, screenX: 22 }]);
    editor.commands.setTextSelection({ from: 1, to: 8 });
    editor.view.focus();
    assert.equal(dispatch('touchend', []).defaultPrevented, false, 'A range extended by a handle is preserved');
    assert.equal(editor.state.selection.to, 8);
    editor.commands.setTextSelection({ from: 1, to: 6 });
    editor.view.focus();
    dispatch('touchstart', [touch]);
    dispatch('touchmove', [{ ...touch, screenX: 22 }]);
    const text = editor.view.dom.querySelector('p').firstChild;
    e.dom.window.getSelection().setBaseAndExtent(text, 0, text, 7);
    assert.equal(editor.state.selection.to, 6, 'The engine has not received the native handle update yet');
    assert.equal(dispatch('touchend', []).defaultPrevented, false);
    assert.equal(e.dom.window.getSelection().toString(), 'Alpha b', 'Native handle changes must survive before the engine catches up');
    assert.equal(e.command('getContent', { format: 'html' }).content, '<p>Alpha beta gamma</p>');
  } finally { e.close(); }
});

for (const editable of [true, false]) test(`selection changes reserve drags only for SOP text ranges in ${editable ? 'editor' : 'reader'} mode`, () => {
  const e = create('<p>Alpha beta</p>', editable);
  try {
    const document = e.dom.window.document;
    const selection = document.getSelection();
    const text = document.querySelector('p').firstChild;
    const publish = () => document.dispatchEvent(new e.dom.window.Event('selectionchange'));
    const selections = () => e.links.filter(message => typeof message.hasSelection === 'boolean');
    const originalDocument = JSON.stringify(e.dom.window.__tiptapEngineInstance.editor.state.doc.toJSON());
    const range = document.createRange();
    range.setStart(text, 0);
    range.setEnd(text, 5);
    selection.removeAllRanges();
    selection.addRange(range);
    publish();
    publish();
    assert.deepEqual(selections(), [{ hasSelection: true }], 'Repeated native changes do not flood Flutter');
    selection.collapse(text, 2);
    publish();
    assert.deepEqual(selections(), [{ hasSelection: true }, { hasSelection: false }]);

    const outside = document.createElement('div');
    outside.textContent = 'Outside';
    document.body.append(outside);
    range.selectNodeContents(outside);
    selection.removeAllRanges();
    selection.addRange(range);
    publish();
    assert.equal(selections().length, 2, 'Selections outside the SOP must not reserve its drags');
    assert.equal(JSON.stringify(e.dom.window.__tiptapEngineInstance.editor.state.doc.toJSON()), originalDocument,
      'Selection must not edit the document');
    assert.equal(e.command('getContent', { format: 'html' }).content, '<p>Alpha beta</p>');
  } finally { e.close(); }
});

test('toolbar states follow formatted text, plain text, mixed selections and stored marks', () => {
  const e = create('<p><strong>Bold</strong> plain <em>Italic</em> <u>Underline</u></p>' +
    '<ul><li><p>Bullet</p></li></ul><ol><li><p>Numbered</p></li></ol>' +
    '<blockquote><p>Quote</p></blockquote><h2>Heading</h2>');
  try {
    const editor = e.dom.window.__tiptapEngineInstance.editor;
    const position = text => {
      let found;
      editor.state.doc.descendants((node, pos) => { if (node.text === text) found = pos; });
      assert.notEqual(found, undefined, text);
      return found;
    };
    const select = (from, to = from) => editor.commands.setTextSelection({ from, to });
    const active = command => e.messages.filter(message => message.name === 'stateChanged')
      .at(-1).payload.commandStates[command].isActive;
    const cases = [['Bold', 'toggleBold'], ['Italic', 'toggleItalic'], ['Underline', 'toggleUnderline'],
      ['Bullet', 'toggleBulletList'], ['Numbered', 'toggleOrderedList'],
      ['Quote', 'toggleBlockquote'], ['Heading', 'toggleHeading']];
    for (const [text, command] of cases) {
      select(position(text) + 1);
      assert.equal(active(command), true, `${command} at the formatted cursor`);
      select(position(' plain ') + 2);
      assert.equal(active(command), false, `${command} at the plain cursor`);
    }
    select(position('Bold'), position('Bold') + 4);
    assert.equal(active('toggleBold'), true);
    select(position('Bold'), position(' plain ') + 3);
    assert.equal(active('toggleBold'), false, 'A mixed range must not appear entirely bold');
    select(position(' plain ') + 2);
    e.command('exec', { command: 'toggleBold' });
    assert.equal(active('toggleBold'), true, 'A stored mark applies to the next typed text');
    e.command('exec', { command: 'toggleBold' });
    assert.equal(active('toggleBold'), false);
    assert.equal(e.command('getContent', { format: 'html' }).content.includes('<strong>Bold</strong> plain '), true);
  } finally { e.close(); }
});

test('an initial double touch selects the whole word across formatting boundaries without editing', () => {
  const e = create('<p>Alpha <strong>for</strong><em>matted</em> text.</p>');
  try {
    const editor = e.dom.window.__tiptapEngineInstance.editor;
    editor.view.posAtCoords = () => ({ pos: 11, inside: 0 });
    const touch = { screenX: 20, screenY: 30, clientX: 20, clientY: 30 };
    const dispatch = (type, touches) => {
      const event = new e.dom.window.Event(type, { bubbles: true, cancelable: true });
      Object.defineProperties(event, { touches: { value: touches }, changedTouches: { value: [touch] } });
      editor.view.dom.querySelector('em').dispatchEvent(event);
      return event;
    };
    dispatch('touchstart', [touch]);
    dispatch('touchend', []);
    assert.equal(editor.view.hasFocus(), true);
    dispatch('touchstart', [touch]);
    assert.equal(dispatch('touchend', []).defaultPrevented, true);
    assert.equal(editor.state.doc.textBetween(editor.state.selection.from, editor.state.selection.to), 'formatted');
    assert.equal(e.dom.window.getSelection().toString(), 'formatted');
    assert.equal(e.command('getContent', { format: 'html' }).content, '<p>Alpha <strong>for</strong><em>matted</em> text.</p>');
    dispatch('touchstart', [touch]);
    assert.equal(dispatch('touchend', []).defaultPrevented, true, 'A later tap clears word selection');
    assert.equal(editor.state.selection.empty, true);
    assert.equal(editor.state.selection.from, 11);
    assert.equal(e.dom.window.getSelection().isCollapsed, true);
  } finally { e.close(); }
});
