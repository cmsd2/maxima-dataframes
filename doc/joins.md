## Joins and Binds

Combine tables by key columns (joins) or by stacking (binds).

### Function: df_inner_join (T1, T2, key)

Join two tables on a key column, keeping only rows with matching keys in both tables.

#### Examples

```maxima
(%i1) T1 : df_table(["id", "name"],
                     [df_string_column(["1","2","3"]),
                      df_string_column(["Alice","Bob","Charlie"])])$
(%i2) T2 : df_table(["id", "score"],
                     [df_string_column(["1","2"]),
                      ndarray([90.0, 80.0])])$
(%i3) df_inner_join(T1, T2, "id");
(%o3)              df_table: 2 rows x 3 cols
```

See also: `df_left_join`, `df_bind_cols`

### Function: df_left_join (T1, T2, key)

Join two tables on a key column, keeping all rows from the left table. Unmatched right columns are filled with 0 (numeric) or "" (string).

#### Examples

```maxima
(%i1) df_left_join(T1, T2, "id");
(%o1)              df_table: 3 rows x 3 cols
```

See also: `df_inner_join`

### Function: df_bind_rows (T1, T2)

Stack two tables vertically. Column names must match exactly.

#### Examples

```maxima
(%i1) A : df_table(["x"], [ndarray([1.0, 2.0])])$
(%i2) B : df_table(["x"], [ndarray([3.0, 4.0])])$
(%i3) df_table_shape(df_bind_rows(A, B));
(%o3)                        [4, 1]
```

See also: `df_bind_cols`

### Function: df_bind_cols (T1, T2)

Stack two tables horizontally. Row counts must match and column names must not overlap.

#### Examples

```maxima
(%i1) X : df_table(["x"], [ndarray([1.0, 2.0])])$
(%i2) Y : df_table(["y"], [ndarray([3.0, 4.0])])$
(%i3) df_table_names(df_bind_cols(X, Y));
(%o3)                        [x, y]
```

See also: `df_bind_rows`, `df_inner_join`
