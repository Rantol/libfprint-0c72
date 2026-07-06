# libfprint-0c72

Патченная libfprint для сканера отпечатков **ELAN 04f3:0c72** (Acer Swift 3, 2023).

## Проблема

ELAN 0c72 — крошечный swipe-сенсор (150x52 пикселей). Оригинальная libfprint использует матчинг Bozorth3 с порогом 24, что слишком строго для таких маленьких изображений. Из-за этого аутентификация часто не работает даже с правильно записанными отпечатками.

## Решение

Два патча в `libfprint/drivers/elan.c` и `elan.h`:

| Параметр | Оригинал | Патч | Зачем |
|----------|----------|------|-------|
| `bz3_threshold` | 24 | 12 | Более лояльный матчинг для маленьких изображений |
| `ELAN_MAX_FRAMES` | 30 | 50 | Собирает больше кадров при свайпе → собранное изображение больше |

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
