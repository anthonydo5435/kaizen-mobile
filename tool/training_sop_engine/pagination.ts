import { Extension } from '@tiptap/core';
import { Plugin, PluginKey } from '@tiptap/pm/state';
import { Decoration, DecorationSet, type EditorView } from '@tiptap/pm/view';
import type { Node as DocumentNode } from '@tiptap/pm/model';

const mm = 96 / 25.4;
const paper = { height: 297 * mm, top: 4.5 * mm, bottom: 18 * mm, gap: 24 };
const stride = paper.height + paper.gap;
const bodyHeight = paper.height - paper.top - paper.bottom;
const key = new PluginKey<DecorationSet>('sopPagination');
interface Block { node: DocumentNode; pos: number; element: HTMLElement; }
interface Space { pos: number; height: number; kind: 'block' | 'line' | 'row'; columns?: number; }

// Page boundaries are view decorations. They never enter the document schema,
// saved HTML, undo history, or the content supplied to Flutter's autosave.
function decorations(view: EditorView, spaces: Space[]) {
  return DecorationSet.create(view.state.doc, spaces.map(space => Decoration.widget(space.pos, () => {
    const element = document.createElement(space.kind === 'row' ? 'tr' : 'span');
    element.className = 'sop-page-spacer';
    element.setAttribute('aria-hidden', 'true');
    element.style.height = `${space.height}px`;
    if (space.kind === 'row') {
      const cell = document.createElement('td');
      cell.colSpan = space.columns ?? 1;
      cell.style.height = `${space.height}px`;
      element.append(cell);
    }
    return element;
  }, { side: -1, marks: [], ignoreSelection: true, key: `${space.pos}:${space.height}` })));
}

class PageLayout {
  private frame = 0;
  private compositionTimer?: ReturnType<typeof setTimeout>;
  private layingOut = false;
  private destroyed = false;
  private spaces: Space[] = [];
  private pages: HTMLElement;
  private width = 0;
  private observer?: ResizeObserver;
  private root: HTMLElement;

  constructor(private view: EditorView) {
    this.root = view.dom.parentElement!;
    this.pages = document.createElement('div');
    this.pages.className = 'sop-pages';
    this.pages.setAttribute('aria-hidden', 'true');
    this.root.prepend(this.pages);
    this.drawPages(1);
    view.dom.addEventListener('load', this.schedule, true);
    view.dom.addEventListener('error', this.schedule, true);
    view.dom.addEventListener('compositionend', this.compositionEnd);
    document.addEventListener('sop-layout', this.schedule);
    document.fonts?.addEventListener('loadingdone', this.schedule);
    if (typeof ResizeObserver !== 'undefined') {
      this.observer = new ResizeObserver(() => {
        const width = view.dom.getBoundingClientRect().width;
        if (Math.abs(width - this.width) > 0.5) { this.width = width; this.schedule(); }
      });
      this.observer.observe(view.dom);
    }
    this.schedule();
  }

  update(view: EditorView, previous: { doc: DocumentNode }) {
    if (!this.layingOut && previous.doc !== view.state.doc) this.schedule();
  }

  private schedule = () => {
    if (this.destroyed || this.frame) return;
    this.frame = requestAnimationFrame(() => {
      this.frame = 0;
      // Replacing view decorations during an IME composition can cancel input.
      if (this.view.composing) return;
      this.layout();
    });
  };

  private compositionEnd = () => {
    clearTimeout(this.compositionTimer);
    // ProseMirror clears its composing flag shortly after the DOM event.
    this.compositionTimer = setTimeout(this.schedule, 60);
  };

  private apply() {
    const transaction = this.view.state.tr.setMeta(key, decorations(this.view, this.spaces))
      .setMeta('addToHistory', false);
    // Only this view's decoration state changes. Bypass Tiptap's content bridge
    // so laying out ten pages does not send ten identical document snapshots.
    this.view.updateState(this.view.state.apply(transaction));
  }

  private bounds() { return this.root.getBoundingClientRect().top; }
  private end(page: number) { return this.bounds() + page * stride + paper.height - paper.bottom; }
  private start(page: number) { return this.bounds() + page * stride + paper.top; }
  private pageAt(y: number) { return Math.max(0, Math.floor((y - this.bounds()) / stride)); }

