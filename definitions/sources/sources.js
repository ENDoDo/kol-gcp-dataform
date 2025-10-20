// definitions/sources.sqlx

// KODBのソーステーブルを宣言します。
// dataform.jsonのvars.source_schemaで指定したデータセット名（kolbi_keiba）が使われます。

// kol_den1: 出馬表レース情報
js_blocks.declare({
  database: "smartkeiba",
  schema: vars.source_schema,
  name: "kol_den1"
});

// kol_den2: 出馬表馬情報
js_blocks.declare({
  database: "smartkeiba",
  schema: vars.source_schema,
  name: "kol_den2"
});

// kol_sei1: 成績レース情報
js_blocks.declare({
  database: "smartkeiba",
  schema: vars.source_schema,
  name: "kol_sei1"
});

// kol_sei2: 成績馬情報
js_blocks.declare({
  database: "smartkeiba",
  schema: vars.source_schema,
  name: "kol_sei2"
});

// kol_ket: 血統情報
js_blocks.declare({
  database: "smartkeiba",
  schema: vars.source_schema,
  name: "kol_ket"
});