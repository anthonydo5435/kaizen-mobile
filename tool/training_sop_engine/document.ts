interface SopViewport {
  width: number;
  textScale: number;
  preventTapCursor?: boolean;
}
declare global {
  interface Window {
    TrainingSopLinks?: { postMessage(message: string): void };
    TrainingSopDocument: {
      configure(viewport: SopViewport): void;
      installStyles(css: string, sourceStyles: string): void;
      blur(): void;
    };
  }
}

const pageWidth = 210 * 96 / 25.4;
const canvasWidth = pageWidth + 24;
let fitScale = 1;
window.TrainingSopDocument = {
  configure({ width, textScale, preventTapCursor = false }) {
    const wasPreventingTapCursor = document.documentElement.dataset.sopPreventTapCursor === 'true';
    document.documentElement.dataset.sopPreventTapCursor = String(preventTapCursor);
    if (preventTapCursor && !wasPreventingTapCursor) {
      (document.activeElement as HTMLElement | null)?.blur();
      document.getSelection()?.removeAllRanges();
    }
    document.querySelectorAll('meta[name="viewport"]').forEach(meta => meta.remove());
    const viewport = document.createElement('meta');
    viewport.name = 'viewport';
    const fit = width / canvasWidth;
    fitScale = fit;
    viewport.content = `width=${Math.ceil(canvasWidth)},initial-scale=${fit},minimum-scale=${fit},maximum-scale=4,user-scalable=yes`;
    document.head.append(viewport);
    document.documentElement.style.setProperty('--sop-text-scale', String(textScale));
    document.getElementById('editor')?.classList.add('sop-a4-sheet');
    document.dispatchEvent(new Event('sop-layout'));
  },
  installStyles(css, sourceStyles) {
    document.querySelectorAll('head style').forEach(style => style.remove());
    const style = document.createElement('style');
    style.textContent = css;
    document.head.append(style);
    const original = document.createElement('style');
    original.textContent = sourceStyles;
    document.head.append(original);
    document.body.style.cssText = '';
    const editor = document.getElementById('editor');
    if (editor) editor.style.cssText = '';
    document.dispatchEvent(new Event('sop-layout'));
  },
  blur() { (document.activeElement as HTMLElement | null)?.blur(); },
};
window.visualViewport?.addEventListener('resize', () => {
  window.TrainingSopLinks?.postMessage(JSON.stringify({
    zoomed: (window.visualViewport?.scale ?? fitScale) > fitScale + 0.05,
  }));
});

// Native selection handles can start outside the text nodes themselves. Let
// Flutter reserve the entire document's next drag while a text range is selected,
// in both the editor and reader, then restore tab swipes when it is collapsed.
let hadSelection = false;
document.addEventListener('selectionchange', () => {
  const selection = document.getSelection();
  const editor = document.querySelector('.tiptap');
  const hasSelection = !!(selection && !selection.isCollapsed && editor &&
    editor.contains(selection.anchorNode) && editor.contains(selection.focusNode));
  if (hasSelection === hadSelection) return;
  hadSelection = hasSelection;
  window.TrainingSopLinks?.postMessage(JSON.stringify({ hasSelection }));
});

// Keep links inside the document from replacing the editor or its JS bridge.
document.addEventListener('click', event => {
  if (document.documentElement.dataset.sopPreventTapCursor === 'true') {
    event.preventDefault();
    event.stopImmediatePropagation();
    window.TrainingSopLinks?.postMessage(JSON.stringify({ interaction: 'tap' }));
    return;
  }
  const link = (event.target as Element | null)?.closest<HTMLAnchorElement>('a[href]');
  if (!link) return;
  event.preventDefault();
  event.stopPropagation();
  const href = link.getAttribute('href') ?? '';
  if (href.startsWith('#')) {
    document.getElementById(decodeURIComponent(href.slice(1)))?.scrollIntoView();
  } else if (/^(https?:|mailto:|tel:)/i.test(href)) {
    window.TrainingSopLinks?.postMessage(JSON.stringify({ href }));
  }
}, true);

document.addEventListener('scroll', () => {
  if (document.documentElement.dataset.sopPreventTapCursor === 'true') {
    window.TrainingSopLinks?.postMessage(JSON.stringify({ interaction: 'scroll' }));
  }
}, { capture: true, passive: true });
