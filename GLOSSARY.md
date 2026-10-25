# NusaOS

Sistem operasi desktop independen buatan Indonesia berbasis Arch Linux yang mengusung prinsip performa ringan, stack tampilan modern berbasis Wayland, dan identitas visual serta utilitas ramah pengembang.

## Language

**NusaOS**:
Distribusi Linux desktop berbasis Arch Linux yang dirancang ringan, estetik, dan siap pakai untuk produktivitas pengembang dan *power user*.
_Avoid_: Nusa Linux, Nusa Distro

**Hyprland Stack**:
Kombinasi *Wayland dynamic tiling compositor* (Hyprland), status bar (*Waybar*), *application launcher* (*Rofi-wayland*), dan *notification daemon* yang menjadi antarmuka visual utama.
_Avoid_: Desktop Environment, Nusa DE, Desktop Shell

**Live Environment**:
Sistem operasi sementara yang berjalan langsung dari memori RAM melalui media bootable (USB/ISO) yang dihasilkan oleh *archiso*.
_Avoid_: Trial OS, Live USB OS

**Calamares Installer**:
Aplikasi pemasang grafis modular yang disesuaikan dengan alur partisi dan visual khas NusaOS untuk menginstal sistem ke media penyimpanan permanen.
_Avoid_: Arch Installer GUI, Nusa Setup Wizard

**Nusa Tooling**:
Kumpulan skrip dan utilitas pembantu internal (seperti pengatur mirror lokal dan wizard onboarding pengguna baru) yang disertakan secara *out-of-the-box*.
_Avoid_: Bloatware, System Tweak Tools

**Zamrud Khatulistiwa**:
Palet warna visual resmi NusaOS yang memadukan latar belakang gelap (*deep slate*), aksen hijau zamrud/teal, dan efek transparansi buram (*frosted blur*).
_Avoid_: Dark Emerald Theme, Nusa Skin

**Custom Repository (customrepo)**:
Repositori paket pacman lokal di lingkungan build yang digunakan untuk menyuntikkan paket-paket kustom NusaOS secara *reproducible* tanpa ketergantungan langsung ke AUR.
_Avoid_: Local AUR, Build Cache

**Live Autologin**:
Mekanisme masuk desktop secara otomatis tanpa autentikasi kata sandi khusus untuk sesi Live Environment agar pengguna dapat langsung menguji sistem.
_Avoid_: Passwordless Root, Insecure Login

**Brave Browser**:
Peramban web default berbasis Chromium dengan perlindungan privasi dan pemblokir iklan bawaan yang dikemas melalui repositori lokal.
_Avoid_: Chrome, Firefox

**Starship Prompt**:
Prompt terminal berkecepatan tinggi berbasis Rust yang menampilkan status lingkungan pengembang dan Git secara adaptif di atas Zsh.
_Avoid_: Oh-My-Zsh Theme, Bash Prompt
