# Profil Archiso Releng dengan Kernel Linux-Zen

Untuk membangun media ISO bootable yang stabil dan memiliki dukungan perangkat keras out-of-the-box, NusaOS menggunakan profil dasar `releng` archiso yang dipasangkan dengan kernel `linux-zen`. Profil `baseline` memang menghasilkan ukuran ISO lebih kecil namun minim driver jaringan dan firmware, sedangkan kernel `linux-zen` dipilih karena memiliki tuning scheduler yang lebih responsif untuk penggunaan interaktif desktop dibandingkan kernel `linux` standar.