  private block(node: DocumentNode, pos: number): Block | undefined {
    const element = this.view.nodeDOM(pos);
    return element instanceof HTMLElement ? { node, pos, element } : undefined;
  }

  private children(block: Block) {
    const children: Block[] = [];
    block.node.forEach((node, offset) => {
      const child = this.block(node, block.pos + 1 + offset);
      if (child) children.push(child);
    });
    return children;
  }

  private move(pos: number, page: number, measure: () => number, kind: Space['kind'] = 'block', columns?: number) {
    const space: Space = { pos, height: Math.max(0, this.start(page) - measure()), kind, columns };
    this.spaces.push(space);
    // Inserting a block can change collapsed margins. Correct against the real
    // rendered position rather than accumulating assumed paragraph heights.
    for (let attempt = 0; attempt < 3; attempt++) {
      this.apply();
      // A focused editor can restore its scroll position when decorations
      // change. Re-read the page origin after applying, in that same viewport.
      const difference = this.start(page) - measure();
      if (Math.abs(difference) < 0.5) break;
      space.height = Math.max(0, space.height + difference);
    }
  }

  private fit(block: Block, bottom = () => block.element.getBoundingClientRect().bottom) {
    const top = () => block.element.getBoundingClientRect().top;
    const page = this.pageAt(top());
    if (bottom() <= this.end(page) + 0.5 && top() >= this.start(page) - 0.5) return;
    const targetPage = top() < this.start(page) - 0.5 ? page : page + 1;
    this.move(block.pos, targetPage, top);
  }

  private lines(block: Block) {
    const first = block.pos + 1;
    const last = first + block.node.content.size;
    let pos = first;
    while (pos < last) {
      const rect = () => this.view.coordsAtPos(pos, 1);
      const current = rect();
      const page = this.pageAt(current.top);
      if (current.bottom > this.end(page) + 0.5 || current.top < this.start(page) - 0.5) {
        const targetPage = current.top < this.start(page) - 0.5 ? page : page + 1;
        this.move(pos, targetPage, () => rect().top, 'line');
      }
      const lineTop = rect().top;
      // Textblock coordinates are monotonic. Find the next visual line without
      // a DOM measurement for every character in a long paragraph.
      let low = pos + 1, high = last;
      while (low < high) {
        const middle = Math.floor((low + high) / 2);
        if (this.view.coordsAtPos(middle, 1).top > lineTop + 1) high = middle;
        else low = middle + 1;
      }
      pos = low;
    }
  }

  private table(block: Block) {
    const rows = this.children(block);
    // A row-spanned cell and the rows it covers travel together when they fit.
    for (let index = 0; index < rows.length;) {
      let end = index + 1;
      for (let row = index; row < end && row < rows.length; row++) {
        rows[row].node.forEach(cell => { end = Math.max(end, row + Number(cell.attrs.rowspan ?? 1)); });
      }
      end = Math.min(end, rows.length);
      const first = rows[index], last = rows[end - 1];
      const top = () => first.element.getBoundingClientRect().top;
      const bottom = () => last.element.getBoundingClientRect().bottom;
      const page = this.pageAt(top());
      if (bottom() - top() <= bodyHeight) {
        if (bottom() > this.end(page) + 0.5 || top() < this.start(page) - 0.5) {
          const next = top() < this.start(page) - 0.5 ? page : page + 1;
          const columns = Array.from((first.element as HTMLTableRowElement).cells)
            .reduce((count, cell) => count + cell.colSpan, 0);
          this.move(first.pos, next, top, 'row', columns);
        }
      } else {
        // Exceptionally tall cells flow by their own paragraphs/lines. All
        // columns use the same page coordinates, retaining merged-cell data.
        for (let row = index; row < end; row++) {
          for (const cell of this.children(rows[row])) this.flow(this.children(cell));
        }
      }
      index = end;
    }
  }

