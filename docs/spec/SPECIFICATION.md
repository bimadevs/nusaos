# NusaOS System Specification (SDD)

Spesifikasi teknis dan fungsional sistem operasi NusaOS. Dokumen ini adalah *single source of truth* arsitektur teknis bagi agen AI dan pengembang.

---

## 1. Visi & Identitas Sistem

- **Nama Resmi**: NusaOS
- **Basis Distribusi**: Arch Linux (x86_64) via framework resmi `archiso`
- **Target Pengguna**: Pengembang perangkat lunak, mahasiswa/pelajar IT, dan *power user* yang mengutamakan kecepatan, efisiensi memori, dan estetika desktop modern.
- **Filosofi Inti**: 
  1. *Lightweight*: Penggunaan RAM idle di bawah 600 MB.
  2. *Pure Wayland*: Mengeliminasi dependensi legacy X11 bila memungkinkan.
  3. *Zero Bloat*: Hanya menyertakan utilitas esensial untuk produktivitas.
  4. *Nusantara Identity*: Sentuhan visual "Zamrud Khatulistiwa" dan optimasi jaringan lokal Indonesia out-of-the-box.

---

## 2. Arsitektur Komponen & Stack Teknologi

### 2.1 Kernel & Bootloader
- **Kernel**: `linux-zen` + `linux-firmware` (dioptimalkan untuk *low-latency interactive desktop*).
- **Initramfs**: `mkinitcpio` + `mkinitcpio-archiso`.
- **Bootloader**:
  - UEFI: `uefi.systemd-boot` (via `efiboot/`).
  - BIOS / Legacy: `bios.syslinux` (via `syslinux/`).
  - *Catatan Kritis*: Dilarang menggabungkan `uefi.systemd-boot` dan `uefi.grub` dalam `bootmodes=()` di `profiledef.sh`.
- **RAM CoW Overlay**: `cow_spacesize=4G` disematkan pada parameter kernel untuk mencegah kepenuhan ruang RAM selama sesi live.

### 2.2 Lingkungan Grafis & Compositor (Hyprland Stack)
- **Display Server**: Wayland murni.
- **Compositor**: `hyprland` (Wayland dynamic tiling compositor).
- **Status Bar**: `waybar` (dikustomisasi dengan indikator workspace, audio, baterai, wifi, jam, dan resource monitor).
- **App Launcher**: `rofi-wayland` (tema Zamrud Khatulistiwa dengan pencarian cepat aplikasi dan perintah).
- **Notification Daemon**: `dunst` (atau `mako`).
- **Screen Locker / Idle**: `hyprlock` & `hypridle`.
- **Polkit Agent**: `polkit-gnome` (dijalankan otomatis saat sesi Wayland aktif).
- **XDG Desktop Portal**: `xdg-desktop-portal-hyprland` + `xdg-desktop-portal-gtk` (wajib untuk *screen-sharing*, *file picker*, dan *screen capture*).

### 2.3 Display Manager & Autologin
- **Media Live ISO**: Autologin langsung ke akun `liveuser` / `nusa` dan otomatis mengeksekusi sesi Hyprland tanpa prompt kata sandi.
- **Sistem Terinstal**: `sddm` dengan tema kustom Wayland NusaOS diaktifkan via `display-manager.service`.

### 2.4 Aplikasi Inti & Shell Pengembang
- **Terminal Emulator**: `kitty` (GPU-accelerated, font ligatures, Kitty graphics protocol).
- **File Manager**: `thunar` + `thunar-archive-plugin` + `tumbler` + `gvfs` (ringan, stabil di Wayland, tanpa bloatware GNOME/KDE).
- **Peramban Web**: `brave-bin` (Chromium engine, pemblokir iklan bawaan, dipaketkan via `customrepo`).
- **Interactive Shell**: `zsh` + `starship` prompt + `zsh-autosuggestions` + `zsh-syntax-highlighting`.
- **AUR Helper**: `paru` (Rust-based, dipaketkan via `customrepo`).
- **Editor Teks Konsol**: `neovim` & `nano`.

### 2.5 Audio, Bluetooth, & Jaringan
- **Audio Server**: `pipewire` + `pipewire-pulse` + `pipewire-alsa` + `wireplumber`.
- **Bluetooth**: `bluez` + `bluez-utils` + `blueman` (layanan `bluetooth.service` diaktifkan).
- **Jaringan**: `networkmanager` + `network-manager-applet` (layanan `NetworkManager.service` diaktifkan).

