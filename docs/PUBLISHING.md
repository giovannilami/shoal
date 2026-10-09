# Community release checklist

Nothing in this repository publishes itself. The maintainer decides when and where to share it.

## Before sharing on lines

1. The README and script preview credit the GitHub handle `@giovannilami`. Confirm that this is the attribution you want to use in the lines announcement.
2. Review [README.md](../README.md), [LICENSE](../LICENSE) and [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md). The original Shoal concept and adapted musical core belong in the Ormer Modular credit; the norns UI/routing work belongs to this port.
3. Run `./tests/run.sh` with Lua 5.3. Test on norns once more with PolyPerc, MIDI, pset save/recall and, if available, 16 × 8 Grid. Crow remains marked unverified unless you test it.
4. Check that no personal psets, MIDI maps, recordings, logs or account details were added to the folder. This repository intentionally contains source and documentation only.

## GitHub — repository checks

1. The repository is public at `https://github.com/giovannilami/shoal-norns`. Review the credits and licence before announcing it on lines.
2. Keep the script files at the repository root: `shoal-norns.lua`, `lib/`, `docs/`, `README.md`, `LICENSE` and `THIRD_PARTY_NOTICES.md`. Do not replace them with only a tarball or add an extra `shoal-norns/shoal-norns/` nesting.
3. The repository URL is in the README and [LINES_POST.md](LINES_POST.md). Verify the links after future updates.
4. After future uploads, verify that the README diagrams render on GitHub and every Lua file has content. The download/archive is not a substitute for this repository-root check.

The [monome Maiden installation command](https://monome.org/docs/norns/reference/) is:

```text
;install https://github.com/giovannilami/shoal-norns
```

Your current norns may have a manually copied `shoal-norns` directory rather than a Maiden-managed Git checkout. Do not overwrite or delete that working copy just to test the installer; back it up first or try a clean device. Monome notes that Maiden's update mechanism treats manually installed scripts differently from project-manager installs.

## lines and norns.community — also manual

1. Create a new topic in the [norns Library on lines](https://llllllll.co/c/library). [LINES_POST.md](LINES_POST.md) is a draft you can adapt and paste. Attach a real screen/Grid photo or a short performance video if you want; the SVGs in this repository are explanatory drawings.
2. Copy the new lines topic URL. Add it to the preview comment at the very top of `shoal-norns.lua`, together with your chosen public handle, then upload that small change to GitHub. This is the sequence [monome recommends for community scripts](https://monome.org/docs/norns/community-scripts/).
3. Optionally submit a pull request to [monome/norns-community](https://github.com/monome/norns-community) adding an entry to `community.json` with project URL, author, short description, documentation URL, lines discussion URL and tags. The monome guide says that merged entries are listed by norns.community.

The GitHub repository is public and its files were uploaded by the maintainer. No lines topic or community-catalog entry has been created yet.
