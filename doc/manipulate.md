## Table Manipulation

dplyr-style verbs for filtering, selecting, sorting, transforming, and summarizing tables. Functions that accept predicates use Maxima lambda expressions where parameter names are automatically matched to column names.

### Function: df_filter (T, pred)

Subset rows where `pred` returns true. The lambda's parameter names are matched to table column names.

#### Examples

```maxima
(%i1) T : df_table(["name", "price"],
                    [df_string_column(["A","B","C"]), ndarray([10.0, 30.0, 20.0])])$
(%i2) df_filter(T, lambda([price], is(price > 15)));
(%o2)              df_table: 2 rows x 2 cols
(%i3) df_filter(T, lambda([name, price], is(price > 15) and name # "C"));
(%o3)              df_table: 1 rows x 2 cols
```

See also: `df_select`, `df_slice`

### Function: df_select (T, names)

Subset and/or reorder columns by name.

#### Examples

```maxima
(%i1) df_select(T, ["price"]);
(%o1)              df_table: 3 rows x 1 cols
(%i2) df_table_names(df_select(T, ["price", "name"]));
(%o2)                   [price, name]
```

See also: `df_filter`, `df_rename`

### Function: df_arrange (T, col_name) / df_arrange (T, col_name, descending)

Sort rows by a column. Ascending by default; pass `descending` for reverse order. Works with both numeric and string columns.

#### Examples

```maxima
(%i1) T2 : df_arrange(T, "price")$
(%i2) np_to_list(df_table_column(T2, "price"));
(%o2)                  [10.0, 20.0, 30.0]
(%i3) df_arrange(T, "price", descending)$
```

See also: `df_filter`, `df_select`

### Function: df_slice (T, indices)

Subset rows by position (1-indexed).

#### Examples

```maxima
(%i1) T2 : df_slice(T, [1, 3])$
(%i2) df_table_shape(T2);
(%o2)                        [2, 2]
```

See also: `df_filter`, `df_table_head`

### Function: df_rename (T, old_name, new_name)

Rename a column.

#### Examples

```maxima
(%i1) T2 : df_rename(T, "price", "cost")$
(%i2) df_table_names(T2);
(%o2)                     [name, cost]
```

See also: `df_select`

### Function: df_mutate (T, col_name, pred)

Add or replace a column by applying a lambda row-wise. Lambda parameter names are matched to column names. If the column name already exists, it is replaced.

#### Examples

```maxima
(%i1) T2 : df_mutate(T, "double", lambda([price], 2 * price))$
(%i2) df_table_names(T2);
(%o2)              [name, price, double]
(%i3) np_to_list(df_table_column(T2, "double"));
(%o3)                  [20.0, 60.0, 40.0]
```

See also: `df_filter`, `df_summarize`

### Function: df_summarize (T, name1, fn1, name2, fn2, ...)

Reduce a table to a single-row summary. Takes alternating name/lambda pairs. Each lambda receives whole columns (as ndarray or string-column handles) and must return a scalar.

Also works with grouped tables from `df_group_by`, producing one row per group.

#### Examples

```maxima
(%i1) df_summarize(T, "avg", lambda([price], np_mean(price)),
                      "n",   lambda([price], df_count(price)));
(%o1)              df_table: 1 rows x 2 cols
```

See also: `df_mutate`, `df_group_by`, `df_describe`

### Function: df_distinct (T) / df_distinct (T, cols)

Return unique rows. Optionally specify which columns to consider for uniqueness.

#### Examples

```maxima
(%i1) T : df_table(["x"], [df_string_column(["a","b","a","c"])])$
(%i2) df_table_shape(df_distinct(T));
(%o2)                        [3, 1]
```

See also: `df_filter`, `df_nunique`
