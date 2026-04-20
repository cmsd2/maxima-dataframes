## String Columns

A **string-column** is an opaque handle wrapping a 1D column of strings. It is the string counterpart to ndarray, designed for categorical labels, names, and other non-numeric data.

String-columns use **1-based indexing** (matching Maxima convention).

### Function: df_string_column (list)

Create a string-column from a Maxima list of strings.

Each element is converted to a string via `sconcat`.

#### Examples

```maxima
(%i1) sc : df_string_column(["Alice", "Bob", "Charlie"]);
(%o1)      string_column(3) ["Alice", "Bob", "Charlie"]
(%i2) df_string_column_length(sc);
(%o2)                          3
(%i3) df_string_column_ref(sc, 1);
(%o3)                        Alice
```

See also: `df_to_string_list`, `df_string_column_p`

### Function: df_to_string_list (col)

Convert a string-column back to a Maxima list of strings.

#### Examples

```maxima
(%i1) sc : df_string_column(["x", "y", "z"]);
(%o1)          string_column(3) ["x", "y", "z"]
(%i2) df_to_string_list(sc);
(%o2)                      [x, y, z]
```

See also: `df_string_column`

### Function: df_string_column_p (x)

Predicate: return `true` if `x` is a string-column handle, `false` otherwise.

#### Examples

```maxima
(%i1) df_string_column_p(df_string_column(["a", "b"]));
(%o1)                         true
(%i2) df_string_column_p(42);
(%o2)                        false
(%i3) df_string_column_p(ndarray([1, 2, 3]));
(%o3)                        false
```

See also: `df_string_column`

### Function: df_string_column_ref (col, i)

Access element `i` (1-indexed) of a string-column.

Signals an error if `i` is out of bounds.

#### Examples

```maxima
(%i1) sc : df_string_column(["red", "green", "blue"]);
(%o1)       string_column(3) ["red", "green", "blue"]
(%i2) df_string_column_ref(sc, 1);
(%o2)                          red
(%i3) df_string_column_ref(sc, 3);
(%o3)                         blue
```

See also: `df_string_column_length`, `df_to_string_list`

### Function: df_string_column_length (col)

Return the number of elements in a string-column.

#### Examples

```maxima
(%i1) df_string_column_length(df_string_column(["a", "b", "c"]));
(%o1)                          3
(%i2) df_string_column_length(df_string_column([]));
(%o2)                          0
```

See also: `df_string_column_ref`, `df_table_shape`
