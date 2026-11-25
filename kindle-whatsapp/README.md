# Kindle WhatsApp (KOReader)

Kindle Paperwhite 11 + KOReader için basit WhatsApp (sadece metin) eklentisi.

```
Kindle (whatsapp.koplugin) <--HTTP--> bridge (Node + Baileys) <--> WhatsApp
```

## Uyumluluk
- Eklenti firmware'e bağlı değildir, KOReader içinde çalışır. Firmware sadece jailbreak için önemli.
- Hedef: Kindle firmware 5.15 ve üstü (11. nesil Paperwhite dahil), güncel KOReader sürümleri.
- Jailbreak (firmware'e göre): 5.16.4–5.18.x için Nosebleed/Sanctuary, 5.18.1–5.18.5 reklamlı cihazlar için AdBreak, 5.18.1'e kadar WinterBreak. Güncel yöntemler için kindlemodding.org'a bak.
- Hafif tasarım: modüller sadece kullanılınca yüklenir, listeler 15 öğeyle sınırlı, arka planda hiçbir şey çalışmaz.

## 1. Köprü (bilgisayar / Raspberry Pi / VPS)
```
cd bridge
npm install
TOKEN=gizlisifre node server.js
```
Node 18+ gerekir. Sürekli açık kalmalı (`pm2 start server.js` önerilir).

## 2. Eklenti
Releases'tan `whatsapp.koplugin.zip` indir, zip'in içindeki `whatsapp.koplugin`
klasörünü Kindle'da `koreader/plugins/` içine kopyala, KOReader'ı yeniden başlat.

## 3. Kullanım
Araçlar menüsü > WhatsApp:
1. **Sunucu adresi** ve **Token** gir (köprüdekiyle aynı).
2. **Telefonla eşleştir**: numarayı 905xxxxxxxxx yaz, çıkan kodu telefonda
   WhatsApp > Bağlı cihazlar > Telefon numarasıyla bağla yoluyla gir.
3. **Sohbetler** veya **Yeni mesaj**.

> Gayriresmi API kullanır, hesap ban riski vardır. Sadece kendi hesabında, az kullan.
