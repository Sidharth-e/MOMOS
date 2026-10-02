#!/usr/bin/env bash
#
# The Markdown renderer in scripts/ui/index.html, exercised for real.
#
# A hand-written parser is the one part of the page that cannot be checked by
# looking at it: the failures it has are off-by-one ones — a fence that does not
# close, a link whose scheme is not checked, a text node that becomes markup —
# and every one of them is invisible until a model happens to emit the shape
# that trips it.
#
# So the renderer sits between `--- markdown:begin ---` and `--- markdown:end ---`
# and takes the element factory it builds through (createElement/createTextNode)
# as a parameter rather than reaching for a global. That makes it runnable under
# node against a factory that makes plain objects, and it means the same
# renderer can be checked here as is served to the phone.
#
# Node is a development-machine convenience, not something the phone needs, so a
# missing node is a skip rather than a failure.
#
# Run: bash tests/test-ui-markdown.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UI_HTML="$REPO_ROOT/scripts/ui/index.html"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf '  \033[0;32mPASS\033[0m  %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  \033[0;31mFAIL\033[0m  %s\n' "$1"; }

section() { printf '\n\033[1m%s\033[0m\n' "$1"; }

if ! command -v node >/dev/null 2>&1; then
    printf '\n\033[0;33mnode is not installed — skipping the markdown tests.\033[0m\n\n'
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ---------------------------------------------------------------------------

section "the page's markdown block is extractable"

MD_JS="$TMP/markdown.js"
sed -n '/\/\/ --- markdown:begin ---/,/\/\/ --- markdown:end ---/p' "$UI_HTML" > "$MD_JS"

if [ -s "$MD_JS" ]; then
    pass "index.html has a markdown block"
else
    fail "index.html is missing the '--- markdown:begin ---' / '--- markdown:end ---' markers"
    printf '\n  \033[0;31mCannot continue without the block.\033[0m\n\n'
    exit 1
fi

# The block is run outside a browser, so reaching for a global would only fail
# here — a long way from the edit that caused it. Comments are stripped first,
# because the block's own prose talks about the rule it follows.
CODE_ONLY="$(sed -e 's://.*::' "$MD_JS" | grep -vE '^[[:space:]]*$')"

if grep -qE '\b(document|window|fetch|localStorage)\b' <<< "$CODE_ONLY"; then
    fail "the markdown block reaches for a global — it must take the element factory as a parameter"
    grep -nE '\b(document|window|fetch|localStorage)\b' <<< "$CODE_ONLY" | sed 's/^/        /'
else
    pass "the markdown block is free of document, window, fetch and localStorage"
fi

# Model output is the least trusted text on the page. Building it as elements is
# what makes escaping structural instead of a regex that has to be right every
# time; an innerHTML anywhere in this file undoes that in one line.
if grep -q 'innerHTML' "$UI_HTML"; then
    fail "index.html uses innerHTML — model output must go in as text nodes"
    grep -n 'innerHTML' "$UI_HTML" | sed 's/^/        /'
else
    pass "index.html builds no markup from a string"
fi

# ---------------------------------------------------------------------------

cat > "$TMP/stub.js" <<'STUB'
// An element factory shaped like the two methods the renderer is allowed to
// use, producing plain objects rather than anything that needs a browser.
function Node(tag, text) {
  this.tagName = tag ? String(tag).toUpperCase() : '#text';
  this.text = tag ? null : String(text);
  this.children = [];
  this.attrs = {};
  this.className = '';
  this.style = {};
  this.disabled = false;
  this.checked = false;
}

Node.prototype.appendChild = function (child) {
  this.children.push(child);
  return child;
};

Node.prototype.setAttribute = function (k, v) { this.attrs[k] = String(v); };

var mk = {
  createElement: function (tag) { return new Node(tag); },
  createTextNode: function (text) { return new Node(null, text); }
};

// ---- reading the result back ----------------------------------------------

function render(md) { return mdToDom(md, mk); }
function textOf(md) { return allText(render(md)); }

function allText(n) {
  if (n.tagName === '#text') return n.text;
  return n.children.map(allText).join('');
}

// Direct children, optionally of one tag.
function kids(n, tag) {
  return n.children.filter(function (c) {
    return !tag || c.tagName === String(tag).toUpperCase();
  });
}

// Every descendant of one tag, in document order.
function find(n, tag) {
  var want = String(tag).toUpperCase();
  var out = [];
  (function walk(x) {
    x.children.forEach(function (c) {
      if (c.tagName === want) out.push(c);
      walk(c);
    });
  })(n);
  return out;
}

function byClass(n, cls) {
  var out = [];
  (function walk(x) {
    if (String(x.className || '').split(' ').indexOf(cls) !== -1) out.push(x);
    x.children.forEach(walk);
  })(n);
  return out;
}

