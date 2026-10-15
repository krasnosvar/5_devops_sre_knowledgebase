# Ответы — GitLab CI

Итоговый файл после всех упражнений:
[.gitlab-ci-answer.yml](./.gitlab-ci-answer.yml). Ниже — шаги по каждому
упражнению. Команды предполагают стенд из упражнения 00 (GitLab на
http://localhost:8929, раннер зарегистрирован) или проект на GitLab.com.

## Упражнение 01 — Первый pipeline

Создать проект в UI (без README), затем локально:

```bash
mkdir ci-lab && cd ci-lab
git init -b main
echo "# ci-lab" > README.md
# .gitlab-ci.yml — содержимое из условия упражнения 01
git add README.md .gitlab-ci.yml
git commit -m "first pipeline"
git remote add origin http://localhost:8929/root/ci-lab.git
git push -u origin main
```

Проверить: проект → Build → Pipelines.

Ожидаемый вывод (примерно так, лог джобы `build`):

```text
$ echo "Building app..."
Building app...
$ mkdir -p dist && echo "VERSION=1.0.0" > dist/version.txt
Uploading artifacts for successful job
dist/: found 2 matching artifact files and directories
Job succeeded
```

Почему так: три стадии идут последовательно, каждая джоба — в новом
контейнере. `dist/` доступен для скачивания (кнопка Download у джобы)
только потому, что объявлен в `artifacts`.

## Упражнение 02 — Rules — условный запуск

Добавить `rules` ко всем джобам (как в
[.gitlab-ci.yml-ответе](./.gitlab-ci-answer.yml)) и проверить на ветке:

```bash
git checkout -b feature/rules
git commit --allow-empty -m "check rules"
git push -u origin feature/rules
# в UI открыть Merge Request из feature/rules в main
```

Ожидаемый вывод (примерно так):

```text
MR pipeline:   lint ✓  test ✓            (build и deploy отсутствуют)
main pipeline: lint ✓  test ✓  build ✓  deploy ▶ (manual, ждёт кнопку)
```

Почему так: в MR-пайплайне `build`/`deploy` не проходят ни одно правило
и не попадают в пайплайн вовсе. `when: manual` указан внутри правила:
`rules` целиком определяют, когда и как джоба запускается. Отдельного
пайплайна для push в `feature/rules` нет — правила разрешают только MR и
main, поэтому дубля «branch + MR pipeline» не возникает.

## Упражнение 03 — Cache зависимостей

```bash
printf 'pytest\n' > requirements.txt
mkdir -p tests
printf 'def test_ok():\n    assert 1 + 1 == 2\n' > tests/test_smoke.py
# в .gitlab-ci.yml — джоба test с cache из условия упражнения 03
git add requirements.txt tests .gitlab-ci.yml
git commit -m "cache venv"
git push
# затем перезапустить пайплайн (Run pipeline) без изменений
```

Ожидаемый вывод (примерно так, второй запуск):

```text
Checking cache for 1a2b3c...-protected...
Successfully extracted cache
$ pip install -r requirements.txt
Requirement already satisfied: pytest in ./.venv/lib/python3.12/site-packages
...
Saving cache for successful job
```

Почему так: ключ кэша — хеш `requirements.txt`, пока файл не меняется,
venv восстанавливается и `pip install` почти ничего не скачивает. Время
сравнить по строке `Job succeeded in ...` в первом и втором запусках.
Кэш — оптимизация: если его нет, джоба всё равно должна пройти.

## Упражнение 04 — Matrix builds

Заменить джобу `test` на вариант с `parallel: matrix` (итог — в
[.gitlab-ci-answer.yml](./.gitlab-ci-answer.yml)):

```bash
git add .gitlab-ci.yml
git commit -m "matrix 3.10-3.12"
git push
```

Ожидаемый вывод (примерно так, в UI):

```text
test: [3.10]   passed
test: [3.11]   passed
test: [3.12]   passed
```

Почему так: `parallel: matrix` создаёт по джобе на значение
`PYTHON_VERSION`, они идут параллельно (если хватает `concurrent` у
раннера). У кэша `prefix: py${PYTHON_VERSION}` — иначе джобы делили бы
один venv, собранный другой версией Python. `|| echo` из условия убран:
он скрывал бы упавшие тесты.
