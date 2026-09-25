// PCV 编辑器内核 — CodeMirror 6 bundle
// 高亮/折叠/搜索/括号匹配/历史/多光标 = CodeMirror 6 成熟内核（不重造轮子）
// 本文件只做三件事：①初始化 CM6 ②把 Flutter 指令转给 CM6 ③把编辑器事件回传 Flutter
import { EditorState, Compartment } from '@codemirror/state';
import {
  EditorView, keymap, lineNumbers, highlightActiveLineGutter, highlightActiveLine,
  drawSelection, dropCursor, highlightSpecialChars,
} from '@codemirror/view';
import {
  defaultKeymap, history, historyKeymap, indentWithTab,
} from '@codemirror/commands';
import {
  searchKeymap, highlightSelectionMatches, openSearchPanel, setSearchQuery, SearchQuery,
} from '@codemirror/search';
import {
  syntaxHighlighting, HighlightStyle, indentOnInput, bracketMatching, foldGutter, foldKeymap,
} from '@codemirror/language';
import { closeBrackets, closeBracketsKeymap } from '@codemirror/autocomplete';
import { tags } from '@lezer/highlight';
import { cpp } from '@codemirror/lang-cpp';
import { python } from '@codemirror/lang-python';
import { javascript } from '@codemirror/lang-javascript';
import { html } from '@codemirror/lang-html';
import { css } from '@codemirror/lang-css';
import { json } from '@codemirror/lang-json';
import { markdown } from '@codemirror/lang-markdown';
import { yaml } from '@codemirror/lang-yaml';

// ============ JS → Flutter 桥接 ============
function call(type, payload) {
  try {
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      window.flutter_inappwebview.callHandler('pcv', type, payload || {});
    }
  } catch (e) { /* 桥不在（浏览器调试）时静默 */ }
}

// ============ 语言映射 ============
function langFor(path) {
  const ext = ((path || '').split('.').pop() || '').toLowerCase();
  switch (ext) {
    case 'c': case 'h': case 'cc': case 'cpp': case 'hpp': case 'cxx':
      return cpp();
    case 'py': case 'pyw':
      return python();
    case 'js': case 'mjs': case 'cjs':
      return javascript();
    case 'jsx':
      return javascript({ jsx: true });
    case 'ts':
      return javascript({ typescript: true });
    case 'tsx':
      return javascript({ typescript: true, jsx: true });
    case 'html': case 'htm': case 'vue':
      return html();
    case 'css': case 'scss': case 'less':
      return css();
    case 'json':
      return json();
    case 'md': case 'markdown':
      return markdown();
    case 'yaml': case 'yml':
      return yaml();
    default:
      return [];
  }
}

// ============ 主题（对齐 PCV 设计令牌：暗=Tokyo Night / 亮=Latte） ============
const DARK_UI = {
  bg: '#1f2335', fg: '#c0caf5', dim: '#565f89',
  cursor: '#7aa2f7', sel: 'rgba(122,162,247,0.22)', active: 'rgba(41,46,66,0.55)',
  border: '#2c3149', panel: '#24283b',
};
const LIGHT_UI = {
  bg: '#ffffff', fg: '#4c4f69', dim: '#8c8fa1',
  cursor: '#1e66f5', sel: 'rgba(30,102,245,0.16)', active: 'rgba(76,79,105,0.05)',
  border: '#d5d9e2', panel: '#eff1f5',
};

