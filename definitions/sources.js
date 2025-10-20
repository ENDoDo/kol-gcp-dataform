// definitions/sources.js

// KODBのソーステーブルを宣言します。
// dataform.jsonのvars.source_schemaで指定したデータセット名（kolbi_keiba）からテーブルを読み込みます。

declare({
  database: "smartkeiba",
  schema: vars.source_schema,
  name: "kol_den1"
});

declare({
  database: "smartkeiba",
  schema: vars.source_schema,
  name: "kol_den2"
});

declare({
  database: "smartkeiba",
  schema: vars.source_schema,
  name: "kol_sei1"
});

declare({
  database: "smartkeiba",
  schema: vars.source_schema,
  name: "kol_sei2"
});

declare({
  database: "smartkeiba",
  schema: vars.source_schema,
  name: "kol_ket"
});