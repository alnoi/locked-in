# Виджеты TrackIt

## Набор
- «Сегодня»: medium — 3 задачи, large — до 6 задач и теги. Только задачи с планированием на сегодня, без просроченного дедлайна; задачи без планирования не включаются. Завершённые запланированные задачи учитываются в прогрессе.
- «Календарь»: medium/large — месяц, цветные точки запланированных задач, расписание текущего дня. Только plannedAt, как в основном календаре; дедлайн не становится планированием. Выполненные скрыты в календарных виджетах, включая точки месяца; в календаре приложения остаются с зачёркнутым названием.
- Кружок завершает задачу без запуска основного окна. Ссылки lockedin://task/<UUID>, lockedin://today и lockedin://calendar?date=YYYY-MM-DD открывают задачу/раздел/день.
- Светлая, тёмная и системная темы; системные правила тонирования/обновления WidgetKit сохраняются.

## Разделение
- LockedInDomain/WidgetAgenda: выбор задач и ссылки.
- LockedInData/WidgetStore, WidgetService: общий read model и журнал действий.
- LockedInWidgetUI: SwiftUI, TimelineProvider, App Intent.
- LockedInWidgets: multi-platform WidgetBundle; существующий Dynamic Island только iOS.

App Group: iPhone — group.com.alan.planner; Mac — <TeamID>.com.alan.planner. Отдельные *.macOS.entitlements и условный Info.plist TrackItAppGroup используются только при sdk=macosx. Группа iPhone не менялась. В каталоге TrackItWidgets приложение атомарно публикует app.json только при изменении содержимого. Provider сохраняет отдельный remote_<source+user>.json и сохраняет pending-правки приложения при наложении серверного ответа. Provider не открывает LocalRepository/OfflineTaskRepository приложения.

Завершение сначала сохраняется отдельным JSON в commands/, затем пробует сервер при совпадении пользователя. ACK остаётся в журнале до обработки приложением. Более позднее переоткрытие задачи не перекрывается старым ACK. При запуске/refresh приложение импортирует команды через mutate(.completed), сохраняет свою очередь и только потом удаляет команду. Darwin notification ускоряет импорт в открытом приложении. Старые/чужие источники изолированы; удалённые задачи не восстанавливаются.

Маленький размер удалён; прокрутка внутри WidgetKit не поддерживается. WidgetKit сам выбирает момент фонового обновления. Provider запрашивает обновление примерно через 15 минут, планирует переходы дедлайнов и полуночи. Изменение данных в приложении, запуск, уход в фон и действия виджета вызывают reload. При свежем app.json provider сразу отображает общие данные без сетевого ожидания. Серверный ответ, начатый до изменения app.json, отбрасывается.

## Подпись и запуск
Оба target должны иметь одну Apple Development Team и capability App Groups с group.com.alan.planner. При устройственной сборке группа должна быть зарегистрирована и включена в provisioning profiles обоих targets. Настройки уже описаны в entitlements. Текущий Bundle ID extension com.alan.planner.activities сохранён для совместимости с Live Activity.

На текущем Mac использовалась ad-hoc подпись без sandbox основного приложения. При ручном обновлении:
1. Собрать Planner для macOS с CODE_SIGNING_ALLOWED=NO.
2. Подписать вложенную LockedInWidgets.appex с её entitlements (sandbox/network/group).
3. Подписать TrackIt.app с отдельным entitlement, содержащим только com.apple.security.application-groups. Не добавлять sandbox к уже работающей локальной копии: это меняет путь хранилища.
4. Проверить codesign --verify --deep --strict, заменить apple/build/TrackIt.app, зарегистрировать pluginkit -a <app>/Contents/PlugIns/LockedInWidgets.appex.

Регистрация extension не доказывает наличие доступа к группе или успешный запуск WidgetKit. Проверять реальные виджеты через галерею macOS. В логах subsystem com.alan.planner/category widgets доступны результат публикации и ошибки без названий задач.

## Проверка
swift test --package-path apple/Packages/LockedInKit --filter 'WidgetAgendaTests|WidgetStoreTests|WidgetRenderingTests'

Snapshot-проверка рисует все размеры в двух темах на синтетических данных в /private/tmp/trackit-widget-previews. Пользовательские задачи для тестирования не менять. Системные виджеты: рабочий стол Mac → «Изменить виджеты» → TrackIt; iPhone → добавление виджетов → TrackIt.

## Исправление Mac App Group
Подтверждено в логах: ad-hoc подпись с group.com.alan.planner получала permission denied при публикации app.json. Настроена Mac-only Team-prefixed группа, которой не требуется provisioning profile. Для доступа по-прежнему необходим действительный сертификат Apple Development с Team ID, одинаковый у приложения и extension. Пользователь разрешил это изменение. На момент подготовки сертификата в keychain не было; создание через Xcode Apple Accounts → Manage Certificates выполняет пользователь. Не подставлять выдуманный Team ID и не обходить защиту контейнеров.

Ссылки lockedin:// предпочитают уже открытый главный scene через handlesExternalEvents(preferring:allowing:), сохраняя onOpenURL в RootView.

Настроенная Team Mac: 8PXFA2R38Q. Сертификат Apple Development установлен пользователем. Для цепочки используется официальный WWDR G3 из Xcode (AppleWWDRCA-2030.cer); настройки доверия не переопределялись. Ad-hoc переподпись после обновления недопустима для доступа к Team-prefixed группе.

Настройка завершена: сборка подписана Apple Development Team 8PXFA2R38Q, фактическое имя группы проверено в Info.plist обоих bundles. Установленная версия успешно публикует snapshot (Published widget snapshot в журнале); прежняя ошибка записи в group.com.alan.planner устранена. При следующем обновлении разворачивать переменную DEVELOPMENT_TEAM в *.macOS.entitlements до вызова ручного codesign, подписывать extension первой, приложение вторым, одним действительным сертификатом Team 8PXFA2R38Q. Не использовать iPhone entitlements для Mac.
