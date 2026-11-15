#!/usr/bin/env bash
# Needed for the rpm and arch builds only; the Debian build no longer uses Cider's apt repo.
# Download Cider Collective's three signing keys into keys/ and sanity-check them.
# The Arch key is pinned to the fingerprint Cider publishes; the others are printed
# so you can eyeball them. REPO_BASE overrides the host (used by the tests).
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
BASE="${REPO_BASE:-https://repo.cider.sh}"
ARCH_FPR="${ARCH_FPR:-A0CD6B993438E22634450CDD2A236C3F42A61682}"
mkdir -p "$HERE/keys"
for k in APT-GPG-KEY RPM-GPG-KEY ARCH-GPG-KEY; do
	curl -fsSL "$BASE/$k" -o "$HERE/keys/$k.tmp"
	if ! gpg --show-keys --with-colons "$HERE/keys/$k.tmp" | grep -q '^pub:'; then
		echo "$k is not a PGP public key (got an error page?)" >&2
		rm -f "$HERE/keys/$k.tmp"; exit 1
	fi
	mv "$HERE/keys/$k.tmp" "$HERE/keys/$k"
	echo "== $k"; gpg --show-keys --with-colons "$HERE/keys/$k" | awk -F: '/^fpr/{print "   " $10}'
done
gpg --show-keys --with-colons "$HERE/keys/ARCH-GPG-KEY" | grep -q ":$ARCH_FPR:" \
	|| { echo "ARCH-GPG-KEY does not contain pinned fingerprint $ARCH_FPR" >&2; exit 1; }
echo "keys OK"
