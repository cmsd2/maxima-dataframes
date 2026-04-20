# Package dataframes

## Introduction to dataframes

The `dataframes` package provides pandas-like tabular data for Maxima. It extends the `numerics` ndarray ecosystem with string columns and mixed-type tables, enabling work with real-world datasets that combine numeric and categorical data.

**Requirements:** SBCL (Steel Bank Common Lisp). The `numerics` package is loaded automatically.

### Key concepts

**string-column** is a 1D column of strings, the text counterpart to ndarray. It uses 1-based indexing (matching Maxima convention) and appears as an opaque handle, like ndarray.

**df_table** is a columnar table with named, typed columns. Each column is either an ndarray (for numeric data) or a string-column (for text data). Tables are the primary container for mixed-type tabular data.

### Quick start

```maxima
(%i1) load("dataframes")$
(%i2) names : df_string_column(["Alice", "Bob", "Charlie"]);
(%o2)      string_column(3) ["Alice", "Bob", "Charlie"]
(%i3) scores : ndarray([95.0, 87.0, 92.0])$
(%i4) T : df_table(["name", "score"], [names, scores]);
(%o4)              df_table: 3 rows x 2 cols
(%i5) df_table_column(T, "name");
(%o5)      string_column(3) ["Alice", "Bob", "Charlie"]
(%i6) df_table_column(T, "score");
(%o6)            ndarray([3], DOUBLE-FLOAT)
```

### String columns

```maxima
(%i1) sc : df_string_column(["red", "green", "blue"]);
(%o1)       string_column(3) ["red", "green", "blue"]
(%i2) df_string_column_ref(sc, 1);
(%o2)                          red
(%i3) df_string_column_length(sc);
(%o3)                          3
(%i4) df_to_string_list(sc);
(%o4)                [red, green, blue]
```

### Mixed tables

```maxima
(%i1) regions : df_string_column(["North", "South", "East", "West"])$
(%i2) revenue : ndarray([100.0, 150.0, 120.0, 180.0])$
(%i3) T : df_table(["region", "revenue"], [regions, revenue])$
(%i4) df_table_shape(T);
(%o4)                        [4, 2]
(%i5) df_table_names(T);
(%o5)                [region, revenue]
(%i6) T2 : df_table_head(T, 2)$
(%i7) df_table_shape(T2);
(%o7)                        [2, 2]
```

### Converting between tables and ndarrays

```maxima
(%i1) A : np_eye(3)$
(%i2) T : df_ndarray_to_table(A, ["a", "b", "c"])$
(%i3) df_table_shape(T);
(%o3)                        [3, 3]
(%i4) B : df_table_to_ndarray(T)$
(%i5) np_shape(B);
(%o5)                        [3, 3]
```

## Definitions for dataframes

<!-- include: string-column.md -->
<!-- include: table.md -->
<!-- include: describe.md -->
<!-- include: manipulate.md -->
<!-- include: groupby.md -->
<!-- include: joins.md -->
<!-- include: duckdb.md -->
