// =====================================================================
// Validate a generated dbt model for Databricks (n8n Code node)
// Static checks only: nothing is run against the warehouse.
// Returns status: "failed" (any failure), "review" (warnings only) or "passed".
// =====================================================================

// Names of the nodes this code reads from: change them if yours differ
const AGENT_NODE = 'Create dbt model (databricks)';
const LINEAGE_NODE = 'Get direct upstream data from datasource_lineage table';
const LOOP_NODE = 'Loop Over Items';

// ---------------------------------------------------------------------
// Inputs
// ---------------------------------------------------------------------
let output = $(AGENT_NODE).first().json.output ?? {};
if (typeof output === 'string') {
  const cleaned = output.trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '');
  try {
    output = JSON.parse(cleaned);
  } catch (e) {
    output = { details: { errors: [`Could not parse agent output: ${e.message}`] } };
  }
}
if (!output || typeof output !== 'object' || Array.isArray(output)) output = {};

const details = (output.details && typeof output.details === 'object') ? output.details : {};
const sql = String(output.sql ?? details.sql ?? '');
const modelName = String(details.model ?? '').trim();
const columns = Array.isArray(details.columns) ? details.columns : [];

// Direct upstream entries of this flow (from datasource_lineage)
const upstream = $(LINEAGE_NODE).all()
  .map(i => i.json ?? {})
  .filter(u => Object.keys(u).length > 0);

// datasource_name looks like CATALOG.SCHEMA.TABLE (possibly with [] "" or `` around the parts)
const norm = s => String(s ?? '').replace(/[\[\]"`]/g, '').trim().toLowerCase();

// Converted upstream models (for ref())
const upstreamModels = upstream.map(u => norm(u.model_name)).filter(Boolean);

// Upstream tables (for source()), normalised to "schema.table"
const upstreamTables = upstream
  .filter(u => u.datasource_type === 'external_table' && u.datasource_name)
  .map(u => norm(u.datasource_name).split('.').slice(-2).join('.'));

const failures = [];
const warnings = [];
const fail = m => failures.push(m);
const warn = m => warnings.push(m);
const toArray = v => (v == null ? [] : Array.isArray(v) ? v : [v]);
const uniq = a => [...new Set(a)];
const colName = c => String(c.dbt ?? c.name ?? c.column ?? '').replace(/`/g, '').toLowerCase();

// ---------------------------------------------------------------------
// Text preparation
//   code = comments removed, literals intact (for ref/source/literal checks)
//   bare = code with string literals blanked and Jinja replaced (for structure checks)
// In Databricks SQL, '...' and "..." are both string literals; identifiers use `...`.
// ---------------------------------------------------------------------
function stripComments(text) {
  let out = '';
  let i = 0;
  let unterminated = null;
  const n = text.length;
  while (i < n) {
    const c = text[i];
    const d = text[i + 1];
    if (c === '-' && d === '-') { while (i < n && text[i] !== '\n') i++; continue; }
    if (c === '/' && d === '*') {
      const end = text.indexOf('*/', i + 2);
      if (end === -1) { unterminated = 'block comment /* */'; break; }
      out += ' '; i = end + 2; continue;
    }
    if (c === '{' && d === '#') {
      const end = text.indexOf('#}', i + 2);
      if (end === -1) { unterminated = 'Jinja comment {# #}'; break; }
      out += ' '; i = end + 2; continue;
    }
    if (c === "'" || c === '"' || c === '`') {
      let j = i + 1;
      while (j < n) {
        if (c !== '`' && text[j] === '\\') { j += 2; continue; }
        if (text[j] === c) { if (text[j + 1] === c) { j += 2; continue; } break; }
        j++;
      }
      if (j >= n) {
        unterminated = c === '`' ? 'backtick identifier' : 'string literal';
        out += text.slice(i);
        break;
      }
      out += text.slice(i, j + 1);
      i = j + 1;
      continue;
    }
    out += c;
    i++;
  }
  return { out, unterminated };
}

