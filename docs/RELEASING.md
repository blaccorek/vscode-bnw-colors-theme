# Releasing

Publishing is automated by [`.github/workflows/release.yml`](../.github/workflows/release.yml).
The **`version` field in `package.json` is the source of truth** for the published
version: `npm version` bumps it and creates the matching tag, and the workflow only
reads it. On a tag push the workflow checks that the tag equals `v<version>` and
fails on a mismatch, so a tag can never publish a different version.

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
2. Commit the changelog, then cut the release with `npm version`, which bumps
   `package.json`, commits that bump and creates the `v0.0.10` tag:

   ```sh
   npm version patch   # or minor / major / 0.0.10
   git push origin main --follow-tags
   ```

The workflow then:

- packages the extension as `vscode-bnw-colors-theme-x.y.z.vsix`
- publishes it to the VS Code Marketplace
- creates a GitHub release for the tag with the changelog section as notes and the
  `.vsix` attached
- uploads the `.vsix` as a workflow artifact

## Re-running a failed publish

Use **Actions > Release > Run workflow** and pick the tag to publish (for example
`v0.0.10`) as the ref. It publishes the version in that ref's `package.json` without
needing a new tag; if the GitHub release already exists, only the `.vsix` asset is
refreshed.

## Building locally

```sh
npx @vscode/vsce package
```
