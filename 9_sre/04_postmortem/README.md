# 04. Postmortem

> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) — команды и шаблоны одним экраном.

## Зачем
Инцидент без разбора повторится. Blameless postmortem ищет системные
причины (почему процесс позволил ошибке случиться), а не виноватого, и
превращает инцидент в конкретные action items с владельцами и сроками.

## Пререквизиты
- [03_incident_management](../03_incident_management/) — lifecycle
  инцидента и timeline.

## Файлы
- [CHEATSHEET.md](./CHEATSHEET.md) — шпаргалка: шаблон, 5 почему, action items.
- [01_theory/postmortem.md](./01_theory/postmortem.md) — принципы
  blameless, пример заполненного postmortem, техника «5 почему», когда
  postmortem обязателен.
- [02_examples/postmortem-template.md](./02_examples/postmortem-template.md)
  — пустой шаблон для заполнения.

Без лабы: тема о процессе; материал для разбора — инцидент из
[README_practical.md](../README_practical.md) (шаги 6-8) или ваш
реальный.

## Как проходить
1. Прочитать теорию.
2. Заполнить шаблон по инциденту из сквозного примера: timeline,
   «5 почему», action items.
3. Перечитать текст и убрать формулировки, ищущие виноватого.

## Когда двигаться дальше
- Можете переформулировать «Вася выкатил баг» в системную причину.
- Можете отличить root cause от contributing factors.
- Можете написать action item, который можно проверить (владелец,
  срок, критерий готовности).

Дальше — [05_on_call](../05_on_call/).