const { out: code, unterminated } = stripComments(sql);
const codeLow = code.toLowerCase();
const noLiterals = code
  .replace(/'(?:''|\\.|[^'\\])*'/g, "''")
  .replace(/"(?:""|\\.|[^"\\])*"/g, "''");
const bare = noLiterals
  .replace(/\{\{[\s\S]*?\}\}/g, ' __jinja__ ')
  .replace(/\{%[\s\S]*?%\}/g, ' ');
const low = bare.toLowerCase();

// Parenthesis depth at every position of `bare`
const depth = new Int32Array(bare.length + 1);
let parenBalance = 0;
let parenNegative = false;
for (let i = 0; i < bare.length; i++) {
  depth[i] = parenBalance;
  if (bare[i] === '(') parenBalance++;
  else if (bare[i] === ')') { parenBalance--; if (parenBalance < 0) parenNegative = true; }
}
depth[bare.length] = parenBalance;

// Name of the function whose parentheses enclose position idx ('' for a bare paren, null at top level)
function enclosingFunction(idx) {
  let d = 0;
  for (let i = idx - 1; i >= 0; i--) {
    if (bare[i] === ')') d++;
    else if (bare[i] === '(') {
      if (d === 0) {
        const m = bare.slice(Math.max(0, i - 40), i).match(/([A-Za-z_][\w]*)\s*$/);
        return m ? m[1].toLowerCase() : '';
      }
      d--;
    }
  }
  return null;
}

