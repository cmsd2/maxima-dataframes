## Tables

A **df_table** is a columnar table with named, typed columns. Each column is either an ndarray (numeric data) or a string-column (text data). All columns must have the same number of rows.

### Function: df_table (names, columns)

Create a table from a list of column names and a list of columns.

Each column can be an ndarray or a string-column. The `names` argument is a Maxima list of strings. The `columns` argument is a Maxima list of column handles.

#### Examples

```maxima
/* Numeric-only table */
(%i1) x : ndarray([1.0, 2.0, 3.0])$
(%i2) y : ndarray([4.0, 5.0, 6.0])$
(%i3) T : df_table(["x", "y"], [x, y]);
(%o3)              df_table: 3 rows x 2 cols

/* Mixed table with strings and numbers */
(%i4) names : df_string_column(["Alice", "Bob", "Charlie"])$
(%i5) scores : ndarray([95.0, 87.0, 92.0])$
(%i6) T2 : df_table(["name", "score"], [names, scores]);
(%o6)              df_table: 3 rows x 2 cols
```

See also: `df_table_column`, `df_table_shape`, `df_table_names`

### Function: df_table_column (T, name)

Extract a column by name from a table.

Returns an ndarray for numeric columns or a string-column for text columns. Signals an error if the column name is not found.

#### Examples

```maxima
(%i1) names : df_string_column(["x", "y", "z"])$
(%i2) vals : ndarray([1.0, 2.0, 3.0])$
(%i3) T : df_table(["name", "value"], [names, vals])$
(%i4) df_table_column(T, "name");
(%o4)          string_column(3) ["x", "y", "z"]
(%i5) ndarray_p(df_table_column(T, "value"));
(%o5)                         true
(%i6) df_string_column_p(df_table_column(T, "name"));
(%o6)                         true
```

See also: `df_table`, `df_table_names`

### Function: df_table_shape (T)

Return the shape of a table as `[nrows, ncols]`.

#### Examples

```maxima
(%i1) x : ndarray([1.0, 2.0, 3.0])$
(%i2) y : ndarray([4.0, 5.0, 6.0])$
(%i3) T : df_table(["x", "y"], [x, y])$
(%i4) df_table_shape(T);
(%o4)                        [3, 2]
```

See also: `df_table_names`, `df_table`

### Function: df_table_names (T)

Return the column names of a table as a Maxima list of strings.

#### Examples

```maxima
(%i1) x : ndarray([1.0, 2.0, 3.0])$
(%i2) y : ndarray([4.0, 5.0, 6.0])$
(%i3) T : df_table(["x", "y"], [x, y])$
(%i4) df_table_names(T);
(%o4)                        [x, y]
```

See also: `df_table_shape`, `df_table_column`

### Function: df_table_head (T) / df_table_head (T, n)

Return the first `n` rows of a table as a new table.

Defaults to 5 rows if `n` is not given. Works with both numeric and string columns.

#### Examples

```maxima
(%i1) names : df_string_column(["a", "b", "c", "d", "e"])$
(%i2) vals : ndarray([1.0, 2.0, 3.0, 4.0, 5.0])$
(%i3) T : df_table(["name", "value"], [names, vals])$
(%i4) T2 : df_table_head(T, 2)$
(%i5) df_table_shape(T2);
(%o5)                        [2, 2]
(%i6) df_to_string_list(df_table_column(T2, "name"));
(%o6)                        [a, b]
```

See also: `df_table`, `df_table_shape`

### Function: df_table_to_ndarray (T)

Stack all numeric columns of a table into a 2D ndarray.

String columns are skipped. Signals an error if the table has no numeric columns. The result has shape `[nrows, num_numeric_cols]`.

#### Examples

```maxima
(%i1) x : ndarray([1.0, 2.0])$
(%i2) y : ndarray([3.0, 4.0])$
(%i3) T : df_table(["x", "y"], [x, y])$
(%i4) A : df_table_to_ndarray(T)$
(%i5) np_shape(A);
(%o5)                        [2, 2]
(%i6) np_to_matrix(A);
(%o6)          matrix([1.0, 3.0], [2.0, 4.0])
```

See also: `df_ndarray_to_table`, `df_table`

### Function: df_ndarray_to_table (A, names)

Split a 2D ndarray into named columns, creating a table.

The `names` argument is a Maxima list of strings, one per column. The number of names must match the number of columns in the ndarray.

#### Examples

```maxima
(%i1) A : np_eye(3)$
(%i2) T : df_ndarray_to_table(A, ["a", "b", "c"])$
(%i3) df_table_shape(T);
(%o3)                        [3, 3]
(%i4) df_table_names(T);
(%o4)                      [a, b, c]
(%i5) np_to_list(df_table_column(T, "a"));
(%o5)                  [1.0, 0.0, 0.0]
```

See also: `df_table_to_ndarray`, `df_table`

### Function: df_table_p (x)

Predicate: return `true` if `x` is a table handle, `false` otherwise.

#### Examples

```maxima
(%i1) x : ndarray([1.0, 2.0])$
(%i2) T : df_table(["x"], [x])$
(%i3) df_table_p(T);
(%o3)                         true
(%i4) df_table_p(42);
(%o4)                        false
```

See also: `df_table`, `df_string_column_p`
