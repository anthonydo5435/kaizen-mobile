import { Extension, Mark, Node, type AnyExtension, mergeAttributes } from '@tiptap/core';
import StarterKit from '@tiptap/starter-kit';
import Image from '@tiptap/extension-image';
import { TaskItem, TaskList } from '@tiptap/extension-list';
import { TableKit } from '@tiptap/extension-table';
import { TextStyle } from '@tiptap/extension-text-style';
import { Pagination } from './pagination';
import { SopInteraction } from './interaction';

const htmlAttributes = Object.fromEntries([
  'style', 'class', 'id', 'title', 'dir', 'data-sop-role', 'data-sop-template',
].map(name => [name, {
  default: null,
  parseHTML: (element: HTMLElement) => element.getAttribute(name),
  renderHTML: (attributes: Record<string, unknown>) => attributes[name] ? { [name]: attributes[name] } : {},
}]));

// Keep source HTML styling in the schema so a text edit cannot strip it on save.
const HtmlAttributes = Extension.create({
  name: 'sopHtmlAttributes',
  addGlobalAttributes() {
    return [{
      types: ['paragraph', 'heading', 'blockquote', 'bulletList', 'orderedList', 'listItem',
        'table', 'tableRow', 'tableCell', 'tableHeader', 'image', 'codeBlock', 'horizontalRule',
        'htmlBlock', 'taskList', 'taskItem', 'bold', 'italic', 'underline', 'strike', 'link',
        'textStyle', 'highlight', 'superscript', 'subscript'],
      attributes: htmlAttributes,
    }];
  },
});
const HtmlBlock = Node.create({
  name: 'htmlBlock', group: 'block', content: 'block+',
  parseHTML: () => [{ tag: 'div' }, { tag: 'section' }, { tag: 'article' }],
  renderHTML: ({ HTMLAttributes }) => ['div', HTMLAttributes, 0],
});
const ImageWithDimensions = Image.extend({
  addAttributes() {
    return {
      ...this.parent?.(),
      width: { default: null, parseHTML: element => element.getAttribute('width') },
      height: { default: null, parseHTML: element => element.getAttribute('height') },
    };
  },
}).configure({ allowBase64: true });
const span = TextStyle.extend({
  // Class-only spans also carry meaningful styles from the document's stylesheet.
  parseHTML() {
    return [...(this.parent?.() ?? []), { tag: 'span', getAttrs: element =>
      ['class', 'id'].some(name => (element as HTMLElement).hasAttribute(name)) ? {} : false }];
  },
});
const inlineMark = (name: string, tag: string) => Mark.create({
  name, parseHTML: () => [{ tag }],
  renderHTML: ({ HTMLAttributes }) => [tag, mergeAttributes(HTMLAttributes), 0],
});

export function buildExtensions(): AnyExtension[] {
  return [
    // Preserve the source's blank paragraphs instead of appending one on reload.
    StarterKit.configure({ link: { openOnClick: false }, trailingNode: false }),
    ImageWithDimensions,
    TableKit.configure({ table: { resizable: false } }),
    span, HtmlAttributes, HtmlBlock, Pagination, SopInteraction,
    TaskList, TaskItem.configure({ nested: true }),
    inlineMark('highlight', 'mark'), inlineMark('superscript', 'sup'), inlineMark('subscript', 'sub'),
  ];
}