// The href the first anchor actually carries, or null when it was refused.
function hrefOf(md) {
  var a = find(render(md), 'a')[0];
  if (!a) return null;
  return Object.prototype.hasOwnProperty.call(a.attrs, 'href') ? a.attrs.href : null;
}

var PASSED = 0;
var FAILED = 0;

function ok(name, cond, detail) {
  if (cond) { PASSED++; console.log('ok ' + name); }
  else { FAILED++; console.log('not ok ' + name + (detail ? ' — ' + detail : '')); }
}

function eq(name, actual, expected) {
  ok(name, JSON.stringify(actual) === JSON.stringify(expected),
     'got ' + JSON.stringify(actual) + ', expected ' + JSON.stringify(expected));
}
STUB

cat > "$TMP/tests.js" <<'TESTS'

// ---- the text that ends up on screen ---------------------------------------

eq('an empty document renders nothing', textOf(''), '');
eq('null renders nothing', textOf(null), '');
eq('a plain sentence is its own text', textOf('a tensor is an array'), 'a tensor is an array');
eq('a partial sentence is its own text', textOf('a tensor is'), 'a tensor is');
// The page re-renders on every streamed chunk, so a fragment that is not yet
// valid Markdown still has to come back character for character.
eq('an unfinished fence keeps its text', textOf('```python\nbase = 1'), 'base = 1');
eq('an unfinished list keeps its text', textOf('- one\n- two'), 'onetwo');
eq('an unfinished table keeps its text', textOf('| a | b |\n|---|'), 'ab');
eq('a line with pipes and no delimiter is just a line', textOf('| a | b'), '| a | b');

// ---- the page is not a scripting surface -----------------------------------

eq('angle brackets stay text', textOf('<script>alert(1)</script>'),
   '<script>alert(1)</script>');
eq('an ampersand stays an ampersand', textOf('a & b'), 'a & b');
eq('an image is never fetched, and shows as a link',
   hrefOf('![cat](http://example.com/cat.png)'), 'http://example.com/cat.png');
eq('and its alt text is what is written on it',
   textOf('![a diagram](http://example.com/d.png)'), 'a diagram');
// Nothing to point at, so nothing to link to: the source is shown instead of
// a link that goes nowhere.
eq('an image with no target shows as its source', textOf('![]()'), '![]()');

// ---- links -----------------------------------------------------------------

eq('a web link keeps its href', hrefOf('[docs](https://example.com/x)'), 'https://example.com/x');
eq('an http link is allowed', hrefOf('[x](http://example.com)'), 'http://example.com');
eq('a mailto link is allowed', hrefOf('[mail](mailto:a@b.com)'), 'mailto:a@b.com');
eq('a fragment is allowed', hrefOf('[top](#top)'), '#top');
eq('the link text is shown', textOf('[docs](https://example.com)'), 'docs');

// The whole point of the check. A model can be talked into emitting any of
// these, and a page that renders one has handed over the browser.
eq('javascript: is refused', hrefOf('[x](javascript:alert(1))'), null);
eq('JaVaScRiPt: is refused too', hrefOf('[x](JaVaScRiPt:alert(1))'), null);
eq('data: is refused', hrefOf('[x](data:text/html;base64,PHNjcmlwdD4=)'), null);
eq('vbscript: is refused', hrefOf('[x](vbscript:msgbox)'), null);
eq('a protocol-relative link is refused', hrefOf('[x](//evil.example.com)'), null);
// A scheme split by a control character is the same scheme once a browser reads
// it; stripping those first is what makes the check above hold.
eq('a scheme split by a newline is refused', hrefOf('[x](java\nscript:alert(1))'), null);
eq('a scheme split by a tab is refused', hrefOf('[x](java\tscript:alert(1))'), null);
// A backslash reads as a slash to a browser, so "/\host" is the same address as
// "//host" — the form refused above. Normalising it before that check is what
// keeps the refusal about where a link goes rather than how it is spelled.
eq('a backslash cannot smuggle a protocol-relative link',
   hrefOf('[x](/\\evil.example.com)'), null);
eq('a doubled backslash is refused too', hrefOf('[x](\\\\evil.example.com)'), null);
eq('a refused link still shows what was written', textOf('[x](javascript:alert(1))'),
   'x (javascript:alert(1))');
eq('an angle-bracket autolink works', hrefOf('<https://example.com>'), 'https://example.com');
eq('a bare url becomes a link', hrefOf('see https://example.com/x now'), 'https://example.com/x');
eq('and its trailing full stop is not part of it',
   hrefOf('see https://example.com/x.'), 'https://example.com/x');
eq('and the words around it survive', textOf('see https://example.com now'),
   'see https://example.com now');