  private flow(blocks: Block[]) {
    blocks.forEach((block, index) => {
      const rect = block.element.getBoundingClientRect();
      const type = block.node.type.name;
      if (type === 'table' && rect.height > bodyHeight) { this.table(block); return; }
      if (rect.height > bodyHeight && block.node.isTextblock) { this.lines(block); return; }
      if (rect.height > bodyHeight && block.node.childCount && !block.node.isLeaf) {
        this.flow(this.children(block)); return;
      }
      if (['bulletList', 'orderedList', 'taskList', 'blockquote', 'htmlBlock'].includes(type) &&
        rect.bottom > this.end(this.pageAt(rect.top)) + 0.5 &&
        !['avoid', 'avoid-page'].includes(getComputedStyle(block.element).breakInside)) {
        this.flow(this.children(block)); return;
      }
      // Keep a heading with the first following block, and keep the template's
      // three coloured header blocks together when their combined height fits.
      let next = blocks[index + 1];
      if (block.element.dataset.sopRole === 'eyebrow') next = blocks[index + 2] ?? next;
      const keepNext = type === 'heading' || block.element.dataset.sopRole === 'eyebrow' ||
        block.element.dataset.sopRole === 'title';
      let following = index + 1;
      while (blocks[following]?.node.type.name === 'heading' && blocks[following + 1]) following++;
      if (type === 'heading') next = blocks[following] ?? next;
      const bottom = next && keepNext ? () => this.leadingBottom(next) : undefined;
      if (bottom && bottom() - rect.top <= bodyHeight) this.fit(block, bottom);
      else this.fit(block);
    });
  }

  private leadingBottom(block: Block): number {
    if (['bulletList', 'orderedList', 'taskList', 'blockquote', 'htmlBlock'].includes(block.node.type.name) ||
      (block.node.type.name === 'table' && block.element.getBoundingClientRect().height > bodyHeight)) {
      const first = this.children(block)[0];
      if (first) return this.leadingBottom(first);
    }
    if (block.node.isTextblock && block.element.getBoundingClientRect().height > bodyHeight) {
      const first = this.view.coordsAtPos(block.pos + 1, 1);
      const lineHeight = parseFloat(getComputedStyle(block.element).lineHeight) || first.bottom - first.top;
      return first.bottom + lineHeight;
    }
    return block.element.getBoundingClientRect().bottom;
  }

  private drawPages(count: number) {
    const fragment = document.createDocumentFragment();
    for (let page = 0; page < count; page++) {
      const sheet = document.createElement('div');
      sheet.className = 'sop-page';
      sheet.style.top = `${page * stride}px`;
      fragment.append(sheet);
      if (page < count - 1) {
        const boundary = document.createElement('div');
        boundary.className = 'sop-page-boundary';
        boundary.style.top = `${page * stride + paper.height - paper.bottom}px`;
        fragment.append(boundary);
      }
    }
    this.pages.replaceChildren(fragment);
    this.root.style.minHeight = `${count * paper.height + (count - 1) * paper.gap}px`;
    this.root.dataset.sopPageCount = String(count);
  }

  private layout() {
    if (!this.view.dom.getBoundingClientRect().width) return; // No layout in jsdom/hidden views.
    this.layingOut = true;
    try {
      this.spaces = [];
      this.apply();
      const blocks: Block[] = [];
      this.view.state.doc.forEach((node, pos) => {
        const block = this.block(node, pos);
        if (block) blocks.push(block);
      });
      this.flow(blocks);
      const bottom = blocks.at(-1)?.element.getBoundingClientRect().bottom ?? this.start(0);
      this.drawPages(this.pageAt(bottom) + 1);
    } finally { this.layingOut = false; }
  }

  destroy() {
    this.destroyed = true;
    cancelAnimationFrame(this.frame);
    clearTimeout(this.compositionTimer);
    this.observer?.disconnect();
    this.view.dom.removeEventListener('load', this.schedule, true);
    this.view.dom.removeEventListener('error', this.schedule, true);
    this.view.dom.removeEventListener('compositionend', this.compositionEnd);
    document.removeEventListener('sop-layout', this.schedule);
    document.fonts?.removeEventListener('loadingdone', this.schedule);
    this.pages.remove();
    this.root.style.removeProperty('min-height');
    delete this.root.dataset.sopPageCount;
  }
}

export const Pagination = Extension.create({
  name: 'sopPagination',
  addProseMirrorPlugins() {
    return [new Plugin({
      key,
      state: {
        init: () => DecorationSet.empty,
        apply: (transaction, previous) => transaction.getMeta(key) ?? previous.map(transaction.mapping, transaction.doc),
      },
      props: { decorations: state => key.getState(state) },
      view: view => new PageLayout(view),
    })];
  },
});
