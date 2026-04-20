# dataframes

[![Docs](https://img.shields.io/badge/docs-online-blue)](https://cmsd2.github.io/maxima-dataframes/)

Pandas-like tabular data for Maxima (SBCL only). Provides string-columns and mixed-type tables for working with real-world datasets that combine numeric and categorical data.

## Install

Install locally during development:

```
mxpm install --path . --editable
```

Or copy-install:

```
mxpm install --path .
```

## Usage

```maxima
load("dataframes");
names : df_string_column(["Alice", "Bob", "Charlie"])$
scores : ndarray([95.0, 87.0, 92.0])$
T : df_table(["name", "score"], [names, scores]);
```

### DuckDB integration (optional)

The `dataframes-duckdb` extension adds CSV/Parquet/JSON I/O, SQL queries, and DuckDB-accelerated operations. It requires `libduckdb`:

```
brew install duckdb   # macOS
```

Then load it separately:

```maxima
load("dataframes-duckdb");
T : df_read_csv("/path/to/data.csv")$
df_sql("SELECT * FROM read_csv('data.csv') WHERE price > 10");
```

## Documentation

Build documentation artifacts (`.info` and help index):

```
mxpm doc build
```

Live preview with mdBook:

```
mxpm doc serve
```

## License

MIT
