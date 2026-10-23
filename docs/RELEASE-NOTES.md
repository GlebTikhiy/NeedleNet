# NeedleNet 0.1.0-preview.4

Fixed guest-only duplicate conveyor cargo when a predicted seam transfer met a partial update of the source belt. The host quantity remained authoritative; the older predicted copy is now removed before restoring the incoming record.

Automated hardening used four real game processes and native physics: 256 conveyor segments in closed loops, 4,096 physical hay wads, a rendered D3D12 host, bad Wi-Fi, five- and 45-second outages, actual host termination and checkpoint restoration. The large factory preserved 204,800 strands on the host. Shared money/technology and personal tool ownership also passed. Detailed measurements, regression evidence and limits are in the [release QA report](https://github.com/GlebTikhiy/NeedleNet/blob/v0.1.0-preview.4/docs/RELEASE-QA.md).

When the host disappears, guests return to the menu after the connection timeout. There is no host migration. Restart the host, load its save and rejoin; unsaved progress rolls back to the checkpoint.

This remains a preview. Long playthroughs, every production chain and separate-PC Steam fault injection are not covered by these local tests. Native tool tutorial hints remain shared.

Every participant must update together. Requires Windows Steam Demo build 25963876. Extract `NeedleNet-0.1.0-preview.4-Windows.zip`, close the game and run `Install.cmd`. Existing mod/configuration files are backed up. Credits and license notices are preserved.
