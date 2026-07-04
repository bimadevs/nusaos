# NusaOS — Distro Linux Turunan Arch

Proyek bikin distribusi Linux turunan Arch Linux untuk kebutuhan **desktop harian**, dibangun memakai **archiso**.

## Status Proyek

| Fase       | Status      |
|------------|-------------|
| Planning   | 🚧InProgress|
| Build ISO  | ⏳Belum     |
| Testing    | ⏳Belum     |
| Release v1 | ⏳Belum     |

## Cakupan Dokumen

| File                          | Isi                                      |
|-------------------------------|------------------------------------------|
| `01-konsep-dan-visi.md`       | Visi, nama OS, target user, branding     |
| `02-arsitektur-teknis.md`     | Base sistem, kernel, bootloader, archiso |
| `03-daftar-paket.md`          | Daftar paket/aplikasi yang disertakan    |
| `04-konfigurasi-default.md`   | Konfigurasi default OS post-install      |
| `05-build-proses.md`          | Langkah-langkah build ISO memakai archiso|
| `06-roadmap.md`               | Tahap pengerjaan & target timeline       |
| `07-sumber-referensi.md`      | Link bacaan & referensi belajar          |
| `08-github-action.md`         | CI/CD build ISO via GitHub Actions       |
| `.github/workflows/build-iso.yaml` | Workflow file GitHub Actions         |

## Garis Besar

- **Base**: Arch Linux
- **Build tool**: `archiso` (tool resmi Arch buat bikin ISO)
- **Target**: Desktop harian untuk user umum
- **Output**: File `.iso` yang bisa diboot lewat USB (Rufus/Ventoy/balenaEtcher)
- **Install**: Pakai `archinstall` (CLI installer resmi Arch; calamares menyusul v1.1)
- **Repo**: [github.com/bimadevs/nusaos](https://github.com/bimadevs/nusaos)

## Catatan Penting

> Proyek ini **bukan** bikin kernel sendiri atau OS dari nol. Ini **respin** — kustomisasi Arch Linux yang sudah ada. Kernel tetap pakai kernel resmi Arch (`linux` atau `linux-lts`).

## Penulis

Bima — guru SMK TJKT, belajar sambil bangun.
