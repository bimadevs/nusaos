# NusaOS Agent Guidelines & Operating Manual

Repositori ini berisi seluruh kode sumber, konfigurasi profil `archiso`, paket kustom, dan skrip orkestrasi untuk membangun **NusaOS**—distribusi Linux desktop independen buatan Indonesia berbasis Arch Linux, berorientasi performa ringan, antarmuka modern Wayland (Hyprland), dan dirancang khusus untuk produktivitas pengembang.

Setiap agen AI yang bekerja di repositori ini **wajib** mematuhi pedoman Spec-Driven Development (SDD) dan aturan operasional di bawah ini secara mutlak.

---

## 1. Context Pointers & Dokumen Rujukan

Sebelum melakukan modifikasi atau merancang fitur baru, agen **wajib** merujuk pada dokumen otoritatif berikut:

- [SPECIFICATION.md](file:///home/bimadev/project/antigravity/nusaos/docs/spec/SPECIFICATION.md): Spesifikasi arsitektur teknis, daftar paket bawaan, skema warna Zamrud Khatulistiwa, dan stack Wayland.
- [GUARDRAILS.md](file:///home/bimadev/project/antigravity/nusaos/docs/spec/GUARDRAILS.md): Batasan ketat `archiso`, aturan validasi `profiledef.sh`, mitigasi izin berkas, dan pencegahan kegagalan build.
- [EXECUTION_PLAN.md](file:///home/bimadev/project/antigravity/nusaos/docs/spec/EXECUTION_PLAN.md): Rencana bertahap, alur kerja dari Fase 1 hingga Fase 6, dan kriteria penyelesaian (*gates*).
- [GLOSSARY.md](file:///home/bimadev/project/antigravity/nusaos/GLOSSARY.md): Definisi resmi istilah domain NusaOS (hindari istilah yang dilarang).
- [docs/adr/](file:///home/bimadev/project/antigravity/nusaos/docs/adr/): Catatan keputusan arsitektur (ADR 0001 hingga 0007).

---

## 2. Aturan Mutlak Penggunaan Tools & Skills

Agen **wajib** memanfaatkan skills dan MCP server terpasang untuk menjaga akurasi dan mencegah degradasi kode:

1. **Wajib Menggunakan Skill `archiso-builder`**:
   - Lokasi: [`.agents/skills/archiso-builder/SKILL.md`](file:///home/bimadev/project/antigravity/nusaos/.agents/skills/archiso-builder/SKILL.md)
   - *Pemicu*: Setiap kali melakukan pengembangan, modifikasi berkas pada `profile/`, penyusunan `profiledef.sh`, deklarasi `file_permissions`, penambahan paket di `packages.x86_64`, pengaturan overlay `airootfs/`, hingga eksekusi `mkarchiso` dan `run_archiso`.
   - *Tujuan*: Menjamin kepatuhan terhadap standar terbaru `archiso` dan mencegah kegagalan build.

2. **Wajib Menggunakan Skill `opensrc`**:
   - Lokasi: [`.agents/skills/opensrc/SKILL.md`](file:///home/bimadev/project/antigravity/nusaos/.agents/skills/opensrc/SKILL.md)
   - *Pemicu*: Setiap kali membutuhkan referensi kode, konfigurasi, PKGBUILD, atau modul dari GitHub dan ekosistem open-source (misal: referensi modul Calamares, dotfiles Hyprland/Waybar, skrip mirror, atau implementasi upstream).
   - *Penggunaan*: Jalankan `opensrc path owner/repo` atau `$(opensrc path ...)` untuk membaca kode sumber langsung, bukan menebak-nebak implementasi.

3. **Wajib Menggunakan MCP Server `context7`**:
   - *Pemicu*: Setiap kali mencari dokumentasi teknis, API, konfigurasi syntax, dan panduan resmi terbaru dari library, framework, atau tool yang digunakan (`resolve-library-id`, `query-docs`).
   - *Tujuan*: Memperoleh dokumentasi primer yang terverifikasi dan termutakhir secara langsung.

4. **Aturan Riset Mendalam (Anti-Stale Training Memory)**:
   - **Dilarang keras mengandalkan ingatan lama hasil data training!** Arsitektur Wayland, Hyprland, Arch Linux, dan ekosistem pendukungnya berubah dengan cepat. Sintaks konfigurasi atau opsi perintah lama sering kali sudah usang (*deprecated* atau *broken*).
   - Agen **wajib selalu berpatokan pada informasi terkini dan terbaru** dengan melakukan riset mendalam (*deep research*) menggunakan `context7`, inspeksi kode upstream via `opensrc`, dan pengecekan dokumentasi primer sebelum menulis berkas konfigurasi maupun kode.

---

## 3. Prinsip Kerja Agen (Spec-Driven Development)

1. **Spec-First, Code-Second**:
   - Jangan pernah menambahkan dependensi besar atau mengubah perilaku inti sistem tanpa mencocokkannya dengan `docs/spec/SPECIFICATION.md`.
   - Jika ada keputusan arsitektur baru yang tidak dapat dibalikkan (*hard to reverse*) dan memiliki trade-off nyata, catat ADR baru di `docs/adr/` dan perbarui `GLOSSARY.md`.

2. **Deklaratif & Reproducible**:
   - Seluruh kustomisasi sesi live ditempatkan di `profile/airootfs/` atau diinjeksikan via pacman hooks.
   - Dilarang membuat skrip imperatif usang seperti `customize_airootfs.sh`.

3. **Integritas Izin Berkas (*Permission Integrity*)**:
   - Setiap berkas baru yang ditaruh di `profile/airootfs/etc/sudoers.d/`, `/etc/shadow`, atau `/usr/local/bin/` **wajib** didaftarkan di array `file_permissions` pada `profile/profiledef.sh`.

4. **Validasi Sebelum Eksekusi**:
   - Selalu jalankan `bash scripts/validate_profile.sh profile` sebelum memicu kompilasi ISO dengan `mkarchiso`.
   - Jangan abaikan pesan peringatan (*warning*) dari validasi profil.

---

## 4. Tata Kelola Perintah & Alur Kerja

| Aksi | Perintah Standar | Catatan |
| :--- | :--- | :--- |
| **Validasi Profil** | `bash scripts/validate_profile.sh profile` | Memeriksa integritas berkas, bootmodes, dan permissions |
| **Setup Paket Lokal** | `bash scripts/setup_customrepo.sh` | Kompilasi paket kustom & update `customrepo.db.tar.gz` |
| **Build ISO Penuh** | `bash build.sh` | Orkestrasi validasi, build lokal, dan eksekusi `mkarchiso` |
| **Uji Coba ISO (UEFI)** | `run_archiso -u -i out/nusaos-*.iso` | Menjalankan emulator QEMU dengan firmware OVMF UEFI |
| **Bersihkan Sisa Build** | `unshare --map-auto --map-root-user -- rm -rf /tmp/archiso-work` | Pembersihan direktori kerja tanpa merusak mount host |

---

## 5. Konvensi Gaya Penulisan Berkas

- **Shell Scripts**: Gunakan header `#!/usr/bin/env bash`, aktifkan mode ketat `set -euo pipefail`, dan sertakan penanganan error yang jelas.
- **Konfigurasi Teks**: Konfigurasi Hyprland, Waybar, dan Kitty harus menyertakan komentar pembatas seksi yang rapi.
- **Git Commit**: Gunakan konvensi Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`).
