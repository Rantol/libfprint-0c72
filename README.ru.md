# libfprint-0c72

Патченная libfprint для сканера отпечатков **ELAN 04f3:0c72** (Acer Swift 3, 2023).

## Проблема

ELAN 0c72 — крошечный swipe-сенсор (150x52 пикселей). Оригинальная libfprint использует матчинг Bozorth3 с порогом 24, что слишком строго для таких маленьких изображений. Из-за этого аутентификация часто не работает даже с правильно записанными отпечатками.

Кроме того, на новых ядрах (6.12.94+) сенсор подвержен ошибкам USB-передач при многоэтапных операциях (запись отпечатков, повторная верификация), из-за чего драйвер отваливается.

## Решение

Патчи в `libfprint/drivers/elan.c` и `elan.h`:

| Параметр | Оригинал | Патч | Зачем |
|----------|----------|------|-------|
| `bz3_threshold` | 24 | 6 | Более лояльный матчинг для маленьких изображений |
| `ELAN_MAX_FRAMES` | 30 | 50 | Собирает больше кадров при свайпе → собранное изображение больше |
| `ELAN_MIN_FRAMES` | 7 | 5 | Позволяет более короткие свайпы |
| `ELAN_CMD_TIMEOUT` | 10000 | 15000 | Увеличенный таймаут USB-команд |
| `IMG_ENROLL_STAGES` | 5 | 8 | Больше образцов в шаблоне — распознавание терпимее к неидеальным свайпам |
| Ошибка stop-команды | обрыв сессии | игнорируется | Неудачная stop-команда между этапами больше не роняет запись отпечатка (проявлялось как `enroll-disconnected`) |
| Пауза перед калибровкой | 0 | 150 мс | Дать сенсору «переварить» stop-команду перед рекалибровкой |
| `ELAN_FINGER_TIMEOUT` | 200 | 1000 | Больше времени между кадрами при захвате |
| Повторы захвата | 0 | 3 | Повтор при USB-ошибках с задержкой 50мс |
| Повторы калибровки | 0 | 3 | Повтор при ошибках калибровки с задержкой 100мс |

Примечание: `IMG_ENROLL_STAGES` находится в `libfprint/fp-image-device-private.h` (влияет на все image-драйверы), остальное — в `libfprint/drivers/elan.c` / `elan.h`.

## Важно: управление питанием

ELAN 0c72 чувствителен к USB autosuspend. Если включены TLP или PowerTOP, добавьте в `/etc/tlp.conf`:

```
USB_DENYLIST="04f3:0c72"
```

Если используется PowerTOP `--auto-tune`, отключите autosuspend для сенсора после его запуска:

```bash
for d in /sys/bus/usb/devices/*/idVendor; do
    vid=$(cat "$d" 2>/dev/null)
    [ "$vid" = "04f3" ] && echo on > "$(dirname "$d")/power/control" 2>/dev/null
done
```

## Важно: защита от обновлений apt

Патченная библиотека перезаписывает `/usr/lib/.../libfprint-2.so.2.0.0`, который принадлежит пакету `libfprint-2-2`. Обычное обновление системы молча заменит её стоковой библиотекой, и все проблемы вернутся. Предотвратить:

```bash
sudo apt-mark hold libfprint-2-2
```

(Или используйте `dpkg-divert`, если хотите, чтобы apt продолжал обновлять сам пакет.) Когда выйдет новая версия libfprint: перенесите патчи, пересоберите, установите, затем `apt-mark unhold` → обновление → снова hold.

## Важно: перезапись отпечатков

После пересборки и установки библиотеки **обязательно перезапишите отпечатки**:

```bash
fprintd-enroll
```

Старые отпечатки могут не совпадать с новыми параметрами захвата.

## Важно: настройка PAM

Для работы аутентификации по отпечатку в системе (sudo, вход) убедитесь, что в `/etc/pam.d/common-auth` достаточный таймаут:

```
auth    [success=2 default=ignore]    pam_fprintd.so max-tries=3 timeout=30
```

Или запустите `sudo ./fix-pam.sh` — применит это автоматически.

## Решение проблем

**`enroll-disconnected` при записи отпечатка** — исправлено патчем stop-команды (см. таблицу); убедитесь, что установлена именно патченная библиотека (пересборка + `sudo ninja -C builddir install && sudo ldconfig && sudo systemctl restart fprintd`).

**`Device was already claimed`** — сенсор занят другим процессом. Закройте страницу отпечатков в настройках GNOME перед запуском `fprintd-enroll` из терминала.

**Отладка** — остановите демон и запустите его в форграунде с подробными логами:

```bash
sudo systemctl stop fprintd
sudo G_MESSAGES_DEBUG=all /usr/libexec/fprintd -t
```

Затем в другом терминале запустите `fprintd-enroll`. Оценки совпадения видны как строки `score N/6`, повторы при USB-ошибках — как `capture USB error, retry ...`.

## Быстрая установка

```bash
sudo ./install.sh
```

## Ручная установка

```bash
# Зависимости (Debian/Ubuntu)
sudo apt install build-essential meson ninja-build python3-dev libglib2.0-dev libusb-1.0-0-dev libgusb-dev libudev-dev

# Сборка
meson setup builddir
ninja -C builddir

# Установка
sudo ninja -C builddir install
sudo ldconfig
sudo systemctl restart fprintd
```

## Тест

```bash
fprintd-enroll
fprintd-verify
```

## Информация об устройстве

- **Сканер**: ELAN 04f3:0c72
- **Тип**: Swipe (150x52 px)
- **Протокол**: Старый ELAN (нет MOC2 — нет EP 0x84)
- **Ноутбук**: Acer Swift 3 SF314-43 (2023)

## Основано на

- [SilverCondor18/libfprint](https://github.com/SilverCondor18/libfprint) — добавляет 0c72 в таблицу устройств
- Оригинальная libfprint с freedesktop.org
