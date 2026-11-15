# AcidVision

[![build](https://github.com/procuroroff/AcidVision/actions/workflows/build.yml/badge.svg)](https://github.com/procuroroff/AcidVision/actions/workflows/build.yml)
[![release](https://img.shields.io/github/v/release/procuroroff/AcidVision?include_prereleases&label=release)](https://github.com/procuroroff/AcidVision/releases/latest)

Психоделический rootless-твик для **iPhone 7 / iOS 15.8** (Dopamine, palera1n):
жидкое «кислотное» искажение поверх SpringBoard, живой эффект в видоискателе
Камеры и **реально искажённые фотографии**, которые сохраняются в галерею.

> **TL;DR.** Оверлей SpringBoard — прозрачный `UIWindow` с `MTKView` и
> runtime-компилируемым Metal-шейдером: волны, ripple, RGB-разъезд, hue-цикл.
> Тачи проходят насквозь. В Камере тот же шейдер ложится на видоискатель, а
> снимок прогоняется через Core Image (`CITwirlDistortion`, `CIBumpDistortion`,
> `CIHueAdjust`, кастомный CIKernel для хроматической аберрации) **до** записи
> в Photo Library.

**Статус:** пакет собирается в GitHub Actions, проходит проверку rootless-layout
и публикуется в Releases. Runtime-проверка на живом iPhone 7 в этой среде не
выполнялась — устройства нет; MSL компилируется на устройстве в рантайме, и при
ошибке компиляции оверлей просто скрывается (в лог пишется причина).

[**Скачать последний .deb**](https://github.com/procuroroff/AcidVision/releases/latest)


---

## 1. Что происходит на экране

| Где | Что делает твик |
|---|---|
| SpringBoard | Прозрачный `UIWindow` на уровне `UIWindowLevelAlert + 100` с `MTKView`. Шейдер рисует движущееся цветовое поле, волновой domain warp, кольца ripple и разъезд RGB. Окно возвращает `NO` из `pointInside:withEvent:` и `nil` из `hitTest:withEvent:` — тачи, свайпы и нажатия не блокируются. |
| Home Screen | Иконки `SBIconView` получают медленный `CAKeyframeAnimation` по `transform.translation` + `transform.rotation.z`. Это заставляет элементы интерфейса **физически** плавать, а не только переливаться. |
| Камера, видоискатель | На `AVCaptureVideoPreviewLayer` находится host-view и сверху добавляется такой же прозрачный `MTKView`. Превью остаётся живым, эффект идёт в реальном времени. |
| Камера, снимок | `-[AVCapturePhoto fileDataRepresentation]` перехватывается, изображение искажается Core Image и кодируется обратно в HEIC/JPEG с сохранением метаданных. В галерею попадает уже искажённый кадр. |

### Важное ограничение прозрачного оверлея

Прозрачный `UIWindow` **не может прочитать пиксели окон, лежащих под ним**:
у UIKit нет API «дай мне framebuffer сцены». Поэтому системный оверлей не
делает геометрическую рефракцию текста и иконок — он накладывает поверх
движущуюся жидкость, цвет и RGB-канты, а иконки дополнительно дрейфуют
CA-анимацией. Визуально это и есть «плывущий кислотный экран», но это не
попиксельный варп чужого рендера.

Настоящая рефракция всего SpringBoard требует захвата дисплея через приватный
`CARenderServerRenderDisplay`/IOSurface. Такой режим сознательно не включён:
оверлей попадает в собственный захват (feedback-петля), появляется задержка
кадра и чёрные/белые вспышки. Если нужен именно screen-capture warp — это
отдельный проект, а не «прозрачный оверлей».

В Камере ограничение смягчено: видоискатель получает живой оверлей, а
**сохранённый снимок** искажается по-настоящему, потому что там есть доступ к
полному изображению до записи.

---

## 2. Структура проекта

```
AcidVision/
├── Makefile                     # rootless, iphone:clang:latest:15.0, arm64
├── control                      # com.procuroroff.acidvision, iphoneos-arm64
├── AcidVision.plist             # фильтры com.apple.springboard + com.apple.camera
├── Tweak.x                      # Logos-хуки обоих процессов
├── AcidConfig.h/.m              # все ручки интенсивности/скорости
├── AcidOverlayWindow.h/.m       # UIWindow, прозрачный для тачей
├── AcidOverlayViewController.*  # корневой VC оверлея
├── AcidOverlayManager.h/.m      # создание окна, сцена, ретраи
├── AcidMetalView.h/.m           # прозрачный MTKView
├── AcidRenderer.h/.m            # Metal pipeline + uniforms
├── AcidShaderTypes.h            # общий layout uniform-буфера
├── AcidDriftAnimator.h/.m       # дрейф иконок SBIconView
├── AcidCameraPreviewManager.*   # оверлей на AVCaptureVideoPreviewLayer
├── AcidCameraProcessor.h/.m     # Core Image пайплайн снимка
├── Shaders.metal                # исходник MSL (читаемый)
├── ShadersSource.h              # автогенерация: MSL как NSString
├── scripts/embed_shader.py      # Shaders.metal -> ShadersSource.h
├── .github/workflows/build.yml  # сборка .deb на ubuntu-latest
└── .github/scripts/install-sdk.sh
```

`ShadersSource.h` генерируется из `Shaders.metal`:

```bash
python3 scripts/embed_shader.py Shaders.metal ShadersSource.h
```

CI делает это перед сборкой и падает, если закоммиченный заголовок разошёлся
с `.metal`. Так шейдер остаётся читаемым, а пакет собирается без Apple
Metal-компилятора (его нет в Linux-тулчейне Theos). MSL компилируется в
рантайме через `newLibraryWithSource:options:error:`.

---

## 3. Сборка

### GitHub Actions (рекомендуется)

Пуш в `main` или ручной запуск:

```bash
gh workflow run build
gh run watch
gh run download --name acidvision-deb --dir out
```

Готовый `.deb` также публикуется в **Releases** при пуше тега:

```bash
git tag -a v1.2.0 -m "AcidVision 1.2.0"
git push --follow-tags
```

Workflow ставит Theos, Linux→iOS clang, iOS SDK 15.x, `ldid`, собирает
`make package FINALPACKAGE=1` и проверяет, что dylib и plist лежат по пути
`/var/jb/Library/MobileSubstrate/DynamicLibraries/...`.

### Локально

Нужны macOS + Theos + iOS SDK **или** Linux с кросс-тулчейном (как в CI):

```bash
export THEOS=$HOME/theos
make package FINALPACKAGE=1
```

`TARGET = iphone:clang:latest:15.0`, `ARCHS = arm64`,
`THEOS_PACKAGE_SCHEME = rootless`.

---

## 4. Установка

```bash
scp packages/com.procuroroff.acidvision_1.2.0_iphoneos-arm64.deb root@iphone:/tmp/
ssh root@iphone 'dpkg -i /tmp/com.procuroroff.acidvision_1.2.0_iphoneos-arm64.deb'
ssh root@iphone 'killall -9 SpringBoard'
```

Или открыть `.deb` в Sileo/Zebra. Пакет rootless: файлы уходят в `/var/jb`,
Dopamine/palera1n это поддерживают. После установки — respring; Камера
подхватит твик при следующем запуске.

Проверка, что dylib загрузилась:

```bash
ssh root@iphone 'log stream --predicate "eventMessage CONTAINS \"[AcidVision]\""'
```

В логе будет `[AcidVision] injected into SpringBoard (com.apple.springboard)` и
`overlay window installed at level ...`.

---

## 5. Настройка интенсивности и скорости

Все параметры читаются при инжекте из rootless-домена
`com.procuroroff.acidvision`. Меняйте от пользователя **mobile** (или через
Filza: `/var/mobile/Library/Preferences/com.procuroroff.acidvision.plist`),
затем перезапускайте процесс.

```bash
# пример: сильнее и быстрее
defaults write com.procuroroff.acidvision intensity -float 0.80
defaults write com.procuroroff.acidvision speed     -float 1.60
defaults write com.procuroroff.acidvision chroma    -float 0.65
defaults write com.procuroroff.acidvision ripple    -float 1.10

killall -9 SpringBoard Camera
```

### Системный оверлей

| Ключ | По умолчанию | Диапазон | За что отвечает |
|---|---:|---:|---|
| `enabled` | `YES` | bool | Полностью выключает оверлей SpringBoard. |
| `intensity` | `0.72` | 0…1 | Общая сила/непрозрачность эффекта. Больше — плотнее цвет, сильнее волны. |
| `speed` | `1.15` | 0…3 | Скорость всей анимации: волны, ripple, hue. `0.5` — медитация, `2.0` — кислотный шторм. |
| `chroma` | `0.45` | 0…1 | Разъезд R/G/B. `0` — без аберрации. |
| `ripple` | `0.80` | 0…2 | Сила бегущих круговых волн. |
| `hueSpeed` | `0.24` | 0…2 | Скорость циклической смены оттенка. |
| `grain` | `0.07` | 0…1 | Плёночное зерно. |
| `vignette` | `0.36` | 0…1 | Затемнение краёв. |
| `scanline` | `0.18` | 0…1 | Имитация строк ЭЛТ. |
| `glitch` | `0.55` | 0…1 | Glitchcore: рваные горизонтальные полосы, блочный RGB-сдвиг, инвертированные блоки, VHS-полосы. |
| `drift` | `1.40` | 0…2 | Амплитуда дрейфа иконок. `0` — иконки стоят на месте. |
| `driftEnabled` | `YES` | bool | Быстрый выключатель дрейфа. |

### Камера

| Ключ | По умолчанию | Диапазон | За что отвечает |
|---|---:|---:|---|
| `cameraPreviewEnabled` | `YES` | bool | Живой оверлей на видоискателе. |
| `cameraIntensity` | `0.38` | 0…1 | Сила эффекта в видоискателе. Держите ниже `intensity`, иначе плохо видно кадр. |
| `photoWarpEnabled` | `YES` | bool | Искажать сохраняемые снимки. |
| `photoTwirl` | `2.15` | −6…6 | Угол `CITwirlDistortion` в радианах. `3.14` — полный оборот, отрицательный — в другую сторону. |
| `photoBump` | `0.34` | −1…1 | `CIBumpDistortion`: «линза»/вмятина. Отрицательное — вогнутая. |
| `photoHue` | `0.55` | −π…π | Сдвиг оттенка `CIHueAdjust` в радианах. |
| `photoSaturation` | `1.45` | 0…3 | Насыщенность `CIColorControls`. |
| `photoChroma` | `4.0` | 0…30 | RGB-разъезд в пикселях на эталонные 1000 px; на 12 Мп умножается на `min(w,h)/1000`. |
| `photoPixelate` | `8.0` | 0…40 | `CIPixellate` для глитч-блоков, в пикселях на 1000 px. `0` — выключено. |
| `photoPosterize` | `8.0` | 0…16 | `CIColorPosterize`: количество уровней цвета. `0` — выключено. |

### Готовые пресеты

```bash
# Мягкий, почти медитативный
defaults write com.procuroroff.acidvision intensity -float 0.32
defaults write com.procuroroff.acidvision speed     -float 0.55
defaults write com.procuroroff.acidvision cameraIntensity -float 0.20

# Жёсткий LSD + glitchcore
defaults write com.procuroroff.acidvision intensity -float 0.85
defaults write com.procuroroff.acidvision speed     -float 1.80
defaults write com.procuroroff.acidvision chroma    -float 0.75
defaults write com.procuroroff.acidvision glitch    -float 0.85
defaults write com.procuroroff.acidvision drift     -float 1.80
defaults write com.procuroroff.acidvision photoTwirl -float 3.40
defaults write com.procuroroff.acidvision photoBump  -float 0.55

# Только фотографии, без оверлея
defaults write com.procuroroff.acidvision enabled           -bool NO
defaults write com.procuroroff.acidvision cameraPreviewEnabled -bool NO
defaults write com.procuroroff.acidvision photoWarpEnabled  -bool YES
```

После правок:

```bash
killall -9 SpringBoard   # перезапуск оверлея
killall -9 Camera        # Камера перечитает настройки при следующем старте
```

---

## 6. Как работает Metal-часть

`Shaders.metal`:

1. **Full-screen triangle** — без вершинного буфера, один `drawPrimitives` на кадр.
2. **Domain warp** — три интерферирующих `sin/cos`-поля смещают координаты,
   по которым строится палитра. Это даёт «жидкое» течение.
3. **Ripple** — кольцо `sin(dist * 16 - t * 2.6) * exp(-dist * 2.2)` от
   движущегося центра; опционально второе кольцо от точки касания.
4. **Glitchcore** — квантованные горизонтальные полосы, блочная выборка цвета,
   инвертированные datamosh-блоки, VHS-полосы и строчный RGB-джиттер.
5. **Chromatic aberration** — палитра считается трижды со сдвигом по X, из
   результатов берутся R, G и B.
6. **Hue drift + specular + scanline + grain + vignette**.
7. **Premultiplied alpha** — смешивание `One / OneMinusSourceAlpha`, поэтому
   подложка просвечивает и интерфейс остаётся читаемым.

`AcidRenderer` компилирует MSL в рантайме, создаёт `MTLRenderPipelineState` и
каждый кадр передаёт 64-байтовый `AcidUniforms` (layout совпадает с
`AcidShaderTypes.h`). `AcidMetalView` — прозрачный `MTKView` с
`preferredFramesPerSecond = 60`, `paused = NO`, `opaque = NO`.

Окно оверлея:

```objc
window.windowLevel = UIWindowLevelAlert + 100.0;
window.opaque = NO;
window.backgroundColor = UIColor.clearColor;
window.userInteractionEnabled = NO;
```

и переопределения:

```objc
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event { return NO; }
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event { return nil; }
- (BOOL)_ignoresHitTest { return YES; }
- (BOOL)_usesWindowServerHitTesting { return NO; }
```

`_ignoresHitTest` — приватный хук window server: без него полноэкранное окно
SpringBoard может съедать тачи в **других процессах** (рабочий стол работает, а
кнопки внутри приложений — нет).

---

## 7. Как работает фотопайплайн

1. `AVCapturePhoto` хук возвращает не оригинальный `NSData`, а результат
   `processedDataForPhoto:originalData:`.
2. `CIImage` создаётся из HEIC/JPEG, EXIF-orientation «запекается» в пиксели.
3. Фильтры: `CITwirlDistortion` → `CIBumpDistortion` → `CIHueAdjust` →
   `CIColorControls` → `CIPixellate` → `CIColorPosterize` → кастомный
   `CIKernel` RGB-split.
4. `CIContext` рендерит `CGImage`, `CGImageDestination` пишет HEIC/JPEG с
   quality `0.95` и исходными метаданными. Если контейнер не поддержан,
   возвращается оригинал — формат файла не подменяется.
5. В EXIF `UserComment` ставится маркер `AcidVision:processed:v1`.
6. Второй, страховочный хук `PHAssetCreationRequest
   addResourceWithType:data:options:` проверяет маркер и **не** обрабатывает
   файл повторно. Это важно для сборок Камеры, которые передают файл в Photos
   напрямую.

RAW/DNG пропускается: `CGImageSourceGetType` содержит `raw`/`dng` — такие
файлы не трогаем, чтобы не сломать формат.

**Live Photos:** парное видео не обрабатывается. Если включён Live Photo,
обработанный still может перестать быть парным к видео. Для эффекта лучше
выключить Live Photos в Камере.

**Портретный режим:** depth data и portrait effects matte при перекодировании не
переносятся — остаётся обычный HEIC/JPEG с эффектом. Для максимального качества
портретов с глубиной снимайте с выключенным `photoWarpEnabled`.

---

## 8. Отладка

```bash
# все сообщения твика
log stream --predicate 'eventMessage CONTAINS "[AcidVision]"' --style compact

# только SpringBoard
log stream --predicate 'process == "SpringBoard" AND eventMessage CONTAINS "[AcidVision]"'

# проверить, что пакет rootless
dpkg -c com.procuroroff.acidvision_1.2.0_iphoneos-arm64.deb
```

Если оверлея нет:

- проверьте `enabled` (по умолчанию `YES`);
- в логе должно быть `overlay window installed`;
- если `Metal shader compilation failed` — пришлите текст ошибки, это MSL;
- если SpringBoard падает в safe mode — удерживайте кнопку увеличения громкости
  при respring (ElleKit/Substrate safe mode), затем `defaults write ...
  enabled -bool NO` и respring.

Удаление:

```bash
dpkg -r com.procuroroff.acidvision
killall -9 SpringBoard
```

---

## 9. Совместимость и оговорки

- Целевая конфигурация: **iPhone 7 (A10), iOS 15.8, arm64, rootless**.
- Твик использует приватные классы `SBIconView` и `SpringBoard`; на других
  версиях iOS имена могут отличаться. Оверлей и Камера при этом продолжат
  работать, дрейф иконок просто не включится.
- 60 fps на A10 — это заметная нагрузка на GPU/батарею. Если греется,
  уменьшите `speed` или поставьте `preferredFramesPerSecond` на 30 в
  `AcidMetalView.m`.
- Обработка снимка синхронная: декодирование + фильтры + HEIC-энкод занимают
  примерно 0,5–2 с на A10. Камера обычно вызывает `fileDataRepresentation` на
  фоновой очереди; если конкретная сборка iOS сделает это на главном потоке,
  возможен короткий фриз после затвора (снимок при этом сохранится).
- Твик не меняет системные файлы и не пишет в Photo Library сам: он лишь
  подменяет данные, которые Камера и так сохраняет.
- Jailbreak-твик предоставляется как есть, без гарантий; используйте на своём
  устройстве и понимайте риски safe mode.

---

## 10. Лицензия

MIT. См. [LICENSE](LICENSE).
