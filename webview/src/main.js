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
import { linter, lintGutter } from '@codemirror/lint';
import { indentMore, indentLess } from '@codemirror/commands';
import { syntaxTree } from '@codemirror/language';
import { cpp } from '@codemirror/lang-cpp';
import { python } from '@codemirror/lang-python';
import { javascript } from '@codemirror/lang-javascript';
import { html } from '@codemirror/lang-html';
import { css } from '@codemirror/lang-css';
import { json } from '@codemirror/lang-json';
import { markdown } from '@codemirror/lang-markdown';
import { yaml } from '@codemirror/lang-yaml';

// ============ JS → Flutter 桥接 ============
// 主通道：webview_flutter 官方插件的 JavaScriptChannel「PcvBridge」
// 兼容通道：flutter_inappwebview callHandler（保留；浏览器调试时全部静默降级）
function call(type, payload) {
  const msg = JSON.stringify({ type: type, payload: payload === undefined ? null : payload });
  try {
    if (window.PcvBridge && typeof window.PcvBridge.postMessage === 'function') {
      window.PcvBridge.postMessage(msg);
      return;
    }
  } catch (e) { /* 忽略 */ }
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
    // 轻量事件：只通知"有改动"。正文由 Flutter 侧按需拉取（getContent）——
    // 避免大文件每次输入都经消息通道传输全文。
    call('changed', { dirty: 1, lines: view.state.doc.lines });
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

// ============ 语法检查（@codemirror/lint 官方生态——基于 lezer 解析树） ============
// 检查项：①解析错误（lezer error 节点——覆盖全部已支持语言）
//         ②JSON 完整性（JSON.parse）③括号/引号配对由 bracketMatching 实时提供
function lintDoc(view) {
  const diagnostics = [];
  const doc = view.state.doc;
  // 超大文件保护：>200KB 跳过解析扫描（手机性能优先）
  if (doc.length > 200000) return diagnostics;
  // ① 解析错误（lezer 语法树中的 error 节点）
  syntaxTree(view.state).cursor().iterate((node) => {
    if (node.type.isError && node.to > node.from) {
      diagnostics.push({
        from: node.from,
        to: Math.min(node.to, node.from + 200),
        severity: 'error',
        message: '语法错误（解析器报告）',
      });
    } else if (node.type.isError) {
      diagnostics.push({
        from: node.from,
        to: Math.min(doc.length, node.from + 1),
        severity: 'error',
        message: '语法错误（解析器报告）',
      });
    }
  });
  // ② JSON 完整性检查
  const path = currentPath || '';
  if (/\.json$/i.test(path) && doc.length < 400000) {
    try {
      JSON.parse(doc.toString());
    } catch (e) {
      const msg = String((e && e.message) || 'JSON 格式错误');
      let pos = 0;
      const m = /position (\d+)/.exec(msg);
      if (m) pos = Math.min(+m[1], doc.length);
      diagnostics.push({
        from: Math.max(0, pos - 1),
        to: Math.min(doc.length, pos + 1),
        severity: 'error',
        message: 'JSON：' + msg,
      });
    }
  }
  // 去重（同一位置只留一条）
  const seen = new Set();
  return diagnostics.filter((d) => {
    const k = d.from + ':' + d.to + ':' + d.message;
    if (seen.has(k)) return false;
    seen.add(k);
    return true;
  }).slice(0, 60);
}

// ============ 双拇指手势（手机端便利——先生要求） ============
// ① 双指捏合：调整字号（10–24px）
// ② 双指水平横滑：缩进 / 反缩进（选中行或当前行）
function touchDist(t) {
  const dx = t[0].clientX - t[1].clientX;
  const dy = t[0].clientY - t[1].clientY;
  return Math.sqrt(dx * dx + dy * dy);
}
function touchAvg(t) {
  return [(t[0].clientX + t[1].clientX) / 2, (t[0].clientY + t[1].clientY) / 2];
}

let pinch = null;
function installGestures(dom) {
  dom.addEventListener('touchstart', (e) => {
    if (e.touches.length === 2) {
      pinch = {
        d0: touchDist(e.touches),
        font0: currentFont,
        x0: touchAvg(e.touches)[0],
        y0: touchAvg(e.touches)[1],
        mode: null, // 'zoom' | 'indent'
      };
    } else {
      pinch = null;
    }
  }, { passive: true });

  dom.addEventListener('touchmove', (e) => {
    if (!pinch || e.touches.length !== 2) return;
    e.preventDefault(); // 双指期间独占手势
    const d = touchDist(e.touches);
    const [ax, ay] = touchAvg(e.touches);
    const dxTotal = ax - pinch.x0;
    const dyTotal = ay - pinch.y0;
    // 判定主意图（只判一次）
    if (!pinch.mode) {
      const zoomDelta = Math.abs(d - pinch.d0);
      const horizDelta = Math.abs(dxTotal);
      if (zoomDelta > 14) {
        pinch.mode = 'zoom';
      } else if (horizDelta > 46 && Math.abs(dyTotal) < 36) {
        pinch.mode = 'indent';
        applyIndentGesture(dxTotal > 0);
        pinch.x0 = ax; // 重置基线（允许连续档位触发）
      } else {
        return;
      }
    }
    if (pinch.mode === 'zoom') {
      const ratio = d / pinch.d0;
      const nf = Math.max(10, Math.min(24, Math.round(pinch.font0 * ratio)));
      if (nf !== currentFont) {
        applyFontSize(nf);
        call('fontChanged', { fontPx: nf });
      }
    } else if (pinch.mode === 'indent') {
      const step = ax - pinch.x0;
      if (Math.abs(step) > 56) {
        applyIndentGesture(step > 0);
        pinch.x0 = ax;
      }
    }
  }, { passive: false });

  dom.addEventListener('touchend', (e) => {
    if (e.touches.length < 2) pinch = null;
  }, { passive: true });
}

function applyIndentGesture(forward) {
  if (!view) return;
  view.focus();
  if (forward) {
    indentMore(view);
  } else {
    indentLess(view);
  }
  call('indentDone', { dir: forward ? 'more' : 'less' });
}

function applyFontSize(px) {
  currentFont = px;
  if (view) {
    view.dispatch({ effects: themeComp.reconfigure(themeBundle(currentDark, currentFont)) });
  }
}
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
    lintGutter(),
    linter(lintDoc, { delay: 500 }),
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
    applyFontSize(Math.max(10, Math.min(24, +px || 14)));
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
installGestures(view.dom);
document.body.style.background = DARK_UI.bg;
call('ready', {});
