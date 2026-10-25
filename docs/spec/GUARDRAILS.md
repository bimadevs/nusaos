# NusaOS Architectural Guardrails & Pitfall Prevention

Dokumen ini memuat aturan tak-dapat-ditawar (*non-negotiable constraints*), mitigasi kegagalan kritis, dan batas ketat (*guardrails*) untuk memastikan setiap modifikasi oleh agen AI berjalan presisi tanpa menyebabkan kegagalan build `mkarchiso`.

---

## 1. Aturan Validasi Archiso (`profiledef.sh`)

1. **Format Identifier `install_dir`**:
   - *Target Positif*: Gunakan string `"nusaos"` (hanya huruf kecil alfanumerik `[a-z0-9]`, panjang maksimal 30 karakter).
   - *Anti-Pattern*: Jangan menyertakan tanda hubung (`-`), garis bawah (`_`), huruf kapital, atau spasi (contoh salah: `nusa-os`, `NusaOS`).

2. **Kombinasi Bootloader Saling Mengunci (*Mutual Exclusivity*)**:
   - *Target Positif*: Gunakan `bootmodes=('bios.syslinux' 'uefi.systemd-boot')`.
   - *Anti-Pattern*: Jangan memasukkan `uefi.systemd-boot` dan `uefi.grub` secara bersamaan di dalam array `bootmodes`. `mkarchiso` akan langsung membatalkan build dengan *fatal error*.
   - *Anti-Pattern*: Jangan menggunakan string bootmode usang (seperti `uefi-x64.systemd-boot.esp`).

3. **Deklarasi Izin Berkas Wajib (`file_permissions`)**:
   - `mkarchiso` menyetel izin bawaan seluruh berkas di `airootfs/` ke `0644` (dan `0755` untuk direktori) dengan kepemilikan `root:root (0:0)`.
   - Berkas-berkas berikut **wajib** dideklarasikan secara eksplisit di array `file_permissions` pada `profiledef.sh`:
     ```bash
     file_permissions=(
       ["/etc/shadow"]="0:0:0400"
       ["/etc/gshadow"]="0:0:0400"
       ["/etc/sudoers.d/00_liveuser"]="0:0:0440"
       ["/etc/sudoers.d/10_installer"]="0:0:0440"
       ["/root"]="0:0:0750"
       ["/root/.gnupg"]="0:0:0700"
       ["/usr/local/bin/nusa-welcome"]="0:0:0755"
       ["/usr/local/bin/nusa-mirror"]="0:0:0755"
     )
     ```
   - *Kegagalan jika diabaikan*: Perintah `sudo` akan menolak berjalan karena `/etc/sudoers.d/*` dianggap *world-writable/insecure permissions*.

---

## 2. Manajemen Berkas Sistem Live (`airootfs/`)

1. **Larangan `customize_airootfs.sh`**:
   - *Target Positif*: Gunakan overlay direktori `airootfs/` secara deklaratif dan Pacman Hooks (`etc/pacman.d/hooks/`).
   - *Anti-Pattern*: Jangan pernah membuat atau mengeksekusi `airootfs/root/customize_airootfs.sh`. Skrip imperatif ini sudah usang (*deprecated*) dalam arsitektur archiso modern dan merusak sifat *reproducible build*.

2. **Aktivasi Layanan Systemd (Tanpa Systemctl)**:
   - *Target Positif*: Buat *symbolic link* relatif di direktori target:
     ```bash
     # Contoh mengaktifkan NetworkManager
     profile/airootfs/etc/systemd/system/multi-user.target.wants/NetworkManager.service -> /usr/lib/systemd/system/NetworkManager.service
     
     # Contoh mengaktifkan SDDM
     profile/airootfs/etc/systemd/system/display-manager.service -> /usr/lib/systemd/system/sddm.service
     
     # Target boot default grafis
     profile/airootfs/etc/systemd/system/default.target -> /usr/lib/systemd/system/graphical.target
     ```
   - *Anti-Pattern*: Jangan mencoba memanggil `chroot ... systemctl enable` di lingkungan luar.

3. **Pemberian Hak Pengguna Live (User Creation)**:
   - *Target Positif*: Siapkan berkas `/etc/passwd`, `/etc/shadow`, `/etc/group`, dan `/etc/gshadow` di `airootfs/` untuk pengguna `nusa` (UID 1000, group `wheel,audio,video,optical,storage,network`), atau gunakan *one-shot build-time pacman hook*.
   - Saat `airootfs/etc/passwd` tersedia, `mkarchiso` otomatis menyalin `/etc/skel` ke `/home/nusa` dan menetapkan izin `0750` dengan kepemilikan `1000:1000`.

---

## 3. Repositori & Paket (`pacman.conf` & `packages.x86_64`)

1. **Akses Rootless Pacman Cache**:
   - *Target Positif*: Berikan ACL read-write pada cache lokal (`sudo setfacl -m "u:${USER}:rwX" /var/cache/pacman/pkg`) agar build rootless tidak mendownload ulang ratusan paket ke RAM.
   - *Anti-Pattern*: Jangan menghapus tanda pagar `#DownloadUser = alpm` di `profile/pacman.conf`. Jika baris `DownloadUser` diaktifkan, proses `pacstrap` dalam kontainer *unshare* akan gagal mengakses direktori kerja dan repositori lokal.

2. **Isolasi Repositori Lokal (`customrepo`)**:
   - *Target Positif*: Daftarkan `[customrepo]` di baris teratas sebelum `[core]` di `profile/pacman.conf`:
     ```ini
     [customrepo]
     SigLevel = Optional TrustAll
     Server = file:///path/to/customrepo/x86_64
     ```
   - Kompilasi paket kustom (seperti `brave-bin`, `calamares`, `nusa-configs`) terlebih dahulu menjadi `.pkg.tar.zst` menggunakan `makepkg -s` di lingkungan chroot bersih, lalu inisialisasi basis data dengan `repo-add`.

3. **Driver Grafis & Lingkungan Virtual Wajib**:
   - *Target Positif*: Pastikan `packages.x86_64` selalu menyertakan:
     - `mesa`, `vulkan-intel`, `vulkan-radeon`, `vulkan-nouveau`, `xf86-video-amdgpu`, `xf86-video-ati`, `xf86-video-nouveau`
     - Driver VM integrasi: `qemu-guest-agent`, `spice-vdagent`, `open-vm-tools`, `virtualbox-guest-utils`
   - *Anti-Pattern*: Membangun sesi Wayland tanpa paket `mesa` atau driver vulkan akan menyebabkan Hyprland gagal *launch* dan langsung *crash* ke TTY.

---

## 4. Keamanan & Kebersihan Direktori Kerja (`work/`)

1. **Pembersihan Direktori Kerja yang Terinterupsi**:
   - Jika proses build gagal atau dibatalkan di tengah jalan, berkas dalam direktori kerja sering kali masih memiliki *bind mount* aktif (`/proc`, `/sys`, `/dev`).
   - *Prosedur Aman*:
     ```bash
     findmnt -R /tmp/archiso-work
     # Jika ada mountpoint aktif, unmount dengan aman atau unshare:
     unshare --map-auto --map-root-user -- rm -rf /tmp/archiso-work
     ```
   - *Anti-Pattern*: Jangan menjalankan `sudo rm -rf` langsung pada folder work yang masih memiliki mount aktif, karena dapat menghapus berkas sistem host!
