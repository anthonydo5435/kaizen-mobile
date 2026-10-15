The SOP uses `tiptap_flutter` 0.3.0's public editor controller and bridge with an
extended, locally bundled Tiptap engine. Tables, source HTML styling, images and
links are rendered by the native WebView on an A4 sheet. Flutter owns the toolbar,
loading/error UI and existing debounced saves.

The checked-in assets work offline; Node.js is only needed to rebuild or test them:

```sh
cd tool/training_sop_engine
npm ci
npm run build
npm test
npm run test:layout
```

`build.mjs` fetches an immutable upstream engine commit into a temporary directory
and applies this feature's extension set and page surface. It never modifies the
installed Flutter package or `third_party/`. The output and notices are stored in
`lib/features/training/presentation/assets/sop_editor/`.

The reading and editing surfaces display 210 × 297 mm A4 pages with 24 px gaps.
Margins are 4.5 mm at the top, 4 mm at the sides and 18 mm at the bottom.
`pagination.ts` measures native text layout and inserts ProseMirror view
decorations between blocks, table row groups or lines of oversized paragraphs.
Headings stay with following content, merged table rows travel together when
they fit, and oversized images are constrained to the page body. Pagination
reflows after edits, image loading, font loading and text-scale changes, and
waits until IME composition ends before changing decorations.

Page frames and spacers are absent from the document schema, saved HTML,
clipboard content and undo history. Layout-only state updates bypass the engine
content bridge. Printing hides display decorations and uses native A4 print
fragmentation. The mobile viewport fits the paper initially, allows pinch zoom,
and leaves horizontal Training swipes available at the initial scale.

Every short editing tap resolves its document position before focusing with
`preventScroll`, avoiding iOS form zoom and a jump to the document start, including
when the editor is already focused. A second short tap selects the word across
inline formatting marks. A short tap replaces an existing selection with the
caret at the tapped text; rapid taps on different words remain cursor moves.
Small selection-handle drags, pinches, long presses and read-only taps retain
native behavior. The interaction
extension also keeps `can().blur()` probes free of side effects; explicit blur
still dismisses the keyboard. The adapter sends replies and editing events
through Flutter's registered `TiptapBridge` channel on both platforms instead
of relying on the package's temporary iOS handler alias.

The document uses `touch-action: manipulation` to reserve double taps for native
text selection while retaining scrolling and pinch zoom. Toolbar command states
query the associated schema type (for example, `bold` for `toggleBold`), including
stored marks and mixed selections. On iOS, the SOP controller uses a scoped native
bridge to hide the WebView's previous/next/Done keyboard accessory. Its public
responder getter is overridden only on that WebView's text input instance;
other WebViews and the app's formatting toolbar and Done button keep their behavior.

The SOP's iOS scroll delegate also retains the last zoom set by a two-finger
pinch. This prevents native long-press focus from magnifying small text after the
keyboard was dismissed. Pinch zoom, zoom bounce and viewport minimum-scale
changes remain native; existing external scroll callbacks are forwarded and
WebKit keeps its internal delegate. The protection belongs to the individual
SOP WebView and is released with it.

Native selection changes tell Flutter when a text range is selected. Selection
handle drags, long presses and pinch gestures stay in the SOP instead of changing
Training tabs. At page-fit size, clearing the selection restores horizontal tab
swipes. Gesture factories stay mounted while selection and zoom state change so
an in-progress native gesture is not cancelled.

The layout tests use a locally installed Chromium browser through its DevTools
protocol, with a temporary profile. Set `CHROME_BIN` if it is installed outside
the standard macOS/Linux paths. They measure rendered text fragments and page
geometry; jsdom tests separately verify HTML preservation and bridge commands.