// ---- emphasis --------------------------------------------------------------

eq('bold', find(render('**heavy**'), 'strong').length, 1);
eq('bold keeps its text', textOf('**heavy**'), 'heavy');
eq('italic', find(render('*light*'), 'em').length, 1);
eq('strikethrough', find(render('~~gone~~'), 'del').length, 1);
eq('underscore bold', find(render('__heavy__'), 'strong').length, 1);
eq('underscore italic', find(render('_light_'), 'em').length, 1);
eq('nesting', textOf('**a *b* c**'), 'a b c');
eq('a lone asterisk is just an asterisk', textOf('2 * 3 = 6'), '2 * 3 = 6');
eq('an unclosed marker is literal', textOf('**dangling'), '**dangling');
// Underscores inside a word are snake_case, not emphasis — the commonest way a
// renderer mangles code that was written as prose.
eq('snake_case is left alone', find(render('call max_tokens now'), 'em').length, 0);
eq('and keeps its underscores', textOf('call max_tokens now'), 'call max_tokens now');

// ---- inline code -----------------------------------------------------------

eq('inline code', find(render('`x = 1`'), 'code').length, 1);
eq('inline code keeps its text', textOf('`max_tokens`'), 'max_tokens');
eq('markup inside code is not markup', find(render('`**not bold**`'), 'strong').length, 0);
eq('and stays as written', textOf('`**not bold**`'), '**not bold**');
eq('a backtick pair in prose is not code', find(render('a ` b'), 'code').length, 0);

// ---- block structure -------------------------------------------------------

eq('a paragraph', kids(render('hello'), 'p').length, 1);
eq('two paragraphs', kids(render('one\n\ntwo'), 'p').length, 2);
eq('a blank line ends a paragraph', kids(render('a\n\n\n\nb'), 'p').length, 2);

eq('h1', kids(render('# Title'), 'h1').length, 1);
eq('h3', kids(render('### Title'), 'h3').length, 1);
eq('a heading keeps its text', textOf('## Sub heading'), 'Sub heading');
eq('a closing hash run is not part of the heading', textOf('## Sub ##'), 'Sub');
eq('a hash without a space is not a heading', kids(render('#hashtag'), 'h1').length, 0);
eq('and stays as text', textOf('#hashtag'), '#hashtag');
eq('seven hashes is not a heading', kids(render('####### x'), 'h7').length, 0);

eq('a rule', kids(render('---'), 'hr').length, 1);
eq('a spaced rule', kids(render('- - -'), 'hr').length, 1);
eq('a star rule', kids(render('***'), 'hr').length, 1);
eq('a rule is not a list', kids(render('---'), 'ul').length, 0);

eq('a quote', kids(render('> quoted'), 'blockquote').length, 1);
eq('a quote keeps its text', textOf('> quoted'), 'quoted');
eq('a quote can hold a paragraph', kids(find(render('> quoted'), 'blockquote')[0], 'p').length, 1);
eq('a quote of two lines is one quote', kids(render('> one\n> two'), 'blockquote').length, 1);

// ---- code blocks -----------------------------------------------------------

eq('a fence is a pre', kids(render('```\nx = 1\n```'), 'pre').length, 1);
eq('a fenced block keeps its text', textOf('```\nx = 1\n```'), 'x = 1');
eq('a fenced block keeps its lines', textOf('```\na\nb\n```'), 'a\nb');
eq('a language is carried for the label',
   kids(render('```python\nx = 1\n```'), 'pre')[0].attrs['data-lang'], 'python');
eq('no language means no label',
   kids(render('```\nx\n```'), 'pre')[0].attrs['data-lang'], undefined);
eq('markdown inside a fence is not markdown', find(render('```\n**x**\n```'), 'strong').length, 0);
eq('a tilde fence works', kids(render('~~~\nx\n~~~'), 'pre').length, 1);
eq('a blank line inside a fence survives', textOf('```\na\n\nb\n```'), 'a\n\nb');
eq('an unterminated fence takes the rest', kids(render('```\na\nb'), 'pre').length, 1);
eq('a different fence does not close it', kids(render('```\na\n~~~\nb\n```'), 'pre').length, 1);
eq('and that content is kept', textOf('```\na\n~~~\nb\n```'), 'a\n~~~\nb');

// ---- lists -----------------------------------------------------------------

eq('a bullet list', kids(render('- one\n- two'), 'ul').length, 1);
eq('with two items', find(render('- one\n- two'), 'li').length, 2);
eq('item text', textOf('- one\n- two'), 'onetwo');
eq('a star bullet', kids(render('* one'), 'ul').length, 1);
eq('a numbered list', kids(render('1. one\n2. two'), 'ol').length, 1);
eq('numbered item text', textOf('1. one\n2. two'), 'onetwo');
eq('a paren marker works', kids(render('1) one'), 'ol').length, 1);
eq('a list starting above one says where it starts',
   kids(render('3. three'), 'ol')[0].attrs.start, '3');
