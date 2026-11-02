# ToDo — native iOS

Нативная SwiftUI-версия проекта ToDoList для **iOS/iPadOS 17+**. Swift 6, Observation, async/await, actor, URLSession и Keychain. Совместима с существующим Ktor REST API; Kotlin и Gradle для сборки приложения не нужны.

Реализованы вход и регистрация, Google Sign-In, восстановление и обновление сессии, периоды «Сегодня / Неделя / Месяц», CRUD задач с датой, временем и статусом, pull-to-refresh, валидация, RU/EN, светлая и тёмная темы.

Интерфейс сохраняет композицию и тексты исходного ToDoList: обычный список с разделителями, выбор периода, прямой выход и «+»; редактор отдельным экраном с Save внизу. Компоненты заменены нативными элементами iOS.

## Запуск

1. Откройте `ToDo.xcodeproj` в Xcode 16+ с установленной iOS platform. Дождитесь разрешения Swift Packages.
2. Для запуска без сервера выберите схему **ToDo Demo**, iPhone/iPad Simulator и нажмите Run. Демо хранит изменения только в памяти и сбрасывает их при перезапуске.
3. Для работы с API выберите схему **ToDo**. Debug обращается к `http://localhost:8080`, Release — к исходному серверу `https://todolist-server-zyck.onrender.com`. Исключение ATS для HTTP в локальной сети добавляется в Info.plist только в Debug (препроцессинг Info.plist, см. `Configuration/Config.xcconfig`).
4. Для реального устройства скопируйте `Configuration/Local.xcconfig.example` в `Configuration/Local.xcconfig`, укажите Apple Developer Team. URL сервера также можно переопределить там. Для удалённого сервера используйте HTTPS; localhost на физическом iPhone указывает на сам телефон.

Локальный сервер запускается из исходного ToDoList: `docker compose up -d`, затем `./gradlew :server:run`. Альтернатива — переопределить Debug `API_BASE_URL` на адрес развёрнутого сервера в Local.xcconfig.

Если на Mac несколько Xcode, выберите тот, для которого установлены platform и runtime. При проверке этого проекта использован `/Applications/Xcode.app` с iOS 26.2; глобальный `xcode-select` не менялся:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
open -a /Applications/Xcode.app ToDo.xcodeproj
```

Google Sign-In подключён через SPM, использует исходный публичный iOS client ID и URL scheme. При сохранённом `com.pelypets.todolist` дополнительная замена client ID не нужна. При смене bundle ID обновите OAuth client и reversed client ID в xcconfig, а также допустимые client IDs сервера. Это отдельный нативный клиент с тем же bundle ID: установка заменяет другую сборку ToDoList на выбранном устройстве.

## Архитектура

**Clean Architecture + MVVM**, четыре production-модуля SwiftPM:

```text
ToDo/App                          Composition Root, Google SDK adapter, Debug demo
Packages/TodoKit/Sources
  TodoDomain                      Entities, правила, ошибки, repository ports
  TodoApplication                 Use Cases, identity-provider port
  TodoData                        APISession actor, AuthAPI/TodoAPI, DTO/mapping, URLSession, Keychain
  TodoPresentation                SwiftUI Views, @MainActor @Observable ViewModels, RU/EN строки экранов
Packages/TodoKit/Tests             Domain / Application / Data / Presentation tests
ToDo/Resources                    RU/EN строки App (старт, Google, демо), иконка, privacy manifest
ToDoUITests                       XCUITest без сервера
Configuration                     API URL, OAuth, signing, Info.plist
```

Зависимости: `Presentation → Application → Domain`, `Data → Domain`. App собирает реализации через конструкторы. Domain не содержит Codable, токенов или UI-текстов; Presentation не обращается к репозиториям напрямую. SwiftUI — UI framework; MVVM — паттерн экранов; Observation — механизм наблюдения состояния.

[Подробная архитектура и схема зависимостей](Docs/ARCHITECTURE.ru.md). [Анализ исходного ToDoList](Docs/ANALYSIS.ru.md).

## Проверка

```bash
python3 Scripts/check_architecture.py
swift test --package-path Packages/TodoKit

xcodebuild build -project ToDo.xcodeproj -scheme ToDo \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO

# Укажите имя установленного симулятора, при необходимости заменив iPhone 17 Pro.
xcodebuild test -project ToDo.xcodeproj -scheme ToDo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO CODE_SIGN_IDENTITY=-
```

На iPhone 17 Pro Simulator (iOS 26.2) прошли UI-сценарии создания/изменения/удаления задачи и переключения периодов/возврата/выхода. Регистрация отдельно перепроверена успешным прогоном после стабилизации ввода тестового пароля: используется системная вставка, чтобы окно AutoFill не перехватывало посимвольные события. Рабочая сборка также проверена с русским интерфейсом и сессией существующего пользователя локального Ktor backend. `/health` и `/health/ready` возвращают `UP`.

UI-тесты сами включают `--demo` или `--demo-auth`. В Release эти режимы исключены условной компиляцией. Схема ToDo работает с реальным API и не переключается на фиктивные данные при ошибке.

Модули: **59 тестов Swift Testing прошли**, включая Use Cases и ViewModel. Debug и Release успешно собраны для iOS Simulator.

Автопроверки: валидация, локальные периоды/DST/границы года, ISO-8601 Kotlin, маршруты и JSON CRUD/auth, HTTP-ошибки, безопасные повторы GET, token rotation, параллельные 401, сохранение сессии при сетевых сбоях, гонка logout/refresh, выход без сети без ложной ошибки, сохранение новой пары токенов при сбое Keychain, время новой задачи около полуночи, фоновое обновление редактора без потери правок, уведомление об истёкшей сессии, локальное применение изменений к списку, переводы в бандле пакета; UI — регистрация, создание/изменение/удаление, периоды, подтверждение отмены черновика и выход. CI находится в `.github/workflows/ios.yml`.

Реальный интерактивный вход Google требует аккаунта пользователя и не выполняется автоматическими тестами. Доступность production backend проверяется отдельно от сборки и тестов клиента.

`ToDo.xcodeproj` хранится в git и редактируется в Xcode; генератора нет. Почти весь код и ресурсы находятся в пакете `TodoKit`, новые файлы пакета Xcode подхватывает автоматически. В проект вручную добавляются только файлы таргета приложения (`ToDo/App`, `ToDo/Resources`) и UI-тестов.
