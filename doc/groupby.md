## Grouped Tables

Group a table by a column for per-group aggregation with `df_summarize`.

### Function: df_group_by (T, col_name)

Group a table by a column, returning a grouped table. The grouped table can then be passed to `df_summarize` to compute per-group statistics.

#### Examples

```maxima
(%i1) T : df_table(["region", "revenue"],
                    [df_string_column(["N","S","N","S"]),
                     ndarray([10.0, 20.0, 30.0, 40.0])])$
(%i2) G : df_group_by(T, "region")$
(%i3) df_summarize(G, "total", lambda([revenue], np_sum(revenue)));
(%o3)              df_table: 2 rows x 2 cols
```

The result table has the group-key column plus one column per summary function.

See also: `df_summarize`, `df_describe`, `df_grouped_table_p`

### Function: df_grouped_table_p (x)

Predicate: return `true` if `x` is a grouped table handle, `false` otherwise.

#### Examples

```maxima
(%i1) T : df_table(["region", "revenue"],
                    [df_string_column(["N","S"]), ndarray([10.0, 20.0])])$
(%i2) G : df_group_by(T, "region")$
(%i3) df_grouped_table_p(G);
(%o3)                         true
(%i4) df_grouped_table_p(T);
(%o4)                        false
```

See also: `df_group_by`, `df_table_p`
