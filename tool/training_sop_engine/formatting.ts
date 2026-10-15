import type { Editor } from '@tiptap/core';

const formatTypes: Record<string, string> = {
  toggleBold: 'bold',
  toggleItalic: 'italic',
  toggleUnderline: 'underline',
  toggleBulletList: 'bulletList',
  toggleOrderedList: 'orderedList',
  toggleBlockquote: 'blockquote',
  toggleHeading: 'heading',
};

// Commands and schema types have different names. Query the schema type so
// cursor moves, ranged selections and stored marks all use Tiptap's semantics.
export function isSopFormatActive(editor: Editor, command: string): boolean {
  return editor.isActive(formatTypes[command] ?? command);
}
