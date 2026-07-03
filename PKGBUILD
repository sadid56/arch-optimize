# Maintainer: Sadid <your-email@example.com>
pkgname=arch-optimize-git
_pkgname=arch-optimize
pkgver=1.0.0
pkgrel=1
pkgdesc="Automated script to optimize Arch Linux for low-latency desktop use, gaming, and real-time audio workloads"
arch=('any')
url="https://github.com/sadid56/arch-optimize"
license=('GPL3')
depends=('bash' 'zram-generator' 'iproute2' 'pciutils' 'linux-zen' 'linux-zen-headers' 'ananicy-cpp')
makedepends=('git')
provides=("$_pkgname")
conflicts=("$_pkgname")
source=("git+${url}.git")
sha256sums=('SKIP')

pkgver() {
  cd "$srcdir/$_pkgname"
  printf "r%s.g%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

package() {
  cd "$srcdir/$_pkgname"
  
  # Install the main executable script
  install -Dm755 arch-optimize.sh "$pkgdir/usr/bin/arch-optimize"
  
  # Install module scripts
  install -d "$pkgdir/usr/share/arch-optimize/modules"
  install -m644 modules/*.sh "$pkgdir/usr/share/arch-optimize/modules/"
  
  # Install config templates
  install -d "$pkgdir/usr/share/arch-optimize/config"
  install -m644 config/* "$pkgdir/usr/share/arch-optimize/config/"
}
