# Repositori Lokal untuk Paket Kustom NusaOS

Alur kerja `mkarchiso` dan `pacstrap` tidak dapat mengunduh atau mengompilasi paket langsung dari AUR. Kami memutuskan untuk menggunakan repositori paket lokal (`customrepo`) yang dikelola via `repo-add` dan didaftarkan pada `pacman.conf` archiso. Keputusan ini membutuhkan langkah kompilasi paket mandiri sebelum ISO dibangun, namun menjamin proses build bersifat offline-capable, deterministik, dan dapat direproduksi tanpa kegagalan koneksi ke AUR.
