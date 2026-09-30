#!/usr/bin/env bash
#
# The saved-chat store in scripts/ui/index.html, exercised for real.
#
# The rest of the UI's tests are greps over the page: they catch a renamed
# endpoint or a dropped marker, but a grep cannot tell you whether a malformed
# localStorage value takes the page down with it. So the store block is marked
# off in the page (between `--- store:begin ---` and `--- store:end ---`) and run
# here under node against a stubbed storage, in the same extract-and-stub spirit
# as tests/test-native-migration.sh uses for the shell functions.
#
# Node is a development-machine convenience, not something the phone needs, so a
# missing node is a skip rather than a failure.
#
# Run: bash tests/test-ui-store.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UI_HTML="$REPO_ROOT/scripts/ui/index.html"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf '  \033[0;32mPASS\033[0m  %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  \033[0;31mFAIL\033[0m  %s\n' "$1"; }
skip() { printf '  \033[0;33mSKIP\033[0m  %s\n' "$1"; }

section() { printf '\n\033[1m%s\033[0m\n' "$1"; }

if ! command -v node >/dev/null 2>&1; then
    printf '\n\033[0;33mnode is not installed — skipping the store tests.\033[0m\n\n'
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ---------------------------------------------------------------------------

section "the page's store block is extractable"

STORE_JS="$TMP/store.js"
sed -n '/\/\/ --- store:begin ---/,/\/\/ --- store:end ---/p' "$UI_HTML" > "$STORE_JS"

if [ -s "$STORE_JS" ]; then
    pass "index.html has a store block"
else
    fail "index.html is missing the '--- store:begin ---' / '--- store:end ---' markers"
    printf '\n  \033[0;31mCannot continue without the block.\033[0m\n\n'
    exit 1
fi

# The block is run outside a browser, so anything that reaches for the document
# would only fail at test time — a long way from the edit that caused it.
#
# Comments are stripped first: the block's own prose says it stays clear of the
# DOM, and a check that tripped on the sentence describing the rule would be
# worse than no check.
CODE_ONLY="$(sed -e 's://.*::' "$STORE_JS" | grep -vE '^[[:space:]]*$')"

if grep -qE '\b(document|window|fetch|localStorage)\b' <<< "$CODE_ONLY"; then
    fail "the store block touches the DOM — it must stay pure to be testable"
    grep -nE '\b(document|window|fetch|localStorage)\b' <<< "$CODE_ONLY" | sed 's/^/        /'
else
    pass "the store block is free of document, window, fetch and localStorage"
fi

# ---------------------------------------------------------------------------

# A localStorage that behaves like the real one, plus switches for the two ways
# it fails: throwing on every write, and refusing altogether.
cat > "$TMP/stub.js" <<'STUB'
var mem = {};
var writes = 0;
var refusing = false;

var storage = {
  setItem: function (k, v) {
    writes++;
    if (refusing) throw new Error('QuotaExceededError');
    mem[k] = String(v);
  },
  getItem: function (k) {
    return Object.prototype.hasOwnProperty.call(mem, k) ? mem[k] : null;
  },
  removeItem: function (k) { delete mem[k]; }
};

function reset(opts) {
  mem = {};
  writes = 0;
  refusing = !!(opts && opts.refusing);
}

function sess(id, updated, messages, model) {
  return {
    id: id,
    title: id,
    model: model || 'llama3.2:3b',
    updated: updated,
    messages: messages || [
      { role: 'user', content: 'hi' },
      { role: 'assistant', content: 'hello' }
    ]
  };
}

var PASSED = 0;
var FAILED = 0;

function ok(name, cond, detail) {
  if (cond) {
    PASSED++;
    console.log('ok ' + name);
  } else {
    FAILED++;
    console.log('not ok ' + name + (detail ? ' — ' + detail : ''));
  }
}

function eq(name, actual, expected) {
  ok(name, JSON.stringify(actual) === JSON.stringify(expected),
     'got ' + JSON.stringify(actual) + ', expected ' + JSON.stringify(expected));
}
STUB