function uiTheme(dark, fontPx) {
  const c = dark ? DARK_UI : LIGHT_UI;
  return EditorView.theme({
    '&': { backgroundColor: c.bg, color: c.fg, fontSize: fontPx + 'px' },
    '.cm-scroller': { fontFamily: "'JetBrainsMono','JetBrains Mono',ui-monospace,SFMono-Regular,monospace", lineHeight: '1.65' },
    '.cm-content': { caretColor: c.cursor, padding: '10px 0' },
    '.cm-line': { padding: '0 14px' },
    '.cm-cursor, .cm-dropCursor': { borderLeftColor: c.cursor, borderLeftWidth: '2px' },
    '&.cm-focused .cm-selectionBackground, .cm-selectionBackground, .cm-content ::selection': { backgroundColor: c.sel },
    '.cm-activeLine': { backgroundColor: c.active },
    '.cm-gutters': { backgroundColor: c.bg, color: c.dim, border: 'none', borderRight: '1px solid ' + c.border, paddingLeft: '4px' },
    '.cm-activeLineGutter': { backgroundColor: c.active, color: c.fg, borderRight: '1px solid ' + c.border },
    '.cm-foldPlaceholder': { backgroundColor: c.panel, border: 'none', color: c.dim, padding: '0 4px', borderRadius: '4px' },
    '.cm-panels': { backgroundColor: c.panel, color: c.fg },
    '.cm-panels.cm-panels-top': { borderBottom: '1px solid ' + c.border },
    '.cm-panels.cm-panels-bottom': { borderTop: '1px solid ' + c.border },
    '.cm-textfield': { backgroundColor: dark ? '#1b1e2d' : '#ffffff', color: c.fg, border: '1px solid ' + c.border, borderRadius: '6px', fontSize: '13px', padding: '4px 8px' },
    '.cm-button': { backgroundColor: c.panel, backgroundImage: 'none', color: c.fg, border: '1px solid ' + c.border, borderRadius: '6px', fontSize: '12px' },
    '.cm-searchMatch': { backgroundColor: 'rgba(224,175,104,0.28)', outline: '1px solid rgba(224,175,104,0.6)' },
    '.cm-searchMatch.cm-searchMatch-selected': { backgroundColor: 'rgba(224,175,104,0.55)' },
    '.cm-selectionMatch': { backgroundColor: dark ? 'rgba(122,162,247,0.14)' : 'rgba(30,102,245,0.10)' },
    '.cm-tooltip': { backgroundColor: c.panel, border: '1px solid ' + c.border, borderRadius: '8px' },
    '.cm-tooltip-autocomplete ul li[aria-selected]': { backgroundColor: c.sel, color: c.fg },
  }, { dark });
}

const DARK_HL = HighlightStyle.define([
  { tag: [tags.keyword, tags.modifier, tags.controlKeyword, tags.moduleKeyword], color: '#bb9af7' },
  { tag: [tags.function(tags.variableName), tags.function(tags.propertyName)], color: '#7aa2f7' },
  { tag: [tags.string, tags.special(tags.string), tags.regexp], color: '#9ece6a' },
  { tag: [tags.comment, tags.lineComment, tags.blockComment, tags.docComment], color: '#565f89', fontStyle: 'italic' },
  { tag: [tags.number, tags.bool, tags.null], color: '#ff9e64' },
  { tag: [tags.typeName, tags.className, tags.namespace, tags.macroName], color: '#2ac3de' },
  { tag: tags.operator, color: '#89ddff' },
  { tag: [tags.punctuation, tags.separator, tags.bracket], color: '#a9b1d6' },
  { tag: [tags.propertyName, tags.attributeName], color: '#7dcfff' },
  { tag: [tags.definition(tags.variableName), tags.definition(tags.propertyName)], color: '#c0caf5' },
  { tag: tags.variableName, color: '#c0caf5' },
  { tag: [tags.heading, tags.strong], fontWeight: '700', color: '#7aa2f7' },
  { tag: tags.emphasis, fontStyle: 'italic' },
  { tag: tags.link, color: '#7dcfff', textDecoration: 'underline' },
  { tag: tags.strikethrough, textDecoration: 'line-through' },
  { tag: tags.invalid, color: '#f7768e' },
]);

const LIGHT_HL = HighlightStyle.define([
  { tag: [tags.keyword, tags.modifier, tags.controlKeyword, tags.moduleKeyword], color: '#8839ef' },
  { tag: [tags.function(tags.variableName), tags.function(tags.propertyName)], color: '#1e66f5' },
  { tag: [tags.string, tags.special(tags.string), tags.regexp], color: '#3d9a29' },
  { tag: [tags.comment, tags.lineComment, tags.blockComment, tags.docComment], color: '#8c8fa1', fontStyle: 'italic' },
  { tag: [tags.number, tags.bool, tags.null], color: '#e05a00' },
  { tag: [tags.typeName, tags.className, tags.namespace, tags.macroName], color: '#0d7a8c' },
  { tag: tags.operator, color: '#179299' },
  { tag: [tags.punctuation, tags.separator, tags.bracket], color: '#5c5f77' },
  { tag: [tags.propertyName, tags.attributeName], color: '#0d7a8c' },
  { tag: [tags.definition(tags.variableName), tags.definition(tags.propertyName)], color: '#4c4f69' },
  { tag: tags.variableName, color: '#4c4f69' },
  { tag: [tags.heading, tags.strong], fontWeight: '700', color: '#1e66f5' },
  { tag: tags.emphasis, fontStyle: 'italic' },
  { tag: tags.link, color: '#0d7a8c', textDecoration: 'underline' },
  { tag: tags.strikethrough, textDecoration: 'line-through' },
  { tag: tags.invalid, color: '#d20f39' },
]);

function themeBundle(dark, fontPx) {
  return [uiTheme(dark, fontPx), syntaxHighlighting(dark ? DARK_HL : LIGHT_HL)];
}