### 2.6 Tipografi & Desain Visual ("Zamrud Khatulistiwa")
- **Font Antarmuka (UI)**: `inter-font` (keterbacaan tinggi untuk label dan teks sistem).
- **Font Terminal & Ikon**: `ttf-jetbrains-mono-nerd` (glif lengkap untuk simbol Waybar, terminal, dan editor).
- **Palet Warna**:
  - *Base Background*: `#0d1117` (Deep Obsidian / Slate)
  - *Panel/Surface*: `#161b22` dengan transparansi `85%` dan *blur* aktif
  - *Primary Accent*: `#00b48a` (Zamrud Khatulistiwa Emerald)
  - *Secondary Accent*: `#00e5a3` (Vibrant Mint Teal)
  - *Text Primary*: `#f0f6fc`
  - *Text Muted*: `#8b949e`
- **GTK Theme**: Tema gelap flat terkurasi dengan aksen Zamrud (misalnya varian papirus/arc/tokyonight disesuaikan).
- **Icon Theme**: `papirus-icon-theme` dengan folder color emerald.

### 2.7 Lokalisasi & Infrastruktur Mirror Indonesia
- **Mirror List**: Pacman mirror Indonesia diutamakan di baris teratas `/etc/pacman.d/mirrorlist`:
  1. Data Utama Dinamika (`mirror.datautama.net.id`)
  2. Politeknik Negeri Banyuwangi (`mirror.poliwangi.ac.id`)
  3. Universitas Telkom (`mirror.telkomuniversity.ac.id`)
  4. Kartolo Surabaya (`kartolo.sby.datautama.net.id`)
- **Zona Waktu Default**: `Asia/Jakarta` (WIB) dengan opsi mudah untuk WITA (`Asia/Makassar`) dan WIT (`Asia/Jayapura`).
- **Locale**: Menghasilkan `en_US.UTF-8` (default antarmuka) dan `id_ID.UTF-8` (format tanggal/angka lokal).

### 2.8 Installer Sistem (Calamares)
- **Framework**: `calamares` versi Qt6/KDE modern.
- **Konfigurasi Modul**:
  - `welcome`: Tampilan sambutan khas NusaOS dalam Bahasa Indonesia dan Bahasa Inggris.
  - `locale`: Peta interaktif zona waktu Indonesia & dunia.
  - `keyboard`: Default US layout.
  - `partition`: Otomatisasi partisi btrfs/ext4 dengan subvolume modern atau partisi manual terpandu.
  - `users`: Pembuatan pengguna reguler dengan hak `wheel` / `sudo`.
  - `packages`: Menggunakan cache lokal atau mirror Indonesia.
  - `summary`, `install`, `finished`.

---

## 3. Struktur Layout Repositori

```text
/home/bimadev/project/antigravity/nusaos/
├── AGENTS.md                  # Pemandu agen AI, aturan, dan context pointers
├── GLOSSARY.md                # Kamus istilah domain NusaOS
├── build.sh                   # Master orchestrator build script (rootless unshare)
├── docs/
│   ├── adr/                   # Architectural Decision Records (0001 - 0007+)
│   └── spec/
│       ├── SPECIFICATION.md   # Dokumen ini (arsitektur teknis & komponen)
│       ├── GUARDRAILS.md      # Batasan ketat, anti-pattern, dan mitigasi error
│       └── EXECUTION_PLAN.md  # Rencana langkah demi langkah berdasar kriteria selesai
├── customrepo/                # Repositori pacman lokal untuk paket non-official
│   ├── PKGBUILDs/             # Resep kompilasi paket (brave-bin, calamares, configs, artwork)
│   └── x86_64/                # Paket biner terkompilasi (.pkg.tar.zst) & customrepo.db.tar.gz
├── profile/                   # Archiso profile kerja (turunan releng)
│   ├── profiledef.sh          # Metadata ISO, bootmodes, dan file_permissions
│   ├── packages.x86_64        # Daftar paket wajib ISO
│   ├── pacman.conf            # Pacman config build-time (termasuk [customrepo])
│   ├── airootfs/              # Overlay filesystem (dotfiles, config, service symlinks)
│   ├── efiboot/               # Konfigurasi systemd-boot UEFI
│   └── syslinux/              # Konfigurasi Syslinux BIOS
└── scripts/
    ├── validate_profile.sh    # Script pre-flight check sebelum kompilasi ISO
    └── setup_customrepo.sh    # Script build paket AUR & inisialisasi repo lokal
```