cat > "$TMP/tests.js" <<'TESTS'

// ---- titleFor --------------------------------------------------------------

eq('a short question is its own title', titleFor('what is a tensor'), 'what is a tensor');
eq('only the first line becomes the title', titleFor('first line\nsecond line'), 'first line');
eq('surrounding whitespace goes', titleFor('   padded   '), 'padded');
eq('an empty string is untitled', titleFor(''), 'untitled');
eq('null is untitled', titleFor(null), 'untitled');
eq('a whitespace-only first line is untitled', titleFor('\n\nsecond'), 'untitled');
eq('a title never exceeds the cap',
   titleFor('x'.repeat(200)).length, TITLE_MAX);
ok('a long title is marked as cut',
   titleFor('x'.repeat(200)).slice(-1) === '…',
   JSON.stringify(titleFor('x'.repeat(200)).slice(-5)));
eq('a title exactly at the cap is left alone',
   titleFor('y'.repeat(TITLE_MAX)), 'y'.repeat(TITLE_MAX));
ok('a title exactly at the cap has no ellipsis',
   titleFor('y'.repeat(TITLE_MAX)).indexOf('…') === -1);

// ---- parseStore: it must never throw --------------------------------------

eq('an empty string parses to an empty store',
   parseStore(''), { current: null, sessions: [] });
eq('null parses to an empty store',
   parseStore(null), { current: null, sessions: [] });
eq('unparseable JSON parses to an empty store',
   parseStore('{this is not json'), { current: null, sessions: [] });
eq('a JSON array parses to an empty store',
   parseStore('[1,2,3]'), { current: null, sessions: [] });
eq('sessions that are not a list parse to an empty store',
   parseStore('{"sessions":"nope"}'), { current: null, sessions: [] });
eq('a null session is dropped',
   parseStore('{"sessions":[null]}').sessions.length, 0);
eq('a session with no id is dropped',
   parseStore('{"sessions":[{"messages":[{"role":"user","content":"a"}]}]}').sessions.length, 0);
eq('a session with an empty id is dropped',
   parseStore('{"sessions":[{"id":"","messages":[{"role":"user","content":"a"}]}]}')
     .sessions.length, 0);

// ---- parseStore: filtering -------------------------------------------------

var dirty = JSON.stringify({
  current: 'a',
  sessions: [{
    id: 'a', updated: 5, title: 'kept', model: 'm',
    extra: 'dropped',
    messages: [
      { role: 'user', content: 'hello', thinking: 'dropped' },
      { role: 'system', content: 'not a chat turn' },
      { role: 'assistant' },
      { role: 'assistant', content: 42 },
      null,
      { role: 'assistant', content: 'world' }
    ]
  }]
});
var parsed = parseStore(dirty);

eq('only real turns survive', parsed.sessions[0].messages,
   [{ role: 'user', content: 'hello' }, { role: 'assistant', content: 'world' }]);
eq('reasoning is not persisted', Object.keys(parsed.sessions[0].messages[0]),
   ['role', 'content']);
ok('unknown session fields are not carried forward',
   parsed.sessions[0].extra === undefined);

eq('a chat with no usable messages is not worth a row',
   parseStore('{"sessions":[{"id":"a","messages":[]}]}').sessions.length, 0);

// ---- parseStore: current, titles and ordering ------------------------------

eq('current is kept when it names a stored chat', parseStore(dirty).current, 'a');
eq('current is dropped when it names nothing',
   parseStore('{"current":"gone","sessions":[{"id":"a","messages":[{"role":"user","content":"x"}]}]}')
     .current, null);
eq('a missing title is rebuilt from the first question',
   parseStore('{"sessions":[{"id":"a","messages":[{"role":"user","content":"ask me"}]}]}')
     .sessions[0].title, 'ask me');

var ordered = parseStore(JSON.stringify({
  sessions: [sess('old', 1), sess('new', 9), sess('mid', 5)]
}));
eq('chats come back newest first', ordered.sessions.map(function (s) { return s.id; }),
   ['new', 'mid', 'old']);

