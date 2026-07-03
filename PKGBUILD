# Maintainer: Sadid <your-email@example.com>
pkgname=artune-git
_pkgname=artune-git
pkgver=r4.gda67467
pkgrel=1
pkgdesc="Automated script to optimize Arch Linux for low-latency desktop use, gaming, and real-time audio workloads (artune)"
arch=('any')
url="https://github.com/sadid56/artune"
license=('GPL3')
depends=('bash' 'zram-generator' 'iproute2' 'pciutils' 'linux-zen' 'linux-zen-headers' 'ananicy-cpp')
makedepends=('git')
provides=("artune")
conflicts=("artune")
source=("git+${url}.git")
sha256sums=('SKIP')

pkgver() {
  cd "$srcdir/$_pkgname"
  printf "r%s.g%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

package() {
  cd "$srcdir/$_pkgname"
  
  # Install the main executable script
  install -Dm755 artune "$pkgdir/usr/bin/artune"
  
  # Install module scripts
  install -d "$pkgdir/usr/share/artune/modules"
  install -m644 modules/*.sh "$pkgdir/usr/share/artune/modules/"
  
  # Install config templates
  install -d "$pkgdir/usr/share/artune/config"
  install -m644 config/* "$pkgdir/usr/share/artune/config/"
}
