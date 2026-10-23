# Publishing NeedleNet

Repository: https://github.com/GlebTikhiy/NeedleNet

This is an independently hosted derivative of the co-op maintenance base credited in NOTICE.md. Its GitHub repository is not marked as an upstream fork. Original copyright and license notices remain intact.

1. Review changes and run applicable tests. Update version/build metadata when necessary.
2. Run `python build_release.py` to create the named player ZIP and SHA-256 file in `dist/`.
3. Tag the reviewed commit. The first preview uses `v0.1.0-preview.2`.
4. Create a GitHub prerelease using `docs/RELEASE-NOTES.md` and attach the ZIP and checksum.
5. Update README and creator-guide links when the recommended release changes.

Never upload game binaries, personal settings, saves, raw diagnostics or private game installations. Test drivers, publication notes and detailed test reports belong in the source repository, not the player ZIP.

Improvements can also be offered to upstream as a separate pull request. Maintaining a public derivative and contributing upstream are independent actions.
