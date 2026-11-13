#!/usr/bin/env bash
set -euo pipefail

SUITE="${SUITE:-trixie}"
COMPONENT="main"
ARCH="amd64"
KEYID="${GPG_KEY_ID:?Falta la variable GPG_KEY_ID}"
REPO_URL="${REPO_URL:-https://dannyxd300.github.io/kebianos-apt}"
ROOT="$(pwd)"
SITE="$ROOT/site"

sign() {
  if [ -n "${GPG_PASSPHRASE:-}" ]; then
    printf '%s' "$GPG_PASSPHRASE" | gpg --batch --yes --pinentry-mode loopback \
        --passphrase-fd 0 --default-key "$KEYID" "$@"
  else
    gpg --yes --default-key "$KEYID" "$@"
  fi
}

rm -rf "$SITE"
mkdir -p "$SITE/pool/$COMPONENT" "$SITE/dists/$SUITE/$COMPONENT/binary-$ARCH"

shopt -s nullglob
debs=("$ROOT"/debs/*.deb)
[ "${#debs[@]}" -gt 0 ] || { echo "No hay .deb en debs/"; exit 1; }
cp "${debs[@]}" "$SITE/pool/$COMPONENT/"

cd "$SITE"

PKG="dists/$SUITE/$COMPONENT/binary-$ARCH/Packages"
dpkg-scanpackages --arch "$ARCH" "pool/$COMPONENT" /dev/null > "$PKG"
test -s "$PKG" || { echo "Packages quedó vacío"; exit 1; }
gzip -9 -k -n "$PKG"
xz   -9 -k    "$PKG"

apt-ftparchive -c "$ROOT/conf/apt-release.conf" release "dists/$SUITE" \
    > "dists/$SUITE/Release"

sign --armor --detach-sign -o "dists/$SUITE/Release.gpg" "dists/$SUITE/Release"
sign --clearsign           -o "dists/$SUITE/InRelease"   "dists/$SUITE/Release"
gpg --verify "dists/$SUITE/InRelease"

cp "$ROOT"/keys/kebianos-archive-keyring.gpg "$ROOT"/keys/kebianos-archive-keyring.asc .

cat > index.html << HTML
<!doctype html><meta charset="utf-8"><title>Repositorio KebianOS</title>
<h1>Repositorio APT de KebianOS</h1>
<p>URL del repositorio: $REPO_URL/</p>
HTML

echo "Repositorio generado en $SITE"
