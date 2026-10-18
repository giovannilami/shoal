# Manual publishing checklist

Nothing in this repository publishes itself. The maintainer decides when and where to share it.

## Release checks

1. The README and script preview credit the GitHub handle `@giovannilami`. Review this attribution before each release.
2. Review [README.md](../README.md), [LICENSE](../LICENSE) and [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md). The original Shoal concept and adapted musical core belong in the Ormer Modular credit; the norns UI/routing work belongs to this port.
3. Run `./test/run.sh` with Lua 5.3. The singular `test/` name keeps these development files out of the norns SELECT menu. Test on norns once more with PolyPerc, MIDI, pset save/recall and, if available, 16 × 8 Grid. Crow remains marked unverified unless you test it.
4. Check that no personal psets, MIDI maps, recordings, logs or account details were added to the folder. This repository intentionally contains source and documentation only.

## GitHub repository check

1. The public repository is at `https://github.com/giovannilami/shoal`. The old `shoal-norns` GitHub URL should redirect after GitHub's Rename action; use the new URL in all documentation and new installs.
2. At the repository root you should see `shoal.lua`, `lib/`, `docs/`, `test/`, `README.md`, `LICENSE` and `THIRD_PARTY_NOTICES.md`. The tests directory must be **`test/` singular**, not `tests/`, or norns may show test scripts in SELECT. Do not upload a tarball as the only repository file, and do not create an extra `shoal/shoal/` nesting.
3. The repository URL is already inserted in the README and [LINES_POST.md](LINES_POST.md). Verify the links after upload.
4. Verify that the README diagrams render on GitHub and every Lua file has content. The download/archive is not a substitute for this repository-root check.

For someone installing from a public repository, the [monome Maiden command](https://monome.org/docs/norns/reference/) is:

```text
;install https://github.com/giovannilami/shoal
```

Your current norns may have a manually copied `shoal-norns` directory rather than a Maiden-managed Git checkout. Move the old directory out of `dust/code` before installing `shoal`, or both names can appear in SELECT. Keep a backup of `/home/we/dust/data/shoal-norns/` if you have old psets; the new script name uses a separate data directory. Do not overwrite or delete the working copy just to test the installer. Monome notes that Maiden's update mechanism treats manually installed scripts differently from project-manager installs.

## lines and norns.community — also manual

1. The [Shoal topic on lines](https://llllllll.co/t/shoal-generative-melodies-for-norns/75630) is public. [LINES_POST.md](LINES_POST.md) remains a reusable draft; the live topic is authoritative. Attach a real screen/Grid photo or a short performance video if you want; the SVGs in this repository are explanatory drawings.
2. Add the lines topic URL to the preview comment at the very top of `shoal.lua` in a later metadata update if desired. This is the sequence [monome recommends for community scripts](https://monome.org/docs/norns/community-scripts/).
3. Optionally submit a pull request to [monome/norns-community](https://github.com/monome/norns-community) adding an entry to `community.json` with project URL, author, short description, documentation URL, lines discussion URL and tags. The monome guide says that merged entries are listed by norns.community.

The repository and lines topic are public. A community-catalog entry is a separate publication step.
