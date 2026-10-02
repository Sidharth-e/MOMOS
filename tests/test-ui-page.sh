#!/usr/bin/env bash
#
# The behaviour of scripts/ui/index.html, driven for real.
#
# tests/test-native-migration.sh greps the page for the strings it must contain,
# and tests/test-ui-store.sh exercises the store block in isolation. Neither can
# tell you whether sending a message files the reply under the right chat, or
# whether a reload brings the conversation back — and there is no browser on the
# build machine to ask.
#
# So the page's own script is run under node against a small hand-written DOM:
# enough of document, localStorage, fetch and AbortController for the page to
# believe it is in a browser. No dependencies, because the repo has none.
#
# Run: bash tests/test-ui-page.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UI_HTML="$REPO_ROOT/scripts/ui/index.html"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf '  \033[0;32mPASS\033[0m  %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  \033[0;31mFAIL\033[0m  %s\n' "$1"; }

section() { printf '\n\033[1m%s\033[0m\n' "$1"; }

if ! command -v node >/dev/null 2>&1; then
    printf '\n\033[0;33mnode is not installed — skipping the page tests.\033[0m\n\n'
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# The page's script, extracted as it is served. The tags are indented, so the
# closing one cannot be matched from the start of the line.
awk '/<script>/{f=1;next} /<\/script>/{f=0} f' "$UI_HTML" > "$TMP/page.js"

if [ ! -s "$TMP/page.js" ]; then
    fail "could not extract the script from index.html"
    exit 1
fi

# ---------------------------------------------------------------------------

cat > "$TMP/dom.js" <<'DOM'
var fs = require('fs');
var vm = require('vm');

// ---- just enough DOM -------------------------------------------------------

function El(tag) {
  this.tagName = tag ? String(tag).toUpperCase() : '#text';
  this.childNodes = [];
  this.parentNode = null;
  this._text = tag ? null : '';   // elements hold text in their children
  this.attrs = {};
  this.handlers = {};
  this.style = {};
  this.className = '';
  this.hidden = false;
  this.disabled = false;
  this.value = '';
  this.title = '';
  this.type = '';
  this.id = '';
  this.scrollHeight = 20;
}

function textOf(node) {
  if (node._text !== null) return node._text;
  return node.childNodes.map(textOf).join('');
}

Object.defineProperty(El.prototype, 'firstChild', {
  get: function () { return this.childNodes.length ? this.childNodes[0] : null; }
});

Object.defineProperty(El.prototype, 'options', {
  get: function () {
    return this.childNodes.filter(function (c) { return c.tagName === 'OPTION'; });
  }
});

Object.defineProperty(El.prototype, 'textContent', {
  get: function () { return textOf(this); },
  set: function (v) {
    this.childNodes.forEach(function (c) { c.parentNode = null; });
    this.childNodes = [];
    if (v !== '') {
      var t = new El(null);
      t._text = String(v);
      t.parentNode = this;
      this.childNodes.push(t);
    }
  }
});

El.prototype.appendChild = function (child) {
  if (child.parentNode) child.parentNode.removeChild(child);
  child.parentNode = this;
  this.childNodes.push(child);
  return child;
};

El.prototype.removeChild = function (child) {
  var i = this.childNodes.indexOf(child);
  if (i !== -1) { this.childNodes.splice(i, 1); child.parentNode = null; }
  return child;
};

El.prototype.insertBefore = function (node, ref) {
  if (node.parentNode) node.parentNode.removeChild(node);
  var i = ref ? this.childNodes.indexOf(ref) : -1;
  if (i === -1) this.childNodes.push(node); else this.childNodes.splice(i, 0, node);
  node.parentNode = this;
  return node;
};

El.prototype.setAttribute = function (k, v) { this.attrs[k] = String(v); };

El.prototype.getAttribute = function (k) {
  return Object.prototype.hasOwnProperty.call(this.attrs, k) ? this.attrs[k] : null;
};

El.prototype.addEventListener = function (t, fn) {
  (this.handlers[t] = this.handlers[t] || []).push(fn);
};

El.prototype.fire = function (t, ev) {
  var e = ev || { preventDefault: function () {} };
  (this.handlers[t] || []).forEach(function (fn) { fn(e); });
};

El.prototype.focus = function () { this.focused = true; };