eq('a missing timestamp sorts last, not first',
   parseStore('{"sessions":[{"id":"stamp","updated":1,"messages":[{"role":"user","content":"x"}]},{"id":"nostamp","messages":[{"role":"user","content":"y"}]}]}')
     .sessions.map(function (s) { return s.id; }), ['stamp', 'nostamp']);

// ---- round trip ------------------------------------------------------------

var trip = { current: 'b', sessions: [sess('a', 1), sess('b', 2)] };
var back = parseStore(serializeStore(trip, trip.sessions));
eq('a chat survives a write and a read', back.sessions.length, 2);
eq('the open chat survives a write and a read', back.current, 'b');
eq('the text survives a write and a read', back.sessions[0].messages[1].content, 'hello');
eq('a store with no open chat round trips as no open chat',
   parseStore(serializeStore({ current: null, sessions: [sess('a', 1)] },
                             [{ id: 'a', title: 'a', model: 'm', updated: 1, messages: [] }]))
     .current, null);

// ---- safeSet: the ordinary path --------------------------------------------

reset();
var few = { current: 'a', sessions: [sess('a', 1)] };
eq('a write that fits reports nothing dropped', safeSet(storage, few), []);
ok('a write that fits actually wrote', typeof mem[STORE_KEY] === 'string');
eq('the written copy reads back', parseStore(mem[STORE_KEY]).sessions.length, 1);

// ---- safeSet: the storage cap ----------------------------------------------

reset();
var many = { current: null, sessions: [] };
for (var i = 0; i < MAX_SESSIONS + 12; i++) many.sessions.push(sess('s' + i, i + 1));

var droppedIds = safeSet(storage, many);
eq('the cap drops exactly the overflow', droppedIds.length, 12);
eq('the cap keeps MAX_SESSIONS', parseStore(mem[STORE_KEY]).sessions.length, MAX_SESSIONS);
ok('the oldest chats are the ones dropped',
   droppedIds.indexOf('s0') !== -1 && droppedIds.indexOf('s11') !== -1,
   JSON.stringify(droppedIds));
ok('the newest chat is kept',
   droppedIds.indexOf('s' + (MAX_SESSIONS + 11)) === -1);
ok('what is left in memory is untouched',
   many.sessions.length === MAX_SESSIONS + 12);

// ---- safeSet: storage that refuses everything ------------------------------

reset({ refusing: true });
var hopeless = { current: 'a', sessions: [sess('a', 1), sess('b', 2)] };
var lost = safeSet(storage, hopeless);

eq('a refusing storage loses every chat, and says so', lost.length, 2);
ok('a refusing storage leaves nothing behind', mem[STORE_KEY] === undefined);
// One write per candidate size, plus the empty one at the end. A loop that
// could only end by succeeding would spin here instead of returning.
eq('a refusing storage is given up on, not retried forever', writes, 3);

// ---- storageUsable ---------------------------------------------------------

reset();
eq('usable storage is usable', storageUsable(storage), true);
ok('the probe does not leave anything behind', mem[STORE_KEY + '.probe'] === undefined);

reset({ refusing: true });
eq('storage that throws is not usable', storageUsable(storage), false);

// ---- the cap of the store itself -------------------------------------------

var over = [];
for (var k = 0; k < MAX_SESSIONS + 5; k++) over.push(sess('x' + k, k + 1));
eq('a stored file over the cap is trimmed on read',
   parseStore(JSON.stringify({ sessions: over })).sessions.length, MAX_SESSIONS);

console.log('');
console.log('#' + (FAILED === 0 ? ' all ' + PASSED + ' assertions passed' :
                              ' ' + FAILED + ' of ' + (PASSED + FAILED) + ' failed'));
TESTS

cat "$TMP/stub.js" "$STORE_JS" "$TMP/tests.js" > "$TMP/run.js"

section "store logic (node)"

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
