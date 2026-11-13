import { execFileSync } from 'node:child_process';
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

// The engine protocol matches tiptap_flutter 0.3.0. Keep its source immutable.
const revision = 'c98b01e1e9dd7dddfa720e6d6490e93e4342433b';
const root = dirname(fileURLToPath(import.meta.url));
const source = mkdtempSync(resolve(tmpdir(), 'kaizen-sop-engine-'));
const assets = resolve(root, '../../lib/features/training/presentation/assets/sop_editor');
const runtimePackages = new Set();
function packageNotices(name) {
  if (runtimePackages.has(name)) return '';
  runtimePackages.add(name);
  const directory = resolve(root, 'node_modules', name);
  const manifest = JSON.parse(readFileSync(resolve(directory, 'package.json'), 'utf8'));
  const license = readdirSync(directory).find(file => /^licen[sc]e(?:\.|$)/i.test(file));
  if (!license) throw new Error(`Missing license notice: ${name}`);
  return `\n\n${name} ${manifest.version}\n${readFileSync(resolve(directory, license), 'utf8')}` +
    Object.keys(manifest.dependencies ?? {}).sort().map(packageNotices).join('');
}
try {
  const git = (...args) => execFileSync('git', args, { cwd: source, stdio: 'inherit' });
  git('init', '--quiet');
  git('fetch', '--quiet', '--depth', '1', 'https://github.com/blackcoffee2/tiptap-engine.git', revision);
  git('checkout', '--quiet', '--detach', 'FETCH_HEAD');
  symlinkSync(resolve(root, 'node_modules'), resolve(source, 'node_modules'), 'dir');
  copyFileSync(resolve(root, 'extensions.ts'), resolve(source, 'src/extensions/registry.ts'));
  copyFileSync(resolve(root, 'document.ts'), resolve(source, 'src/sop-document.ts'));
  copyFileSync(resolve(root, 'pagination.ts'), resolve(source, 'src/extensions/pagination.ts'));
  copyFileSync(resolve(root, 'interaction.ts'), resolve(source, 'src/extensions/interaction.ts'));
  copyFileSync(resolve(root, 'flutter_webview_adapter.ts'), resolve(source, 'src/adapters/sop-webview.ts'));
  copyFileSync(resolve(root, 'formatting.ts'), resolve(source, 'src/core/sop-formatting.ts'));
  const engine = resolve(source, 'src/core/engine.ts');
  const engineSource = readFileSync(engine, 'utf8');
  const activeQuery = 'isActive = editor.isActive(name);';
  if (!engineSource.includes(activeQuery)) throw new Error('Upstream command-state query changed');
  writeFileSync(engine, 'import { isSopFormatActive } from "./sop-formatting";\n' +
    engineSource.replace(activeQuery, 'isActive = isSopFormatActive(editor, name);'));
  const entry = resolve(source, 'src/index.ts');
  const entrySource = readFileSync(entry, 'utf8');
  const adapterImport = 'import { WebViewAdapter } from "./adapters/webview";';
  if (!entrySource.includes(adapterImport)) throw new Error('Upstream WebView adapter import changed');
  writeFileSync(entry, entrySource.replace(adapterImport,
    'import { WebViewAdapter } from "./adapters/sop-webview";') + '\nimport "./sop-document";\n');
  execFileSync(process.execPath, [resolve(root, 'node_modules/vite/bin/vite.js'), 'build'], {
    cwd: source, stdio: 'inherit',
  });
  mkdirSync(assets, { recursive: true });
  copyFileSync(resolve(source, 'dist/tiptap-engine.js'), resolve(assets, 'sop-engine.js'));
  copyFileSync(resolve(root, 'document.css'), resolve(assets, 'sop-document.css'));
  const dependencies = JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf8')).devDependencies;
  writeFileSync(resolve(assets, 'LICENSES.txt'),
    `tiptap-engine ${revision}\n${readFileSync(resolve(source, 'LICENSE'), 'utf8')}` +
    Object.keys(dependencies).filter(name => name.startsWith('@tiptap/')).sort().map(packageNotices).join(''));
} finally {
  rmSync(source, { recursive: true, force: true });
}