El.prototype.scrollIntoView = function () {};

El.prototype.getElementsByTagName = function (tag) {
  var want = String(tag).toUpperCase();
  var out = [];
  (function walk(n) {
    n.childNodes.forEach(function (c) {
      if (c.tagName === want) out.push(c);
      walk(c);
    });
  })(this);
  return out;
};

function makeDocument() {
  var byId = {};
  var doc = {
    handlers: {},
    getElementById: function (id) {
      if (!byId[id]) { byId[id] = new El('div'); byId[id].id = id; }
      return byId[id];
    },
    createElement: function (tag) { return new El(tag); },
    createTextNode: function (t) { var n = new El(null); n._text = String(t); return n; },
    addEventListener: function (t, fn) {
      (doc.handlers[t] = doc.handlers[t] || []).push(fn);
    },
    fire: function (t, ev) {
      (doc.handlers[t] || []).forEach(function (fn) { fn(ev || {}); });
    }
  };
  return doc;
}

// ---- a localStorage with the two ways it fails -----------------------------

function makeStorage(mem, refusing) {
  return {
    setItem: function (k, v) {
      if (refusing) throw new Error('QuotaExceededError');
      mem[k] = String(v);
    },
    getItem: function (k) {
      return Object.prototype.hasOwnProperty.call(mem, k) ? mem[k] : null;
    },
    removeItem: function (k) { delete mem[k]; }
  };
}

// ---- a fetch that answers the page's three requests ------------------------

function jsonRes(obj) {
  return { ok: true, json: function () { return Promise.resolve(obj); } };
}

function abortError() {
  var e = new Error('aborted');
  e.name = 'AbortError';
  return e;
}

function streamRes(lines, signal, state) {
  var i = 0;
  var enc = new TextEncoder();
  return {
    ok: true,
    body: {
      getReader: function () {
        return {
          read: function () {
            if (signal && signal.aborted) return Promise.reject(abortError());
            if (i < lines.length) {
              return Promise.resolve({ done: false, value: enc.encode(lines[i++] + '\n') });
            }
            // A reply that never finishes, so a test can stop it mid-flight.
            if (state.hang) {
              return new Promise(function (_, reject) {
                if (signal) signal.addEventListener('abort', function () { reject(abortError()); });
              });
            }
            return Promise.resolve({ done: true });
          }
        };
      }
    }
  };
}

function makeFetch(state) {
  return function (url, opts) {
    if (url === 'runtime.json') return Promise.resolve(jsonRes(state.config));
    if (/\/api\/tags$/.test(url)) {
      if (state.tagsFails) return Promise.reject(new TypeError('Failed to fetch'));
      return Promise.resolve(jsonRes({
        models: state.models.map(function (n) { return { name: n }; })
      }));
    }
    if (/\/api\/chat$/.test(url)) {
      var body = JSON.parse(opts.body);
      state.requests.push(body);
      return Promise.resolve(streamRes(state.reply(body), opts.signal, state));
    }
    return Promise.reject(new Error('unexpected fetch: ' + url));
  };
}

// ---- running the page ------------------------------------------------------

var PAGE = fs.readFileSync(process.argv[2], 'utf8');
var INTRINSICS = ['Math', 'Date', 'JSON', 'Promise', 'Error', 'TypeError',
                  'String', 'Number', 'Object', 'Array', 'Boolean', 'isFinite',
                  'RegExp', 'parseInt'];

// Date.now() pinned to `ms`, while `new Date(x)` still builds real dates — the
// page formats stamps with it. Called with or without `new`, it hands back a
// real Date either way.
function frozenDate(ms) {
  var RealDate = Date;
  function Frozen(a) {
    return arguments.length ? new RealDate(a) : new RealDate(ms);
  }
  Frozen.now = function () { return ms; };
  Frozen.parse = RealDate.parse;
  Frozen.UTC = RealDate.UTC;
  Frozen.prototype = RealDate.prototype;
  return Frozen;
}

