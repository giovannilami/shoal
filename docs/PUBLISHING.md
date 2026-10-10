# Manual publishing checklist

Nothing in this repository publishes itself. The maintainer decides when and where to share it.

## Before going public

1. The README and script preview now credit the GitHub handle `@giovannilami`. Review whether that is the public attribution you want; you can change it before making the repository public.
2. Review [README.md](../README.md), [LICENSE](../LICENSE) and [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md). The original Shoal concept and adapted musical core belong in the Ormer Modular credit; the norns UI/routing work belongs to this port.
3. Run `./test/run.sh` with Lua 5.3. The singular `test/` name keeps these development files out of the norns SELECT menu. Test on norns once more with PolyPerc, MIDI, pset save/recall and, if available, 16 × 8 Grid. Crow remains marked unverified unless you test it.
4. Check that no personal psets, MIDI maps, recordings, logs or account details were added to the folder. This repository intentionally contains source and documentation only.

## GitHub repository check

1. The repository is at `https://github.com/giovannilami/shoal-norns`. Keep it **private** until you are satisfied with the tested build, credits and licence; changing its visibility is a separate decision.
2. At the repository root you should see `shoal-norns.lua`, `lib/`, `docs/`, `test/`, `README.md`, `LICENSE` and `THIRD_PARTY_NOTICES.md`. The tests directory must be **`test/` singular**, not `tests/`, or norns may show test scripts in SELECT. Do not upload a tarball as the only repository file, and do not create an extra `shoal-norns/shoal-norns/` nesting.
3. The repository URL is already inserted in the README and [LINES_POST.md](LINES_POST.md). Verify the links after upload.
4. Verify that the README diagrams render on GitHub and every Lua file has content. The download/archive is not a substitute for this repository-root check.

For someone installing from a public repository, the [monome Maiden command](https://monome.org/docs/norns/reference/) is:

```text
;install https://github.com/giovannilami/shoal-norns
```

Your current norns may have a manually copied `shoal-norns` directory rather than a Maiden-managed Git checkout. Do not overwrite or delete that working copy just to test the installer; back it up first or try a clean device. Monome notes that Maiden's update mechanism treats manually installed scripts differently from project-manager installs.

## lines and norns.community — also manual

1. Create a new topic in the [norns Library on lines](https://llllllll.co/c/library). [LINES_POST.md](LINES_POST.md) is a draft you can adapt and paste. Attach a real screen/Grid photo or a short performance video if you want; the SVGs in this repository are explanatory drawings.
2. Copy the new lines topic URL. Add it to the preview comment at the very top of `shoal-norns.lua`, together with your chosen public handle, then upload that small change to GitHub. This is the sequence [monome recommends for community scripts](https://monome.org/docs/norns/community-scripts/).
3. Optionally submit a pull request to [monome/norns-community](https://github.com/monome/norns-community) adding an entry to `community.json` with project URL, author, short description, documentation URL, lines discussion URL and tags. The monome guide says that merged entries are listed by norns.community.

The repository remains private until the maintainer chooses to announce it. A lines topic and community-catalog entry are separate publication steps.
