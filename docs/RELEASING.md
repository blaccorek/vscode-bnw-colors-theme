# Releasing

Publishing is automated by [`.github/workflows/release.yml`](../.github/workflows/release.yml).
The **git tag is the source of truth** for the published version: the workflow writes
that version into `package.json` before packaging, so a tag can never publish a
mismatched version.

## One-time setup

1. Create a publisher on the [Marketplace management page](https://marketplace.visualstudio.com/manage)
   if `blaccorek` does not exist yet.
2. Create an Azure DevOps Personal Access Token:
   - organization **All accessible organizations**
   - scope **Marketplace > Manage**
3. Add it to the repo as a secret named `VSCE_PAT`
   (Settings > Secrets and variables > Actions > New repository secret).

PATs expire (max 1 year). When publishing fails with a 401, regenerate the token
and update the secret.

## Cutting a release

1. Add a `## [x.y.z]` section to [`CHANGELOG.md`](../CHANGELOG.md) describing the changes.
   Those bullets become the GitHub release notes.
2. Commit, then tag and push:

   ```sh
   git tag v0.0.10
   git push origin main --follow-tags
   ```

Bumping `version` in `package.json` is optional — the workflow sets it from the tag —
but keeping it in sync avoids confusion when packaging locally.

The workflow then:

- packages the extension as `vscode-bnw-colors-theme-x.y.z.vsix`
- publishes it to the VS Code Marketplace
- creates a GitHub release for the tag with the changelog section as notes and the
  `.vsix` attached
- uploads the `.vsix` as a workflow artifact

## Re-running a failed publish

Use **Actions > Release > Run workflow** and enter the version (for example `0.0.10`).
It does the same thing without needing a new tag; if the GitHub release already
exists, only the `.vsix` asset is refreshed.

## Building locally

```sh
npx @vscode/vsce package
```
