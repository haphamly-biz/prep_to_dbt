const output = $('Create dbt model (snowflake)').first().json.output;
const details = output.details ?? {};
const sql = output.sql ?? '';

// direct upstream entries of this flow (from datasource_lineage)

const upstream = $('Get direct upstream data from datasource_lineage table').all().map(i => i.json);

// converted upstream models (for ref())

const upstreamModels = upstream.map(u => u.model_name).filter(Boolean);

// upstream database tables (for source()), normalised to "schema.table"
// datasource_name looks like DATABASE.SCHEMA.TABLE (possibly with [] or "" around the parts)

const norm = s => String(s ?? '').replace(/[\[\]"`]/g, '').trim().toLowerCase();
const upstreamTables = upstream
  .filter(u => u.datasource_type === 'external_table' && u.datasource_name)
  .map(u => norm(u.datasource_name).split('.').slice(-2).join('.'));

const failures = [];
const warnings = [];

// 1. the agent reported no errors and returned SQL

for (const e of details.errors ?? []) failures.push(`Agent error: ${e}`);
if (!sql.trim()) failures.push('The SQL is empty.');
if (sql.includes('TODO_')) failures.push('The SQL still contains a TODO_ placeholder.');

// 2. no backticks (invalid in Snowflake; identifiers use double quotes)

const withoutStrings = sql.replace(/'[^']*'/g, "''").replace(/--.*$/gm, '');
if (/`/.test(withoutStrings)) failures.push('Backticks found. Snowflake identifiers use double quotes.');

// 3. every ref() points to a converted upstream model

for (const [, model] of sql.matchAll(/ref\(\s*['"]([^'"]+)['"]\s*\)/g)) {
  if (!upstreamModels.includes(model)) failures.push(`ref('${model}') is not a converted upstream model.`);
}

// 4. every source() points to an upstream table of this flow

for (const [, schema, table] of sql.matchAll(/source\(\s*['"]([^'"]+)['"]\s*,\s*['"]([^'"]+)['"]\s*\)/g)) {
  if (schema.startsWith('TODO_')) continue; // placeholder, already caught by check 1
  const key = `${norm(schema)}.${norm(table)}`;
  if (!upstreamTables.includes(key)) {
    warnings.push(`source('${schema}', '${table}') is not an upstream table of this flow in datasource_lineage.`);
  }
}

// 5. no duplicate column names (unquoted Snowflake identifiers are case-insensitive)

const names = (details.columns ?? []).map(c => String(c.dbt).toLowerCase());
const dups = names.filter((n, i) => names.indexOf(n) !== i);
if (dups.length) failures.push(`Duplicate column names: ${[...new Set(dups)].join(', ')}.`);

const passed = failures.length === 0;

return [{ json: {
  passed,
  failures,
  warnings,
  model: details.model,
  sql,
  details,
}}];
