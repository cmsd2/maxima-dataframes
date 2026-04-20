## Column Aggregation and Describe

Column-level aggregation functions and `df_describe` for summary statistics. These functions work on individual columns (ndarray or string-column) and return scalars or new structures.

### Function: df_count (col)

Count the number of elements in a column. Works on both ndarray and string-column.

#### Examples

```maxima
(%i1) df_count(ndarray([1.0, 2.0, 3.0]));
(%o1)                          3
(%i2) df_count(df_string_column(["a", "b"]));
(%o2)                          2
```

See also: `df_nunique`, `df_describe`

### Function: df_median (col)

Median of a 1D ndarray. For even-length arrays, returns the average of the two middle values.

#### Examples

```maxima
(%i1) df_median(ndarray([3.0, 1.0, 2.0]));
(%o1)                         2.0
(%i2) df_median(ndarray([4.0, 1.0, 3.0, 2.0]));
(%o2)                         2.5
```

See also: `df_quantile`, `df_describe`

### Function: df_quantile (col, p)

Compute the p-quantile (0 to 1) of a 1D ndarray using linear interpolation (NumPy default method).

#### Examples

```maxima
(%i1) a : ndarray([3.0, 1.0, 4.0, 1.0, 5.0, 9.0, 2.0, 6.0])$
(%i2) df_quantile(a, 0.25);
(%o2)                         1.75
(%i3) df_quantile(a, 0.5);
(%o3)                         3.5
(%i4) df_quantile(a, 0.75);
(%o4)                         5.75
```

See also: `df_median`, `df_describe`

### Function: df_unique (col)

Return a new string-column with the unique values from a string-column, preserving first-occurrence order.

#### Examples

```maxima
(%i1) sc : df_string_column(["a", "b", "a", "c", "b"])$
(%i2) df_to_string_list(df_unique(sc));
(%o2)                      [a, b, c]
```

See also: `df_nunique`, `df_value_counts`

### Function: df_nunique (col)

Count of unique values in a column. Works on both ndarray and string-column.

#### Examples

```maxima
(%i1) df_nunique(df_string_column(["a", "b", "a", "c"]));
(%o1)                          3
(%i2) df_nunique(ndarray([1.0, 2.0, 1.0, 3.0]));
(%o2)                          3
```

See also: `df_unique`, `df_value_counts`

### Function: df_value_counts (col)

Frequency table for a column, returned as a `df_table` with columns `"value"` and `"count"`, sorted by count descending. Works on string-columns and ndarrays.

#### Examples

```maxima
(%i1) sc : df_string_column(["a", "b", "a", "c", "b", "a"])$
(%i2) vc : df_value_counts(sc)$
(%i3) df_table_names(vc);
(%o3)                    [value, count]
(%i4) df_to_string_list(df_table_column(vc, "value"));
(%o4)                      [a, b, c]
(%i5) np_to_list(df_table_column(vc, "count"));
(%o5)                  [3.0, 2.0, 1.0]
```

See also: `df_nunique`, `df_unique`

### Function: df_describe (T)

Summary statistics for the numeric columns of a table. Returns a new `df_table` with a `"stat"` string-column labeling each row and one ndarray column per numeric input column. String columns are skipped.

The statistics computed are: count, mean, std (sample, n-1 denominator), min, 25%, 50% (median), 75%, max.

#### Examples

```maxima
(%i1) prices : ndarray([10.0, 20.0, 30.0, 40.0, 50.0])$
(%i2) names : df_string_column(["A", "B", "C", "D", "E"])$
(%i3) T : df_table(["name", "price"], [names, prices])$
(%i4) df_describe(T);
(%o4)              df_table: 8 rows x 2 cols
(%i5) df_table_names(df_describe(T));
(%o5)                    [stat, price]
```

See also: `df_median`, `df_quantile`, `df_count`
