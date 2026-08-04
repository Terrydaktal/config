# ASRock NCT6683 DKMS package

This local package builds the latest `main` branch of
[`branchmispredictor/asrock-nct6683`](https://github.com/branchmispredictor/asrock-nct6683)
as `asrock-nct6683-dkms-git`.

The package installs clean DKMS sources and a generated `dkms.conf` under
`/usr/src/asrock-nct6683-<version>`. It also installs a pacman hook that runs
after CachyOS kernel or header transactions. The hook rebuilds DKMS and checks
that every installed CachyOS kernel resolves `nct6683` to
`updates/dkms/nct6683.ko` (including compressed `.ko.zst` modules).

## Build and install

```bash
cd ~/Dev/config/packages/asrock-nct6683-dkms-git
makepkg --clean --force
pkexec pacman -U --noconfirm ./asrock-nct6683-dkms-git-*.pkg.tar.zst
```

The package depends on `dkms` and `linux-cachyos-headers`. For the optional LTS
fallback, install `linux-cachyos-lts`, `linux-cachyos-lts-headers`, and
`linux-cachyos-lts-nvidia-open`.

## Manual verification

```bash
pkexec /usr/lib/asrock-nct6683/verify-dkms
```

Do not reboot into a newly installed kernel until the verifier reports:

```text
*** ASRock NCT6683 DKMS verification passed. ***
```

Generated DKMS state under `/var/lib/dkms`, installed modules under
`/lib/modules`, package archives, and makepkg source caches are not tracked in
this configuration repository.