// ============ 动态配置槽 ============
const themeComp = new Compartment();
const langComp = new Compartment();
const roComp = new Compartment();

let currentDark = true;
let currentFont = 14;
let currentPath = '';
let view = null;

// ============ 事件回传（防抖） ============
let changedTimer = null;
let cursorTimer = null;
function scheduleChanged() {
  if (changedTimer) clearTimeout(changedTimer);
  changedTimer = setTimeout(() => {
    changedTimer = null;
    call('changed', { content: view.state.doc.toString() });
  }, 700);
}
function scheduleCursor() {
  if (cursorTimer) return;
  cursorTimer = setTimeout(() => {
    cursorTimer = null;
    const sel = view.state.selection.main;
    const line = view.state.doc.lineAt(sel.head);
    call('cursor', {
      line: line.number,
      col: sel.head - line.from + 1,
      selLen: sel.to - sel.from,
    });
  }, 150);
}

const updateListener = EditorView.updateListener.of((u) => {
  if (u.docChanged) scheduleChanged();
  if (u.selectionSet || u.docChanged) scheduleCursor();
});

// ============ 基础扩展（全部来自 CM6 成熟生态） ============
function baseExtensions() {
  return [
    lineNumbers(),
    highlightActiveLineGutter(),
    highlightSpecialChars(),
    history(),
    foldGutter(),
    drawSelection({ cursorBlinkRate: 1100 }),
    dropCursor(),
    EditorState.allowMultipleSelections.of(true),
    indentOnInput(),
    bracketMatching(),
    closeBrackets(),
    highlightActiveLine(),
    highlightSelectionMatches(),
    EditorView.lineWrapping, // 手机窄屏——自动换行
    keymap.of([
      ...closeBracketsKeymap,
      ...defaultKeymap,
      ...historyKeymap,
      ...foldKeymap,
      ...searchKeymap,
      indentWithTab,
    ]),
    EditorView.contentAttributes.of({
      autocorrect: 'off', autocapitalize: 'off', spellcheck: 'false',
    }),
    updateListener,
  ];
}

function makeState(content, path) {
  return EditorState.create({
    doc: content,
    extensions: [
      ...baseExtensions(),
      themeComp.of(themeBundle(currentDark, currentFont)),
      langComp.of(langFor(path)),
      roComp.of(EditorState.readOnly.of(false)),
    ],
  });
}

// ============ 对外 API（Flutter 通过 evaluateJavascript 调用 window.pcv.*） ============
window.pcv = {
  openFile(path, content, opts) {
    opts = opts || {};
    currentPath = path || '';
    if (typeof opts.dark === 'boolean') currentDark = opts.dark;
    if (typeof opts.fontPx === 'number') currentFont = opts.fontPx;
    view.setState(makeState(content, currentPath));
    view.scrollDOM.scrollTop = 0;
    document.body.style.background = (currentDark ? DARK_UI : LIGHT_UI).bg;
    call('fileOpened', { path: currentPath, lines: view.state.doc.lines });
  },
  setTheme(dark) {
    currentDark = !!dark;
    view.dispatch({ effects: themeComp.reconfigure(themeBundle(currentDark, currentFont)) });
    document.body.style.background = (currentDark ? DARK_UI : LIGHT_UI).bg;
  },
  setFontSize(px) {
    currentFont = Math.max(10, Math.min(24, +px || 14));
    view.dispatch({ effects: themeComp.reconfigure(themeBundle(currentDark, currentFont)) });
  },
  setReadOnly(b) {
    view.dispatch({ effects: roComp.reconfigure(EditorState.readOnly.of(!!b)) });
  },
  getContent() { return view.state.doc.toString(); },
  getContentJson() { return JSON.stringify({ content: view.state.doc.toString() }); },
  focus() { view.focus(); },
  goToLine(n) {
    const num = Math.max(1, Math.min(+n || 1, view.state.doc.lines));
    const info = view.state.doc.line(num);
    view.dispatch({
      selection: { anchor: info.from },
      effects: EditorView.scrollIntoView(info.from, { y: 'center' }),
    });
    view.focus();
  },
  search(term) {
    if (term) view.dispatch({ effects: setSearchQuery.of(new SearchQuery({ search: term })) });
    openSearchPanel(view);
  },
  formatDoc() { /* 预留：格式化插件接入点 */ },
  stats() {
    return JSON.stringify({
      lines: view.state.doc.lines,
      length: view.state.doc.length,
      path: currentPath,
    });
  },
};

// ============ 初始化 ============
view = new EditorView({
  state: makeState('// PCV · 从 Flutter 侧打开文件\n', ''),
  parent: document.getElementById('ed'),
});
document.body.style.background = DARK_UI.bg;
call('ready', {});