eq('a list starting at one says nothing',
   kids(render('1. one'), 'ol')[0].attrs.start, undefined);
eq('a nested list is inside its parent item',
   kids(find(render('- a\n  - b'), 'li')[0], 'ul').length, 1);
eq('a nested list keeps its text', textOf('- a\n  - b'), 'ab');
eq('a wrapped item stays one item', find(render('- a\n  continued'), 'li').length, 1);
eq('and keeps its text', textOf('- a\n  continued'), 'acontinued');
eq('markdown inside an item works', find(render('- **bold**'), 'strong').length, 1);

// Task lists: the checkbox is an element, so the text is still just the text.
eq('a task list', find(render('- [ ] todo'), 'input').length, 1);
eq('a checked task is checked', find(render('- [x] done'), 'input')[0].checked, true);
eq('an unchecked task is not', find(render('- [ ] todo'), 'input')[0].checked, false);
eq('a checkbox is not interactive', find(render('- [ ] todo'), 'input')[0].disabled, true);
eq('a task keeps only its text', textOf('- [x] done'), 'done');
eq('a task inside a numbered list is not a task',
   find(render('1. [ ] x'), 'input').length, 0);

// ---- tables ----------------------------------------------------------------

var table = render('| a | b |\n|---|---|\n| 1 | 2 |');
eq('a table', kids(table, 'table').length, 1);
eq('with a header row', find(table, 'th').length, 2);
eq('with a body row', find(table, 'td').length, 2);
eq('header text', allText(find(table, 'th')[0]), 'a');
eq('body text', allText(find(table, 'td')[0]), '1');
eq('a table does not also become a paragraph', find(table, 'p').length, 0);

var aligned = render('| a | b | c |\n|:--|:-:|--:|\n| 1 | 2 | 3 |');
eq('left stays default', find(aligned, 'th')[0].style.textAlign, undefined);
eq('centre is centred', find(aligned, 'th')[1].style.textAlign, 'center');
eq('right is right', find(aligned, 'th')[2].style.textAlign, 'right');
eq('alignment follows to the body', find(aligned, 'td')[2].style.textAlign, 'right');

eq('a raggedy row is padded out',
   find(render('| a | b |\n|---|---|\n| 1 |'), 'td').length, 2);
eq('a row with no pipes is not a table', kids(render('hello'), 'table').length, 0);
eq('a pipe in prose is not a table', kids(render('a | b'), 'table').length, 0);

// ---- formatting inside blocks ----------------------------------------------

eq('bold inside a heading', find(render('## a **b**'), 'strong').length, 1);
eq('a link inside a list item',
   hrefOf('- see [docs](https://example.com)'), 'https://example.com');
eq('a code span inside a quote', find(render('> `x`'), 'code').length, 1);

// ---- line breaks -----------------------------------------------------------
// A single newline is a break, not a space: models write line-oriented answers,
// and a space would run two lines together in the middle of a sentence.
eq('a newline in a paragraph is a break', find(render('one\ntwo'), 'br').length, 1);
eq('a blank line is not a break', find(render('one\n\ntwo'), 'br').length, 0);

console.log('');
console.log('#' + (FAILED === 0 ? ' all ' + PASSED + ' assertions passed' :
                              ' ' + FAILED + ' of ' + (PASSED + FAILED) + ' failed'));
TESTS

cat "$TMP/stub.js" "$MD_JS" "$TMP/tests.js" > "$TMP/run.js"

section "markdown rendering (node)"

OUT="$(node "$TMP/run.js" 2>&1)"
NODE_STATUS=$?

if [ "$NODE_STATUS" -ne 0 ] && [ -z "$OUT" ]; then
    fail "node produced no output (exit $NODE_STATUS)"
else
    while IFS= read -r line; do
        case "$line" in
            "ok "*)     pass "${line#ok }" ;;
            "not ok "*) fail "${line#not ok }" ;;
            "#"*)       : ;;   # the node-side summary line
            "")         : ;;
            *)          printf '        %s\n' "$line" ;;
        esac
    done <<< "$OUT"
fi

# ---------------------------------------------------------------------------

printf '\n\033[1m%s\033[0m\n' "────────────────────────────────"
printf '  \033[0;32m%d passed\033[0m' "$PASS"
if [ "$FAIL" -gt 0 ]; then
    printf ', \033[0;31m%d failed\033[0m' "$FAIL"
fi
printf '\n\n'

[ "$FAIL" -eq 0 ]
