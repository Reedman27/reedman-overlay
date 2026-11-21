# Equibop on Debian-family systems

The build script mirrors the upstream amd64 `.deb` into `out/` without modifying its
control metadata. This package can be served from the ReedMuhn APT repository and
installed on Debian, Ubuntu, Linux Mint, antiX, MX Linux, and Devuan where the
upstream package dependencies are available. Devuan users must keep Devuan's own
APT repositories configured; do not add Debian repositories to Devuan.
