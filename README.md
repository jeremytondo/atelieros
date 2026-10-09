# AtelierOS

A personal, headless, image-based OS built on [Fedora bootc](https://docs.fedoraproject.org/en-US/bootc/). Machines run a released image, download new versions in the background, apply them when the developer chooses, and can roll back.

The image carries only the system. Development tools, mise itself and dotfiles live in the user's mise-managed environment. Machine details such as the hostname, user account and SSH keys come from provisioning: cloud-init on VMs, and a kickstart on bare metal.

The image is public at `ghcr.io/jeremytondo/atelieros`. It must never contain secrets, user accounts, SSH keys or hostnames.

## What's in the image

On top of `quay.io/fedora/fedora-bootc:44`, which already has openssh-server, podman, toolbox, sudo and NetworkManager:

- **Packages:** git, zsh, libatomic, `xterm-ghostty` terminfo, Tailscale, cloud-init, qemu-guest-agent, distrobox, Chromium and firewalld.
- **Shell:** zsh is the default login shell for new users.
- **SSH:** key authentication only. Password authentication and root login are rejected.
- **SELinux:** enforcing, with `virt_qemu_ga_read_nonsecurity_files` on.
- **ptrace:** `kernel.yama.ptrace_scope = 1`.
- **Firewall:** the default zone (`public`) accepts SSH only. The Tailscale interface is in the `trusted` zone. VMs opt out through cloud-init.
- **Updates:** the bootc update timer downloads new versions but never applies them or reboots.
- **Root filesystem:** XFS, for disk images and `bootc install`.

cloud-init and qemu-guest-agent stay inactive on bare metal. Tailscale runs but joins the tailnet only when someone enrolls the machine.

Check which version a machine runs with `bootc status`, or:

```sh
grep IMAGE_VERSION /etc/os-release
```

Production images report `vX.Y.Z`. `dev` images report `dev-<commit>`.

## Releases

Releases are cut by one GitHub Actions workflow, dispatched from mise:

| Command | Result |
| -- | -- |
| `mise run release:dev` | Builds `main` and pushes it as `:dev`. |
| `mise run release:dev --ref <branch>` | Builds a pushed branch as `:dev`. |
| `mise run release:patch` | Cuts the next `vX.Y.Z` patch release from `main`. |
| `mise run release:minor` | Cuts the next minor release. |
| `mise run release:major` | Cuts the next major release. |

A production release does the following:

1. It computes the next version from the repository's tags and tags the commit.
2. It builds the image from that commit and pushes it as `:vX.Y.Z`.
3. It builds a qcow2 disk image from it with [image-builder](https://github.com/osbuild/image-builder). The file isn't wrapped in `.xz` or similar, so Proxmox can import it directly. Like Fedora's cloud images, it's compressed inside the qcow2 format.
4. It moves `:stable` to the new image.
5. It creates a GitHub Release with the qcow2 and its sha256 checksum.

`dev` builds produce no qcow2, git tag or GitHub Release.

A production release rebuilds the image from its commit rather than retagging `:dev`, so it may include Fedora updates newer than the last `dev` build.

Production tags, images and releases are never moved, edited or deleted. If a production run fails, re-run it: it resumes the same version rather than skipping to the next one.

Every Monday the workflow cuts a patch release from `main`, so Fedora's updates reach `:stable` without anyone remembering. GitHub disables scheduled workflows after 60 days without repository activity. If the weekly releases stop, re-enable the workflow in the Actions tab.

To check the image locally before releasing, run `mise run build`. It builds with podman or docker and runs `bootc container lint`.

## Updating a machine

Machines track `:stable`. Every 8 hours or so, the update timer downloads any newer version without applying it. `bootc status` shows a downloaded update as staged.

To apply it, run:

```sh
sudo bootc upgrade --from-downloaded --apply
```

This reboots into the new version. A downloaded update that's never applied is discarded at the next reboot and downloaded again afterwards.

To fetch and apply right away, without waiting for the timer:

```sh
sudo bootc upgrade --apply
```

OS updates and rollbacks never touch home directories, mise tools or project files.

## Rolling back

To return to the previous version, run:

```sh
sudo bootc rollback
sudo systemctl reboot
```

bootc keeps one previous version. To go back further, switch to a specific release:

```sh
sudo bootc switch ghcr.io/jeremytondo/atelieros:v1.2.3
```

That machine then stays on `v1.2.3`. Switch back to `:stable` to resume updates.

## Switching channels

To test a `dev` build on one machine, run:

```sh
sudo bootc switch ghcr.io/jeremytondo/atelieros:dev
sudo systemctl reboot
```

To return to `:stable`, run:

```sh
sudo bootc switch ghcr.io/jeremytondo/atelieros:stable
sudo systemctl reboot
```

## Adding an OS package

OS packages are never installed on a running machine. dnf refuses to install on bootc anyway.

1. Add the package to the `dnf -y install` list in the `Containerfile`.
2. Run `mise run build` to check that it builds and lints.
3. Commit and push, then run `mise run release:dev`.
4. Switch a machine to `:dev` and check the change.
5. Run `mise run release:patch`, and switch the test machine back to `:stable`.

For a one-off tool, use a distrobox container instead, for example an Arch container with the AUR. For a temporary experiment, `sudo bootc usr-overlay` makes `/usr` writable until the next reboot.

## Upgrading Fedora

A new Fedora major version is a change to the base tag in the `Containerfile`, for example from `fedora-bootc:44` to `fedora-bootc:45`.

1. Change the tag, and run `mise run build`.
2. Release it to `:dev` and test it on one machine.
3. Cut a production release. `mise run release:minor` makes the jump visible in the version number.

Machines receive it through the normal update path. If the new version misbehaves, `sudo bootc rollback` returns to the previous Fedora.

## Repository layout

| Path | Purpose |
| -- | -- |
| `Containerfile` | The image: packages, configuration and the release marker |
| `system_files/` | Files copied into the image's root |
| `mise.toml` | The build and release tasks |
| `.github/workflows/release.yml` | The release workflow and its weekly schedule |
