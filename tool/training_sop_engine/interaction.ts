import { Extension } from '@tiptap/core';
import { Plugin, TextSelection } from '@tiptap/pm/state';

const preventsTapCursor = (document: Document) =>
  document.documentElement.dataset.sopPreventTapCursor === 'true';

export const SopInteraction = Extension.create({
  name: 'sopInteraction',
  addCommands() {
    return {
      blur: () => ({ dispatch, editor, view }) => {
        // The engine probes every command with can() while publishing toolbar
        // state. Tiptap's default blur also schedules a real blur during that
        // dry run, removing the native keyboard/caret after every selection.
        if (dispatch) requestAnimationFrame(() => {
          if (!editor.isDestroyed) {
            view.dom.blur();
            view.dom.ownerDocument.getSelection()?.removeAllRanges();
          }
        });
        return true;
      },
    };
  },
  addProseMirrorPlugins() {
    // Place the caret on every short editing tap without WebKit's focus zoom,
    // including taps that replace a selected range. Complete double-tap word
    // selection ourselves, leaving drags, long presses and pinches native.
    const nativeSelection = (document: Document) => {
      const selection = document.getSelection();
      return [selection?.anchorNode, selection?.anchorOffset,
        selection?.focusNode, selection?.focusOffset] as const;
    };
    let focusTap: { x: number; y: number; time: number; position: number } | undefined;
    let tap: {
      x: number; y: number; time: number; previousPosition?: number;
      nativeSelection: ReturnType<typeof nativeSelection>; moved: boolean;
      preventTapCursor: boolean;
    } | undefined;
    const words = new Intl.Segmenter(undefined, { granularity: 'word' });
    return [new Plugin({
      props: {
        handleDOMEvents: {
          mousedown(view, event) {
            if (!preventsTapCursor(view.dom.ownerDocument)) return false;
            event.preventDefault();
            return true;
          },
          touchstart(view, event) {
            const target = event.target instanceof Element ? event.target : undefined;
            const touch = event.touches[0];
            const now = Date.now();
            const selectWord = !!(touch && focusTap && view.hasFocus() && view.state.selection.empty &&
              view.state.selection.from === focusTap.position && now - focusTap.time < 400 &&
              Math.hypot(touch.screenX - focusTap.x, touch.screenY - focusTap.y) < 20);
            const preventTapCursor = preventsTapCursor(view.dom.ownerDocument);
            tap = (view.editable || preventTapCursor) && event.touches.length === 1 &&
              (preventTapCursor || !target?.closest('a, input, button, label, img')) ?
              { x: touch.screenX, y: touch.screenY, time: now,
                previousPosition: selectWord ? focusTap?.position : undefined,
                nativeSelection: nativeSelection(view.dom.ownerDocument), moved: false,
                preventTapCursor } : undefined;
            focusTap = undefined;
            return false;
          },
          touchmove(_, event) {
            const touch = event.touches[0];
            if (!tap) return false;
            const distance = touch ? Math.hypot(touch.screenX - tap.x, touch.screenY - tap.y) : Infinity;
            if (event.touches.length !== 1 || distance > 10) tap = undefined;
            else if (distance > 0) tap.moved = true;
            return false;
          },
          touchcancel() { tap = undefined; return false; },
          touchend(view, event) {
            const start = tap;
            tap = undefined;
            if (!start || event.touches.length || Date.now() - start.time > 500) return false;
            // Keep normal tap tolerance for finger jitter. A handle can extend
            // selection within that distance, before ProseMirror receives it.
            if (start.moved && nativeSelection(view.dom.ownerDocument)
              .some((value, index) => value !== start.nativeSelection[index])) return false;
            if (start.preventTapCursor || preventsTapCursor(view.dom.ownerDocument)) {
              event.preventDefault();
              window.TrainingSopLinks?.postMessage(JSON.stringify({ interaction: 'tap' }));
              return true;
            }
            if (!view.editable) return false;
            const touch = event.changedTouches[0];
            if (!touch) return false;
            const hit = view.posAtCoords({ left: touch.clientX, top: touch.clientY });
            if (!hit) return false;
            event.preventDefault();
            const position = view.state.doc.resolve(hit.pos);
            let selection = TextSelection.near(position);
            let selectedWord = false;
            if (start.previousPosition !== undefined && position.parent.isTextblock) {
              const text = position.parent.textBetween(0, position.parent.content.size, '', '\ufffc');
              const segments = words.segment(text);
              const atCaret = segments.containing(position.parentOffset);
              const word = atCaret?.isWordLike ? atCaret : segments.containing(position.parentOffset - 1);
              if (word?.isWordLike) {
                const from = position.start() + word.index;
                const to = from + word.segment.length;
                // Nearby taps on different words are cursor moves, even when
                // they are fast enough to resemble a double tap.
                if (start.previousPosition >= from && start.previousPosition <= to) {
                  selection = TextSelection.create(view.state.doc, from, to);
                  selectedWord = true;
                }
              }
            }
            if (!selection.eq(view.state.selection)) {
              view.dispatch(view.state.tr.setSelection(selection).setMeta('pointer', true));
            }
            // Focus synchronously within the user gesture so iOS opens its
            // keyboard, then sync the DOM caret from the tapped document position.
            // preventScroll also suppresses WebKit's automatic focus zoom.
            view.dom.focus({ preventScroll: true });
            view.focus();
            if (!selectedWord) focusTap = { x: start.x, y: start.y, time: Date.now(), position: hit.pos };
            return true;
          },
        },
      },
    })];
  },
});
