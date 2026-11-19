# setup-wangpkg

GitHub Action to install [wangpkg](https://github.com/startracex/wangpkg) and add it to `PATH`.

## Usage

```yaml
steps:
  - uses: actions/checkout@v7
  - uses: startracex/setup-wangpkg@v1
  - run: wangpkg install --locked
```

Pin a version:

```yaml
- uses: startracex/setup-wangpkg@v1
  with:
    version: 0.1.0
```

When `version` is omitted, the action infers from the manifest:

1. `packageManager` — e.g. `"wangpkg@0.1.0"`
2. `devEngines.packageManager` — name `wangpkg`, version may be a range
3. otherwise uses the `latest` dist-tag

Pass a dist-tag explicitly to skip the manifest, e.g. `version: latest` or `version: next`.

```json
{
  "packageManager": "wangpkg@0.1.0"
}
```

```json
{
  "devEngines": {
    "packageManager": {
      "name": "wangpkg",
      "version": "^0.1.0"
    }
  }
}
```

## Inputs

| Name | Default | Description |
| --- | --- | --- |
| `version` | `""` | Exact semver, range, or dist-tag. Empty → infer from manifest, else `latest`. |
| `manifest` | `"package.json"` | Package manifest path (relative to the job working directory). |

## Outputs

| Name | Description |
| --- | --- |
| `version` | Installed wangpkg version |
| `path` | Directory containing the `wangpkg` binary |

## Requirements

Runs on GitHub-hosted `ubuntu-*`, `windows-*`, and `macos-*` runners (needs `bash`, `curl`, `tar`, `node`, and `npm`).

## License

[MIT](LICENSE)
