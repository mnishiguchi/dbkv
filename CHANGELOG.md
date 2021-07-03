# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.2] - 2021-07-03

**Added**
- `select_by_value/2` and `delete_by_value/2`

## [0.2.1] - 2021-07-02

**Fixed**
- Handle error in `select_by_match_spec/3`
- Fix incorrect range match specs

**Added**
- `all/2`
- `init_table/2`

## [0.2.0] - 2021-07-02

**Changed**
- Table name defaults to `DBKV` if not specified in `open/1` options.
- Arguments of `select_by_*` and `delete_by_*` functions

**Removed**
- deprecated functions
  - `create_table/1`
  - `delete_table/1`
  - `describe_table/1`
  - `exist?/1`

## [0.1.4] - 2021-07-01

**Added**
- `open?/1` deprecating `exist?/1`

## [0.1.3] - 2021-07-01

**Added**
- `info/1`, which deprecated `describe_table/1`
- `open/1` and `close/1`, which deprecates `create_table/1` and `delete_table/1`

## [0.1.2] - 2021-06-30

**Changed**
- Always warnings as errors
- Let it crash when table not exist following [Chris Keathley's advice](https://keathley.io/blog/good-and-bad-elixir.html)

**Added**
- `delete_all` and `delete_by_*`
- `increment` and `decrement`
- `all`, `keys` and `values`

## [0.1.1] - 2021-06-30

**Changed**
- Rename `DubDB` to `DBKV`

## [0.1.0] - 2021-06-29

Initial release

[Unreleased]: https://github.com/mnishiguchi/dbkv/compare/v0.2.2...HEAD
[0.2.2]: https://github.com/mnishiguchi/dbkv/releases/tag/v0.2.2
[0.2.1]: https://github.com/mnishiguchi/dbkv/releases/tag/v0.2.1
[0.2.0]: https://github.com/mnishiguchi/dbkv/releases/tag/v0.2.0
[0.1.4]: https://github.com/mnishiguchi/dbkv/releases/tag/v0.1.4
[0.1.3]: https://github.com/mnishiguchi/dbkv/releases/tag/v0.1.3
[0.1.2]: https://github.com/mnishiguchi/dbkv/releases/tag/v0.1.2
[0.1.1]: https://github.com/mnishiguchi/dbkv/releases/tag/v0.1.1
[0.1.0]: https://github.com/mnishiguchi/dbkv/releases/tag/v0.1.0