function makeEnv(opts) {
  opts = opts || {};

  var state = {
    config: opts.config === undefined
      ? { model: 'llama3.2:3b', ollama_port: 11434 }
      : opts.config,
    models: opts.models || ['qwen2.5:7b', 'llama3.2:3b', 'deepseek-r1:8b'],
    tagsFails: !!opts.tagsFails,
    hang: false,
    requests: [],
    reply: opts.reply || function () {
      return ['{"message":{"content":"a tensor is an array"}}', '{"done":true}'];
    }
  };

  var mem = opts.mem || {};
  var doc = makeDocument();
  var env = {
    mem: mem,
    state: state,
    document: doc,
    confirmResult: true,
    storage: makeStorage(mem, opts.refusingStorage)
  };

  env.window = {
    localStorage: env.storage,
    confirm: function () { return !!env.confirmResult; },
    innerHeight: 800
  };
  env.location = { hostname: 'localhost' };
  env.fetch = makeFetch(state);

  var sandbox = {
    document: doc,
    window: env.window,
    location: env.location,
    fetch: env.fetch,
    AbortController: AbortController,
    TextDecoder: TextDecoder,
    TextEncoder: TextEncoder,
    console: console,
    setTimeout: setTimeout,
    setImmediate: setImmediate
  };
  INTRINSICS.forEach(function (k) { sandbox[k] = globalThis[k]; });

  // A clock that never moves. Two chats touched inside one millisecond carry
  // the same stamp, and the page has to keep them in recency order anyway — a
  // race that turns up on its own only every few runs is a race that gets
  // written back in. Freezing the clock makes that tie happen every run.
  if (opts.frozenClock !== undefined) sandbox.Date = frozenDate(opts.frozenClock);

  vm.createContext(sandbox);
  // The page's script runs exactly as served. A throw here is a real failure,
  // not a harness problem, so it is left to surface.
  vm.runInContext(PAGE, sandbox);
  return env;
}

function tick() { return new Promise(function (r) { setImmediate(r); }); }

async function settle() {
  for (var i = 0; i < 10; i++) await tick();
}

// ---- reading the page ------------------------------------------------------

function el(env, id) { return env.document.getElementById(id); }
// Saved data, or an empty store when nothing was written. Returning an empty
// store rather than throwing means a page that has stopped saving fails the
// assertions about saving, instead of killing the run at the first one and
// hiding every check after it.
function store(env) {
  var raw = env.mem['momos.sessions.v1'];
  if (!raw) return { current: null, sessions: [] };
  return JSON.parse(raw);
}
// A stand-in so an assertion about a chat that was not saved reads as a failed
// assertion rather than a TypeError that ends the run.
function emptyChat(title) {
  return { id: null, title: title, model: null, messages: [] };
}

function newestChat(env) {
  var all = store(env).sessions;
  return all.length ? all[0] : emptyChat(null);
}

function savedChat(env, title) {
  var all = store(env).sessions.filter(function (s) { return s.title === title; });
  return all.length ? all[0] : emptyChat(title);
}

function rows(env) { return el(env, 'chat-list').childNodes; }
function rowText(env, i) { return row(env, i).childNodes[0].textContent; }
// A row that is not there cannot be clicked, but clicking nothing should not
// end the run either — every assertion after it is still worth making.
function row(env, i) {
  if (rows(env)[i]) return rows(env)[i];
  var stub = new El('li');
  stub.appendChild(new El('button'));
  stub.appendChild(new El('button'));
  return stub;
}

function rowDelete(env, i) { return row(env, i).childNodes[1]; }
function logText(env) { return el(env, 'log').textContent; }
function modelValue(env) { return el(env, 'model').value; }
function modelLabels(env) {
  return el(env, 'model').options.map(function (o) { return o.textContent; });
}
function bannerText(env) { return el(env, 'banner').hidden ? '' : el(env, 'banner').textContent; }

function sendText(env, text) {
  el(env, 'prompt').value = text;
  el(env, 'composer').fire('submit');
}

function countClass(node, cls) {
  var n = 0;
  (function walk(x) {
    var names = String(x.className || '').split(' ');
    if (names.indexOf(cls) !== -1) n++;
    (x.childNodes || []).forEach(walk);
  })(node);
  return n;
}

// ---- assertions ------------------------------------------------------------

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

function includes(name, haystack, needle) {
  ok(name, String(haystack).indexOf(needle) !== -1,
     JSON.stringify(String(haystack).slice(0, 300)) + ' has no ' + JSON.stringify(needle));
}

