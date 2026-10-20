# 01. Теория CI/CD и стратегии развертывания

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — команды и шаблоны одним экраном.

## Зачем
Прежде чем писать `.gitlab-ci.yml` или workflow GitHub Actions, нужно
понимать, что именно автоматизируется: чем CI отличается от Continuous
Delivery и Deployment и как выкатывать новую версию без простоя (Rolling,
Blue/Green, Canary, feature toggles). Эти решения принимаются на работе
при каждом проектировании пайплайна и разборе неудачного релиза.

## Пререквизиты
-  [Git:
  основы](../../../4_python_my_knowledgebase/0_tooling_and_workflow/01_git_essentials/)
  (соседний репозиторий) — коммиты, ветки, merge request: пайплайн
  запускается именно на эти события. Git в этой базе отдельно не
  преподаётся.
- [3_containers](../../3_containers/) — что такое образ и registry:
  результат CI почти всегда Docker-образ.

## Файлы
- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: стратегии деплоя, когда что.
- [01_theory/cicd_theory.md](./01_theory/cicd_theory.md) — CI vs CD vs
  Deployment, Rolling Update, Blue/Green, Canary, A/B и feature toggles,
  вопросы с собеседований.

Без примеров и упражнений: тема концептуальная, практика — в
[02_gitlab_ci](../02_gitlab_ci/) и [03_github_actions](../03_github_actions/).

## Как проходить
1. Прочитать теорию целиком.
2. Ответить на вопросы раздела Interview Q&A, не подглядывая в ответы.

## Когда двигаться дальше
- Можете объяснить разницу между Continuous Delivery и Continuous
  Deployment одной фразой.
- Можете сравнить Rolling, Blue/Green и Canary по стоимости ресурсов,
  скорости отката и риску.
- Понимаете, зачем feature toggles, если уже есть Canary.

Дальше: [02_gitlab_ci](../02_gitlab_ci/) или
[03_github_actions](../03_github_actions/) — по используемой платформе.
