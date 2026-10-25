# Adopsi PipeWire Murni dan Porting Wayland

Untuk menangani audio, video, dan kapabilitas multimedia desktop modern, NusaOS beralih sepenuhnya ke PipeWire (`pipewire-pulse`, `wireplumber`) dan meniadakan implementasi PulseAudio legacy. Keputusan ini diambil karena PipeWire menawarkan latensi audio yang jauh lebih rendah, integrasi Bluetooth codec tingkat lanjut, serta integrasi wajib dengan `xdg-desktop-portal-hyprland` untuk kapabilitas *screen capture* dan *screen sharing* di sesi Wayland.