function excludes(name, haystack, needle) {
  ok(name, String(haystack).indexOf(needle) === -1,
     JSON.stringify(String(haystack).slice(0, 300)) + ' contains ' + JSON.stringify(needle));
}
DOM

# ---------------------------------------------------------------------------

cat > "$TMP/scenarios.js" <<'SCENARIOS'

async function main() {

// ---- a fresh page ----------------------------------------------------------

var env = makeEnv();
await settle();

eq('the picker offers what the phone has installed', modelLabels(env),
   ['deepseek-r1:8b', 'llama3.2:3b', 'qwen2.5:7b']);
eq('the picker opens on the model runtime.json recorded', modelValue(env), 'llama3.2:3b');
eq('an empty chat list says so', el(env, 'chats-empty').hidden, false);
eq('nothing is warned about on a healthy page', bannerText(env), '');
eq('the composer is ready', el(env, 'send').disabled, false);
eq('the page asks Ollama and nothing else', env.state.requests.length, 0);

// ---- the model list is a nicety, not a prerequisite ------------------------

var noTags = makeEnv({ tagsFails: true });
await settle();

includes('a model list that cannot be fetched is said out loud',
         bannerText(noTags), 'Could not list the models');
eq('the picker still names the model from runtime.json',
   modelLabels(noTags), ['llama3.2:3b']);
eq('and chat still works', el(noTags, 'send').disabled, false);

// ---- the first message starts a chat ---------------------------------------

sendText(env, 'what is a tensor');
includes('the question is on screen', logText(env), 'what is a tensor');
eq('the question is asked of the chosen model', env.state.requests[0].model, 'llama3.2:3b');
eq('the request carries just the question', env.state.requests[0].messages,
   [{ role: 'user', content: 'what is a tensor' }]);

await settle();

includes('the reply is on screen', logText(env), 'a tensor is an array');
eq('the chat list has one row', rows(env).length, 1);
eq('the row is named after the question', rowText(env, 0), 'what is a tensor');
eq('the open row says so', row(env, 0).childNodes[0].getAttribute('aria-current'), 'true');
eq('the chat is saved with both turns', newestChat(env).messages,
   [{ role: 'user', content: 'what is a tensor' },
    { role: 'assistant', content: 'a tensor is an array' }]);
ok('the chat records the model that answered',
   newestChat(env).model === 'llama3.2:3b', newestChat(env).model);
eq('the saved chat is the open one', store(env).current, newestChat(env).id);
eq('the empty-chat line is gone', el(env, 'chats-empty').hidden, true);

// A second turn continues the same chat rather than starting another.
sendText(env, 'and a vector');
await settle();
eq('a second question does not start a second chat', rows(env).length, 1);
// Both turns of the first exchange, plus the question just asked. The reply to
// this one does not exist yet, so it cannot be in the body.
eq('the second request carries the whole conversation',
   env.state.requests[1].messages.length, 3);

// ---- a second chat ---------------------------------------------------------

el(env, 'new-chat').fire('click');
eq('a new chat clears the screen', logText(env), '');
eq('a new chat keeps the model you were using', modelValue(env), 'llama3.2:3b');
eq('a new chat with nothing typed in it adds no row', rows(env).length, 1);

sendText(env, 'what is a vector');
await settle();

eq('there are two chats now', rows(env).length, 2);
eq('the newer chat is at the top', rowText(env, 0), 'what is a vector');
eq('the older chat is below it', rowText(env, 1), 'what is a tensor');
eq('the newer chat is the open one', store(env).current, newestChat(env).id);
eq('both chats are saved', store(env).sessions.length, 2);

// ---- a reload --------------------------------------------------------------

var reloaded = makeEnv({ mem: env.mem });
await settle();

eq('a reload brings the chats back', rows(reloaded).length, 2);
includes('a reload reopens the chat you left off in',
         logText(reloaded), 'what is a vector');
includes('and shows the answer that was in it', logText(reloaded), 'a tensor is an array');
excludes('and does not show the other chat', logText(reloaded), 'what is a tensor');
eq('and points the picker at that chat\'s model', modelValue(reloaded), 'llama3.2:3b');

// ---- opening an older chat -------------------------------------------------

row(reloaded, 1).childNodes[0].fire('click');
includes('opening a chat replays its question', logText(reloaded), 'what is a tensor');
includes('opening a chat replays its reply', logText(reloaded), 'a tensor is an array');
excludes('and drops the chat that was open', logText(reloaded), 'what is a vector');
eq('the reopened chat is now the open one', row(reloaded, 1).childNodes[0].getAttribute('aria-current'), 'true');
eq('the row it was in is no longer marked', row(reloaded, 0).childNodes[0].getAttribute('aria-current'), null);
includes('the page says which chat it opened', el(reloaded, 'status').textContent, 'what is a tensor');

// ---- the model is a property of the chat -----------------------------------

el(reloaded, 'model').value = 'qwen2.5:7b';
el(reloaded, 'model').fire('change');

var tensorChat = savedChat(reloaded, 'what is a tensor');
var vectorChat = savedChat(reloaded, 'what is a vector');

eq('switching the model moves that chat', tensorChat.model, 'qwen2.5:7b');
eq('and leaves the other chat alone', vectorChat.model, 'llama3.2:3b');

// Switching moved that chat to the top of the list, and it is the one left
// open, so this is also the chat a reload comes back to.
eq('the chat that was switched is the one the reload reopens', rowText(reloaded, 0), 'what is a tensor');

var switched = makeEnv({ mem: reloaded.mem });
await settle();

eq('the choice survives a reload', modelValue(switched), 'qwen2.5:7b');
row(switched, 1).childNodes[0].fire('click');
eq('and does not leak into the other chat', modelValue(switched), 'llama3.2:3b');
row(switched, 0).childNodes[0].fire('click');
eq('and is still there when you come back to it', modelValue(switched), 'qwen2.5:7b');

// ---- two chats touched inside one millisecond ------------------------------
// The clock is stopped, so every chat here carries the same `updated` and the
// ordering cannot lean on the timestamp at all. It has to come from the order
// the chats were last touched — without it the rail shows the older chat at the
// top and the reload reopens the wrong one, and it does so only on runs where
// the two touches happen to straddle a millisecond boundary.
var frozen = makeEnv({ frozenClock: 1700000000000 });
await settle();

sendText(frozen, 'first chat');
await settle();
eq('two chats under one stamp are ordered by recency',
   rowText(frozen, 0), 'first chat');

el(frozen, 'new-chat').fire('click');
sendText(frozen, 'second chat');
await settle();
eq('the newer chat is on top even with an identical stamp',
   rowText(frozen, 0), 'second chat');
eq('and the older one is below it', rowText(frozen, 1), 'first chat');

// Touching the older chat is what has to move it back to the head — a stamp it
// shares with the other chat cannot do that on its own.
row(frozen, 1).childNodes[0].fire('click');
el(frozen, 'model').value = 'qwen2.5:7b';
el(frozen, 'model').fire('change');
eq('touching the older chat brings it to the top',
   rowText(frozen, 0), 'first chat');
var frozenReload = makeEnv({ mem: frozen.mem, frozenClock: 1700000000000 });
await settle();
eq('and it is the one a reload reopens',
   rowText(frozenReload, 0), 'first chat');

// ---- a chat whose model has gone -------------------------------------------

var ghostStore = {
  current: 'g1',
  sessions: [{
    id: 'g1', title: 'old chat', model: 'ghost:1b', updated: 5,
    messages: [{ role: 'user', content: 'hello' }, { role: 'assistant', content: 'hi' }]
  }]
};
var ghost = makeEnv({ mem: { 'momos.sessions.v1': JSON.stringify(ghostStore) } });
await settle();

// The missing one goes last, so "not installed" reads as the answer at the end
// of the list rather than a surprise in the middle of it.
eq('a deleted model is still offered, and last',
   modelLabels(ghost), ['deepseek-r1:8b', 'llama3.2:3b', 'qwen2.5:7b', 'ghost:1b (not installed)']);
eq('and is still the chat\'s model', modelValue(ghost), 'ghost:1b');

// ---- deleting --------------------------------------------------------------

switched.confirmResult = false;
var before = rows(switched).length;
rowDelete(switched, 0).fire('click');
eq('declining the question deletes nothing', rows(switched).length, before);
eq('and the saved chats are untouched', store(switched).sessions.length, before);

switched.confirmResult = true;
var doomed = row(switched, 0).childNodes[0].textContent;
var survivor = row(switched, 1).childNodes[0].textContent;
rowDelete(switched, 0).fire('click');

eq('confirming deletes the chat', rows(switched).length, 1);
eq('and the saved copy loses it too', store(switched).sessions.length, 1);
eq('the chat that is left is the other one', newestChat(switched).title, survivor);
includes('and the page opens what is left', logText(switched), survivor);
excludes('and the deleted chat is off the screen', logText(switched), doomed);

// ---- stopping mid-reply ----------------------------------------------------

var slow = makeEnv({ reply: function () {
  return ['{"message":{"content":"a tensor is"}}'];
} });
await settle();
slow.state.hang = true;

sendText(slow, 'explain tensors');
await settle();

// The "> " in front of a question is drawn by the stylesheet, not written into
// the text, so it is not in the DOM and not in this string.
eq('the part that arrived is on screen', logText(slow), 'explain tensorsa tensor is');
eq('a caret shows while it is still typing', countClass(el(slow, 'log'), 'cursor'), 1);

// Navigating away mid-reply is the thing the lock exists to prevent, so it is
// worth a check of its own: the reply must land in the chat it was asked in.
el(slow, 'new-chat').fire('click');
eq('a chat cannot be started under a reply that is still arriving', rows(slow).length, 1);
eq('and the screen is not cleared out from under it', logText(slow) === '', false);

el(slow, 'stop').fire('click');
await settle();

eq('the page says it stopped', el(slow, 'status').textContent, 'stopped');
eq('the partial reply is saved rather than thrown away',
   newestChat(slow).messages,
   [{ role: 'user', content: 'explain tensors' },
    { role: 'assistant', content: 'a tensor is' }]);
eq('and the caret is gone', countClass(el(slow, 'log'), 'cursor'), 0);

// A reply cannot be stopped before it is started, and the controls come back.
eq('the composer is usable again', el(slow, 'send').disabled, false);
eq('the stop button is hidden again', el(slow, 'stop').hidden, true);

// ---- a browser with no storage ---------------------------------------------

var refused = makeEnv({ refusingStorage: true });
await settle();

includes('a browser that will not save says so', bannerText(refused), 'not saving chats');
eq('and the page still chats', el(refused, 'send').disabled, false);
sendText(refused, 'hello');
await settle();
includes('and answers', logText(refused), 'a tensor is an array');
eq('the chat list is not written to', refused.mem['momos.sessions.v1'], undefined);
ok('but the row is still on screen for this session', rows(refused).length === 1,
   String(rows(refused).length));

// ---- saved data that makes no sense ----------------------------------------

var corrupt = makeEnv({ mem: { 'momos.sessions.v1': '{{{ not json at all' } });
await settle();

eq('a corrupt save does not take the page down', rows(corrupt).length, 0);
eq('the composer still works', el(corrupt, 'send').disabled, false);
sendText(corrupt, 'still alive');
await settle();
includes('and the page still answers', logText(corrupt), 'a tensor is an array');
eq('and starts saving afresh', store(corrupt).sessions.length, 1);

// ---- no model at all -------------------------------------------------------

var bare = makeEnv({ config: { ollama_port: 11434 }, tagsFails: true });
await settle();

includes('a page with no model says where to get one', bannerText(bare), 'momos chat');
eq('and does not offer to send', el(bare, 'send').disabled, true);
eq('and the picker says there is nothing installed',
   modelLabels(bare), ['no model installed']);

console.log('');
console.log('#' + (FAILED === 0 ? ' all ' + PASSED + ' assertions passed' :
                              ' ' + FAILED + ' of ' + (PASSED + FAILED) + ' failed'));
}

main().catch(function (e) {
  console.log('not ok the harness ran to completion — ' + (e && e.stack || e));
});
SCENARIOS

cat "$TMP/dom.js" "$TMP/scenarios.js" > "$TMP/run.js"

section "page behaviour (node + a stub DOM)"

OUT="$(node "$TMP/run.js" "$TMP/page.js" 2>&1)"
NODE_STATUS=$?

if [ "$NODE_STATUS" -ne 0 ] && [ -z "$OUT" ]; then
    fail "node produced no output (exit $NODE_STATUS)"
else
    while IFS= read -r line; do
        case "$line" in
            "ok "*)     pass "${line#ok }" ;;
            "not ok "*) fail "${line#not ok }" ;;
            "#"*)       : ;;
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
