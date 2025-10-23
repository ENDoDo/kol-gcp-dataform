// definitions/sources/kol_sources.js
const { source_schema, source_schema_stg } = dataform.projectConfig.vars;
const defaultSchema = dataform.projectConfig.defaultSchema;

const schema = defaultSchema === 'kolbi_analysis_stg' ? source_schema_stg : source_schema;

// kolbi_keiba
declare({
  schema: schema,
  name: "kol_den1"
});

declare({
  schema: schema,
  name: "kol_den2"
});

declare({
  schema: schema,
  name: "kol_sei1"
});

declare({
  schema: schema,
  name: "kol_sei2"
});

declare({
  schema: schema,
  name: "kol_ket"
});