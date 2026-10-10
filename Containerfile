FROM quay.io/fedora/fedora-bootc:44

# Set by the release workflow: vX.Y.Z for production, dev-<commit> for dev.
ARG VERSION=local
ARG REVISION=unknown

COPY system_files/ /

# tailscale comes from Tailscale's repository (system_files/etc/yum.repos.d).
# ncurses-term carries the ghostty terminfo entry that xterm-ghostty extends.
RUN dnf -y install \
        chromium \
        cloud-init \
        distrobox \
        firewalld \
        git \
        libatomic \
        ncurses-term \
        qemu-guest-agent \
        qrencode \
        tailscale \
        zsh \
    && dnf clean all \
    && rm -rf /var/cache/* /var/log/* /var/lib/dnf /var/lib/authselect /run/cloud-init /run/dnf

# Ghostty sets TERM=xterm-ghostty; ncurses only ships the entry as ghostty.
RUN printf 'xterm-ghostty|Ghostty,\n\tuse=ghostty,\n' > /tmp/xterm-ghostty.src \
    && tic -x -o /usr/share/terminfo /tmp/xterm-ghostty.src \
    && rm /tmp/xterm-ghostty.src

# cloud-init only starts where its generator finds a datasource, and
# qemu-guest-agent only where the hypervisor exposes its virtio port, so
# both stay inactive on bare metal.
RUN systemctl enable firewalld tailscaled \
    && sed -i 's|^SHELL=.*|SHELL=/usr/bin/zsh|' /etc/default/useradd \
    && setsebool -P virt_qemu_ga_read_nonsecurity_files on \
    && firewall-offline-cmd --zone=public --remove-service-from-zone=mdns \
    && firewall-offline-cmd --zone=public --remove-service-from-zone=dhcpv6-client \
    && firewall-offline-cmd --zone=trusted --add-interface=tailscale0

# Release marker: IMAGE_VERSION in os-release, and the OCI version label
# that `bootc status` shows.
RUN printf 'IMAGE_ID=atelieros\nIMAGE_VERSION=%s\n' "$VERSION" >> /usr/lib/os-release
LABEL org.opencontainers.image.title="AtelierOS" \
      org.opencontainers.image.source="https://github.com/jeremytondo/atelieros" \
      org.opencontainers.image.version="$VERSION" \
      org.opencontainers.image.revision="$REVISION"

RUN bootc container lint --fatal-warnings