// =====================================================================
// 1. Agent result and file content
// =====================================================================
for (const e of [...toArray(details.errors), ...toArray(output.errors)]) {
  fail(`Agent error: ${typeof e === 'string' ? e : JSON.stringify(e)}`);
}
if (!sql.trim()) fail('The SQL is empty.');
if (sql.includes('TODO_')) fail('The SQL still contains a TODO_ placeholder.');
if (sql.includes('```')) fail('The SQL contains markdown code fences (```).');
if (code.trim() && !/^\s*(with|select|\(|\{\{|\{%)/i.test(code)) {
  fail('The SQL does not start with WITH, SELECT or Jinja. It may contain agent commentary.');
}

// =====================================================================
// 2. Model name
// =====================================================================
if (!modelName) {
  fail('No model name returned (details.model).');
} else {
  if (!/^[a-z][a-z0-9_]*$/.test(modelName)) warn(`Model name "${modelName}" is not lowercase snake_case.`);
}

// =====================================================================
// 2b. The agent converted the flow of the current loop iteration
// =====================================================================
let loopFlow = {};
try {
  const f = $(LOOP_NODE).first().json ?? {};
  const raw = f.next_batch?.flows ?? f['next_batch.flows'] ?? f.flows;
  loopFlow = (Array.isArray(raw) ? raw[0] : raw) ?? {};
} catch (e) {
  // loop node not reachable: skip this check
}
if (loopFlow.flow_luid && details.flow_luid && loopFlow.flow_luid !== details.flow_luid) {
  fail(`The agent converted flow ${details.flow_luid}, but the loop is on ${loopFlow.flow_luid} (${loopFlow.flow_name ?? 'unknown'}).`);
} else if (loopFlow.flow_name && details.flow_name && norm(loopFlow.flow_name) !== norm(details.flow_name)) {
  warn(`Flow name "${details.flow_name}" differs from the loop's "${loopFlow.flow_name}".`);
}
if (!String(details.flow_luid ?? '').trim()) fail('No flow_luid returned (details.flow_luid).');
if (!String(details.flow_name ?? '').trim()) fail('No flow_name returned (details.flow_name).');
if (!details.datasource) warn('No datasource name returned (details.datasource).');

// =====================================================================
// 2c. Agent review notes: anything listed here needs a human look
// =====================================================================
for (const r of toArray(details.review)) {
  warn(`Agent review: ${typeof r === 'string' ? r : JSON.stringify(r)}`);
}

// =====================================================================
// 3. SQL syntax basics
// =====================================================================
if (unterminated) fail(`Unterminated ${unterminated}.`);
if (parenNegative || parenBalance !== 0) fail('Unbalanced parentheses.');

if (bare.replace(/;\s*$/, '').includes(';')) fail('More than one SQL statement (";" found inside the model).');
else if (/;\s*$/.test(bare)) fail('Trailing semicolon. dbt wraps the model in its own statement, so remove it.');

const ddl = low.match(/\b(create\s+(or\s+replace\s+)?(temporary\s+)?(table|view|schema|catalog|database)|insert\s+(into|overwrite)|update\s+[\w.`]+\s+set|delete\s+from|merge\s+into|drop\s+(table|view|schema)|alter\s+(table|view)|truncate\s+table|optimize\s|vacuum\s|grant\s|revoke\s)/);
if (ddl) fail(`DDL/DML found ("${ddl[0].trim()}"). A dbt model must be a single SELECT.`);

// =====================================================================
// 4. Jinja and config()
// =====================================================================
const count = re => (code.match(re) || []).length;
if (count(/\{\{/g) !== count(/\}\}/g)) fail('Unbalanced Jinja expression braces {{ }}.');
if (count(/\{%/g) !== count(/%\}/g)) fail('Unbalanced Jinja statement braces {% %}.');
for (const [open, close] of [['if', 'endif'], ['for', 'endfor'], ['macro', 'endmacro'], ['call', 'endcall'], ['filter', 'endfilter']]) {
  const o = count(new RegExp(`\\{%-?\\s*${open}\\b`, 'g'));
  const c = count(new RegExp(`\\{%-?\\s*${close}\\b`, 'g'));
  if (o !== c) fail(`Unbalanced Jinja block: ${o} {% ${open} %} vs ${c} {% ${close} %}.`);
}

const cfg = key => (code.match(new RegExp(`${key}\\s*=\\s*['"]([\\w]+)['"]`, 'i')) || [])[1]?.toLowerCase();
const materialized = cfg('materialized');
if (materialized) {
  const allowed = ['table', 'view', 'incremental', 'ephemeral', 'materialized_view', 'streaming_table'];
  if (!allowed.includes(materialized)) fail(`Materialization "${materialized}" is not supported by dbt-databricks.`);
  if (materialized === 'incremental') {
    if (!/is_incremental\s*\(\s*\)/.test(code)) warn('Incremental model without an is_incremental() filter.');
    const strategy = cfg('incremental_strategy') ?? 'merge';
    const strategies = ['append', 'merge', 'insert_overwrite', 'replace_where', 'microbatch'];
    if (!strategies.includes(strategy)) fail(`Incremental strategy "${strategy}" is not supported by dbt-databricks.`);
    if (strategy === 'merge' && !/unique_key\s*=/.test(code)) warn('Incremental merge without a unique_key appends rows instead of merging.');
  }
}
const fileFormat = cfg('file_format');
if (fileFormat && fileFormat !== 'delta') warn(`file_format "${fileFormat}": merge, snapshots and contracts need Delta.`);

// =====================================================================
// 5. ref() and source()
// =====================================================================
const refs = [];
for (const m of code.matchAll(/\bref\(\s*['"]([^'"]+)['"]\s*(?:,\s*['"]([^'"]+)['"]\s*)?(?:,[^)]*)?\)/g)) {
  refs.push(norm(m[2] ?? m[1])); // ref('model') or ref('package', 'model')
}
for (const model of uniq(refs)) {
  if (model === norm(modelName)) fail(`The model references itself: ref('${model}').`);
  else if (!upstreamModels.includes(model)) fail(`ref('${model}') is not a converted upstream model.`);
}

const sources = [];
for (const [, schema, table] of code.matchAll(/\bsource\(\s*['"]([^'"]+)['"]\s*,\s*['"]([^'"]+)['"]\s*\)/g)) {
  if (schema.startsWith('TODO_')) continue; // placeholder, already caught in section 1
  const key = `${norm(schema)}.${norm(table)}`;
  sources.push(key);
  if (!upstreamTables.includes(key)) {
    warn(`source('${schema}', '${table}') is not an upstream table of this flow in datasource_lineage.`);
  }
}

if (sql.trim() && refs.length === 0 && sources.length === 0) {
  fail('The model has no ref() or source(). Every input must go through one of them.');
}
for (const m of uniq(upstreamModels)) {
  if (!refs.includes(m)) warn(`Upstream model "${m}" is not referenced with ref().`);
}
for (const t of uniq(upstreamTables)) {
  if (!sources.includes(t)) warn(`Upstream table "${t}" is not referenced with source().`);
}

// details.sources (CATALOG.SCHEMA.TABLE) must match the source() calls in the SQL
const declaredSources = uniq(toArray(details.sources).map(s => norm(s).split('.').slice(-2).join('.')).filter(Boolean));
for (const s of declaredSources) {
  if (!sources.includes(s)) fail(`details.sources lists "${s}" but the SQL has no source() for it.`);
}
for (const s of uniq(sources)) {
  if (declaredSources.length && !declaredSources.includes(s)) warn(`source() "${s}" is not listed in details.sources.`);
}

// =====================================================================
// 6. CTEs and relations
// =====================================================================
const cteNames = [];
const cteBody = {}; // CTE name -> position of its opening parenthesis
for (const m of low.matchAll(/(?:\bwith\b(?:\s+recursive\b)?|,)\s*(`?[a-z_][\w]*`?)\s+as\s*\(/g)) {
  if (depth[m.index] === 0) {
    const name = m[1].replace(/`/g, '');
    cteNames.push(name);
    cteBody[name] = m.index + m[0].length - 1;
  }
}
const dupCtes = cteNames.filter((n, i) => cteNames.indexOf(n) !== i);
if (dupCtes.length) fail(`Duplicate CTE names: ${uniq(dupCtes).join(', ')}.`);
for (const name of uniq(cteNames)) {
  const uses = (low.match(new RegExp(`\\b${name}\\b`, 'g')) || []).length;
  if (uses < 2) warn(`CTE "${name}" is defined but never used.`);
}

const SKIP_CALLS = ['extract', 'trim', 'substring', 'substr', 'position', 'overlay', 'date_part'];
for (const m of bare.matchAll(/\b(from|join)\s+([A-Za-z_`][\w.`]*)(\s*\()?/gi)) {
  const target = m[2];
  const before = bare.slice(Math.max(0, m.index - 20), m.index);
  if (/\bdistinct\s*$/i.test(before)) continue; // "is distinct from"
  if (m[3]) continue; // table-valued function, e.g. explode(...), range(...)
  if (['__jinja__', 'lateral', 'values'].includes(target.toLowerCase())) continue;
  const fn = enclosingFunction(m.index);
  if (fn && SKIP_CALLS.includes(fn)) continue; // extract(year from x), trim(both from x) ...
  if (target.includes('.')) {
    fail(`Hardcoded relation "${target}". Use ref() or source() instead of catalog.schema.table.`);
  } else if (!cteNames.includes(target.replace(/`/g, '').toLowerCase())) {
    warn(`"${m[1]} ${target}" is not a CTE, ref() or source().`);
  }
}

// =====================================================================
// 7. Final SELECT: output columns
// =====================================================================
// Analyse the SELECT that starts at selIdx: its column expressions, FROM target and region
function analyseSelect(selIdx) {
  const lvl = depth[selIdx];
  let end = bare.length;
  for (let i = selIdx; i < bare.length; i++) {
    if (bare[i] === ')' && depth[i] === lvl) { end = i; break; }
  }
  let fromPos = -1;
  for (const m of low.slice(selIdx, end).matchAll(/\bfrom\b/g)) {
    if (depth[selIdx + m.index] === lvl) { fromPos = selIdx + m.index; break; }
  }
  const listStart = selIdx + 6;
  const listEnd = fromPos >= 0 ? fromPos : end;
  const exprs = [];
  let last = listStart;
  for (let i = listStart; i < listEnd; i++) {
    if (bare[i] === ',' && depth[i] === lvl) { exprs.push(bare.slice(last, i)); last = i + 1; }
  }
  exprs.push(bare.slice(last, listEnd));
  exprs[0] = exprs[0].replace(/^\s*(distinct|all)\b/i, '');

  const tail = fromPos >= 0 ? bare.slice(fromPos + 4, end) : '';
  const fromTarget = (tail.match(/^\s+([A-Za-z_`][\w`]*)/) || [])[1]?.replace(/`/g, '').toLowerCase() ?? null;
  const atLevel = re => [...low.slice(selIdx, end).matchAll(re)].some(m => depth[selIdx + m.index] === lvl);
  const hasJoin = atLevel(/\bjoin\b/g);
  return { selIdx, end, exprs, selectList: bare.slice(listStart, listEnd), fromTarget, hasJoin, atLevel };
}

let finalSelect = -1;
for (const m of low.matchAll(/\bselect\b/g)) if (depth[m.index] === 0) finalSelect = m.index;

let sqlColumns = [];
if (finalSelect >= 0) {
  const finalSel = analyseSelect(finalSelect);

  // dbt style "select * from final": follow the star into the CTE that defines the columns
  let sel = finalSel;
  for (let hops = 0; hops < 10; hops++) {
    const onlyStar = sel.exprs.length === 1 && /^\s*([A-Za-z_`][\w`]*\.)?\*\s*$/.test(sel.exprs[0]);
    if (!onlyStar || sel.hasJoin || !sel.fromTarget || !(sel.fromTarget in cteBody)) break;
    const p = cteBody[sel.fromTarget];
    const inner = [...low.slice(p).matchAll(/\bselect\b/g)].find(m => depth[p + m.index] === depth[p] + 1);
    if (!inner) break;
    sel = analyseSelect(p + inner.index);
  }
  const { exprs, selectList } = sel;

  const ID = '(`([^`]+)`|[A-Za-z_][\\w]*)';
  const KEYWORDS = ['end', 'null', 'true', 'false', 'distinct'];
  const outputName = expr => {
    const e = expr.trim();
    let m = e.match(new RegExp(`\\bas\\s+${ID}\\s*$`, 'i'));
    if (m) return m[2] ?? m[1];
    if (new RegExp(`^(?:${ID}\\.)*${ID}$`).test(e)) {
      m = e.match(new RegExp(`${ID}$`));
      return m[2] ?? m[1];
    }
    m = e.match(new RegExp(`[)\\w\`']\\s+${ID}\\s*$`));
    if (m && !KEYWORDS.includes((m[2] ?? m[1]).toLowerCase())) return m[2] ?? m[1];
    return null;
  };

  const hasStar = exprs.some(e => /(^|\.)\s*\*(\s+except\s*\(.*\))?\s*$/i.test(e.trim()));
  const hasJinja = selectList.includes('__jinja__');
  if (hasStar) warn('SELECT * in the final select. List the columns explicitly so the contract is stable.');

  if (!hasStar && !hasJinja) {
    const names = exprs.map(outputName);
    const unnamed = exprs.filter((e, i) => names[i] === null).map(e => e.trim().slice(0, 40));
    if (unnamed.length) warn(`Final select has expressions without an alias: ${unnamed.join(' | ')}.`);
    sqlColumns = names.filter(Boolean).map(n => n.toLowerCase());

    const dupSql = sqlColumns.filter((n, i) => sqlColumns.indexOf(n) !== i);
    if (dupSql.length) fail(`Duplicate output columns in the SQL: ${uniq(dupSql).join(', ')}.`);

    // A SQL column is "mapped" when details.columns has an entry with that dbt name and a Prep name
    const meta = columns.map(colName).filter(Boolean);
    const mapped = columns.filter(c => colName(c) && String(c.prep ?? '').trim()).map(colName);
    const extra = sqlColumns.filter(n => !mapped.includes(n));
    if (extra.length) warn(`SQL columns without an equivalent flow column in details.columns: ${uniq(extra).join(', ')}.`);
    if (!unnamed.length) {
      const missing = meta.filter(n => !sqlColumns.includes(n));
      if (missing.length) fail(`Columns in details.columns but not in the SQL: ${uniq(missing).join(', ')}.`);
    }
  } else if (hasJinja) {
    warn('The final select uses Jinja, so its columns could not be compared with details.columns.');
  }

  // Aggregation without GROUP BY (GROUP BY ALL counts as a GROUP BY)
  const AGG = /\b(sum|count|avg|min|max|array_agg|collect_list|collect_set|median|percentile|stddev|variance|any_value|first|last|count_if|bool_and|bool_or)\s*\(/i;
  const aggItems = exprs.filter(s => AGG.test(s) && !/\bover\s*[(\w]/i.test(s));
  const plainItems = exprs.filter(s => !AGG.test(s) && !/^\s*(''|\d+(\.\d+)?|null|true|false)\s*$/i.test(s));
  if (aggItems.length && plainItems.length && !sel.atLevel(/\bgroup\s+by\b/g)) {
    fail('Final select mixes aggregates and plain columns without GROUP BY.');
  }

  const topLevel = finalSel.atLevel;
  if (topLevel(/\border\s+by\b/g) && !topLevel(/\blimit\b/g)) warn('ORDER BY in the final select has no effect on a table or view.');
  if (topLevel(/\blimit\b/g)) warn('LIMIT in the final select. Is that a leftover from testing?');
} else if (sql.trim()) {
  fail('No top-level SELECT found.');
}

// =====================================================================
// 8. Column metadata (details.columns)
// =====================================================================
if (!columns.length) warn('No column metadata returned (details.columns).');

const metaNames = columns.map(colName);
const dups = metaNames.filter((n, i) => n && metaNames.indexOf(n) !== i);
if (dups.length) fail(`Duplicate column names (Databricks is case-insensitive): ${uniq(dups).join(', ')}.`);
if (metaNames.some(n => !n)) fail('A column in details.columns has no name.');

// Each Prep column must be mapped, and the dbt name should follow the naming rule
// ("Deal Detail Amount (EUR)" -> deal_detail_amount_eur, "Deal HK-1" -> deal_hk_1)
const toSnake = s => String(s).toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
const prepNames = columns.map(c => String(c.prep ?? '').trim());
if (prepNames.some(p => !p)) fail('A column in details.columns has no Prep name (prep).');
const dupPrep = prepNames.filter((p, i) => p && prepNames.indexOf(p) !== i);
if (dupPrep.length) fail(`Prep columns mapped more than once: ${uniq(dupPrep).join(', ')}.`);
const renamed = columns.filter(c => c.prep && colName(c) && toSnake(c.prep) !== colName(c));
if (renamed.length) {
  warn(`dbt names that don't follow the snake_case of the Prep name: ${renamed.map(c => `"${c.prep}" -> ${colName(c)}`).join(', ')}.`);
}

// Delta rejects these characters in column names unless column mapping is enabled
const deltaBad = metaNames.filter(n => /[ ,;{}()\n\t=]/.test(n));
if (deltaBad.length) fail(`Column names with characters Delta rejects ( ,;{}()=): ${uniq(deltaBad).join(', ')}.`);
const badNames = metaNames.filter(n => n && !deltaBad.includes(n) && !/^[a-z_][a-z0-9_]*$/.test(n));
if (badNames.length) warn(`Column names that are not snake_case: ${uniq(badNames).join(', ')}.`);

const RESERVED = ['select', 'from', 'where', 'group', 'order', 'by', 'table', 'join', 'on', 'union', 'having',
  'limit', 'case', 'when', 'then', 'else', 'end', 'and', 'or', 'not', 'null', 'as', 'with', 'qualify', 'all',
  'distinct', 'except', 'intersect', 'into', 'is', 'in', 'like', 'between', 'true', 'false', 'user'];
const reserved = metaNames.filter(n => RESERVED.includes(n));
if (reserved.length) warn(`Column names that are reserved words (need backticks): ${uniq(reserved).join(', ')}.`);

const TYPES = ['bigint', 'long', 'int', 'integer', 'smallint', 'short', 'tinyint', 'byte', 'decimal', 'dec',
  'numeric', 'double', 'float', 'real', 'string', 'varchar', 'char', 'binary', 'boolean', 'date', 'timestamp',
  'timestamp_ntz', 'interval', 'array', 'map', 'struct', 'variant', 'void'];
const SNOWFLAKE_TYPES = { number: 'decimal(p,s)', text: 'string', timestamp_ltz: 'timestamp', timestamp_tz: 'timestamp',
  datetime: 'timestamp', time: 'string', varbinary: 'binary', object: 'struct or map', geography: 'string', geometry: 'string' };
for (const c of columns) {
  const t = c.data_type ?? c.type;
  if (!t) continue;
  const base = String(t).toLowerCase().trim().match(/^[a-z_0-9]+/)?.[0] ?? '';
  if (SNOWFLAKE_TYPES[base]) fail(`Column "${colName(c)}" uses Snowflake type "${t}". Use ${SNOWFLAKE_TYPES[base]}.`);
  else if (!TYPES.includes(base)) fail(`Column "${colName(c)}" has a type that is not valid in Databricks: "${t}".`);
}

// =====================================================================
// 9. Databricks dialect
// =====================================================================
if (/"[^"]*"/.test(code)) {
  warn('Double quotes found. In Databricks they make a string literal, not an identifier. Use backticks for identifiers.');
}
const notSupported = [
  [/\blateral\s+flatten\b|\bflatten\s*\(/, 'FLATTEN', 'explode() / LATERAL VIEW explode()'],
  [/\bselect\s+top\s+\d+/, 'SELECT TOP n', 'LIMIT n'],
  [/\bconnect\s+by\b|\bstart\s+with\b/, 'CONNECT BY', 'a recursive CTE'],
  [/\bdistinct\s+on\s*\(/, 'DISTINCT ON', 'row_number() with QUALIFY'],
  [/\bobject_construct\s*\(/, 'OBJECT_CONSTRUCT', 'named_struct() or map()'],
  [/\barray_construct\s*\(/, 'ARRAY_CONSTRUCT', 'array()'],
  [/\bdiv0\s*\(/, 'DIV0', 'try_divide()'],
  [/\bzeroifnull\s*\(/, 'ZEROIFNULL', 'coalesce(x, 0)'],
  [/\bnullifzero\s*\(/, 'NULLIFZERO', 'nullif(x, 0)'],
  [/\bequal_null\s*\(/, 'EQUAL_NULL', 'a <=> b or IS NOT DISTINCT FROM'],
  [/\bto_varchar\s*\(/, 'TO_VARCHAR', 'cast(x as string) or date_format()'],
  [/\bstrtok\s*\(/, 'STRTOK', 'split_part()'],
  [/\$\d+\b/, 'positional $1 references', 'column names'],
  [/\bas\s+text\b|::\s*text\b/, 'TEXT type', 'string'],
  [/::\s*number\b|\bas\s+number\b/, 'NUMBER type', 'decimal(p,s)'],
  [/\bcurrent_warehouse\s*\(|\bcurrent_role\s*\(/, 'Snowflake session functions', 'current_user() / current_catalog()'],
];
for (const [re, what, use] of notSupported) {
  if (re.test(low)) fail(`${what} is not Databricks SQL. Use ${use}.`);
}
const runtimeDependent = [
  [/\blistagg\s*\(|\bstring_agg\s*\(/, 'LISTAGG / STRING_AGG', 'array_join(collect_list(x), sep) on older runtimes'],
  [/\bparse_json\s*\(|::\s*variant\b|\bas\s+variant\b/, 'VARIANT / parse_json', 'from_json() or a string column on older runtimes'],
  [/\bwithin\s+group\s*\(/, 'WITHIN GROUP', 'array_sort(collect_list(...)) on older runtimes'],
];
for (const [re, what, use] of runtimeDependent) {
  if (re.test(low)) warn(`${what} needs a recent Databricks runtime. Check yours, or use ${use}.`);
}

// =====================================================================
// 10. Risky logic patterns
// =====================================================================
if (/(?:[^<>!:]=|<>|!=)\s*null\b/.test(low)) fail('Comparison with NULL using = or <> (always unknown). Use IS NULL / IS NOT NULL.');
if (/\bis\s+(not\s+)?distinct\s+from\s+''/.test(codeLow)) warn("IS DISTINCT FROM '' keeps NULL values. Check that this is intended.");
if (/\bcross\s+join\b/.test(low)) warn('CROSS JOIN found. Check that the row multiplication is intended.');
if (/\bselect\s+distinct\b/.test(low)) warn('SELECT DISTINCT found. It can hide duplicate rows caused by a wrong join.');
if (/\bunion\b(?!\s+all\b)/.test(low)) warn('UNION without ALL removes duplicates. Use UNION ALL unless that is intended.');
if (/\bnot\s+in\s*\(\s*select\b/.test(low)) warn('NOT IN (SELECT ...) returns no rows if the subquery contains a NULL. Prefer NOT EXISTS.');
if (/\bon\s+(1\s*=\s*1|true)\b/.test(low)) warn('Join condition ON 1=1 / ON TRUE acts as a cross join.');
if (/\bcollect_set\s*\(|\bcollect_list\s*\(/.test(low) && !/\barray_sort\s*\(/.test(low)) {
  warn('collect_list / collect_set order is not deterministic. Wrap in array_sort() if order matters.');
}

// =====================================================================
// 11. Hardcoded values and security
// =====================================================================
if (/\b(password|passwd|pwd|secret|token|api_?key|access_?key)\b\s*[=:]\s*['"][^'"]+['"]/i.test(code)) {
  fail('Possible hardcoded credential in the SQL.');
}
if (/\bdapi[0-9a-f]{32}\b/i.test(code)) fail('Databricks personal access token found in the SQL.');
if (/'(prod|production|dev|development|staging|uat|test)'/i.test(code)) {
  warn('Hardcoded environment name. Use target.name or a var() instead.');
}
if (/'\d{4}-\d{2}-\d{2}/.test(code)) warn('Hardcoded date literal. Consider a var() or a relative date.');
if (/\b(dbfs|abfss|s3a?|gs):\/\//i.test(code)) warn('Hardcoded storage path. Read files through a source() or volume instead.');

// ---------------------------------------------------------------------
// Result (plain object: valid in both Code node modes)
// ---------------------------------------------------------------------
const status = failures.length ? 'failed' : warnings.length ? 'review' : 'passed';

return {
  status,
  passed: failures.length === 0,
  failures: uniq(failures),
  warnings: uniq(warnings),
  model: modelName || null,
  sql_columns: sqlColumns,
  refs: uniq(refs),
  sources: uniq(sources),
  sql,
  details,
};
