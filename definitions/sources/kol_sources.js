// definitions/sources/kol_sources.js
const { source_schema } = dataform.projectConfig.vars;

// kolbi_keiba
declare({
  schema: source_schema,
  name: "kol_den1"
});

declare({
  schema: source_schema,
  name: "kol_den2"
});

declare({
  schema: source_schema,
  name: "kol_sei1"
});

declare({
  schema: source_schema,
  name: "kol_sei2"
});

declare({
  schema: source_schema,
  name: "kol_ket"
});