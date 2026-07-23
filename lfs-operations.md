# Git LFS Operations Tutorial

This repository stores large circuit artifacts (such as `.zkey` and `.wasm` files) with Git LFS. Git records a small pointer file in normal Git; the original binary is stored and transferred by Git LFS.

## Prerequisite

Install Git LFS once on each machine:

```bash
git lfs install
```

## Clone a new checkout

```bash
git clone git@github.com:currensa/pact-circuits-compiled.git
cd pact-circuits-compiled
```

When Git LFS is installed, cloning normally downloads the original LFS files automatically. If a file contains text beginning with `version https://git-lfs.github.com/spec/v1`, it is an LFS pointer and its binary object was not downloaded. Restore all originals with:

```bash
git lfs pull
```

A separate `git pull` is not needed immediately after a new clone.

## Update an existing checkout

```bash
git pull
git lfs pull
```

`git pull` updates the Git commits and the LFS pointers they reference. `git lfs pull` downloads the binary objects for those pointers. In many configurations, `git pull` downloads them automatically; run `git lfs pull` when files are still pointers or LFS downloads were previously disabled.

## Update and push an existing LFS file

First ensure the original binary has been downloaded, then edit or replace it. Do not edit an LFS pointer file directly.

```bash
git lfs pull
# edit or replace path/to/file.zkey
git add path/to/file.zkey
git commit -m "Update proving key"
git push
```

`git push` uploads the new LFS object, then pushes the Git commit that points to it.

## Add a new large-file type

Track the pattern before adding the file:

```bash
git lfs track "*.zkey" "*.wasm"
git add .gitattributes path/to/new-file.zkey
git commit -m "Add LFS-tracked artifact"
git push
```

## Verify LFS state

```bash
git lfs ls-files
git status
```

In `git lfs ls-files`, a leading `*` means the LFS object is available locally. A leading `-` means only its pointer is present and you should run `git lfs pull`.

## Troubleshooting

- If `git lfs pull` returns an authorization error, authenticate with an account that can access the repository's LFS storage.
- If it reports that an object does not exist, the original binary was not uploaded to LFS or has been removed from the server; it cannot be restored from the pointer alone.
