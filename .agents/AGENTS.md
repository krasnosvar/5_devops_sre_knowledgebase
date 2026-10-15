# Repo Context & Conventions

This is a Russian-language DevOps/SRE/MLOps knowledge base, written as a practical
roadmap for senior engineers: theory + runnable configs/scripts + exercises with
lab stands. Root `README.md` is the master index of top-level topics — it MUST be
kept in sync any time a subsection is added, removed, renamed, or nested; the same
applies to each top-level topic's own `README.md`.

All new content — theory, code comments in examples, exercise text — is written in
Russian, matching the rest of the repo.

## Directory & Structural Conventions

- Top-level topics: `<N>_<name>/` with a sequential integer prefix (`0_lab_setup`,
  `1_linux_and_shell`, ... `11_mlops`, `other`). Don't assume the prefix list on disk
  and in root `README.md` agree — verify with `ls` before trusting either; this repo
  has a history of README/disk drift after renumbering.
- Standard leaf template per subsection: `01_theory/` (mandatory), `02_examples/`,
  `03_exercises/`, `04_exercises_answers/`. Add examples/exercises only where a real
  hands-on lab makes sense; skip them (and say so explicitly in the theory doc, e.g.
  "без лабы: требует реальное облако") for cloud-only or reference-only topics.
- **If `01_theory/` ever holds 2+ files, give each a numeric reading-order
  prefix** (`01_`, `02_`, ...), e.g. `4_kubernetes/03_networking/01_theory/
  {01_k8s_networking.md, 02_k8s_networking_flow.md}` (concepts first, deep-
  dive second). Most topics here only need one file and that file keeps its
  plain descriptive name (no prefix needed for a single file) — this only
  applies once a topic's theory is split across multiple files, so a reader
  browsing the bare directory (GitHub, no README open) can tell which one to
  open first without guessing from alphabetical order. Same rule as the
  sibling `6_ai_engineering_knowledgebase` repo, which hit this for real
  across all 13 of its sections (lesson files there are numbered by
  design, not just an edge case).
- Lab tier legend (used everywhere upgrades/exercises reference a stand):
  🐳 Tier 1 — Docker Compose only; 🖥 Tier 2 — local VM (KVM/OrbStack/VirtualBox);
  ☁️ Tier 3 — real cloud/VPS.

## Nested Sub-Tool Convention

When a subsection's topic naturally contains 2+ independent, swappable tools that
are each deep enough to deserve their own theory+examples+exercises (ArgoCD vs Flux,
Helm vs Kustomize, OPA Gatekeeper vs Kyverno, Cluster Autoscaler vs Karpenter) —
do **not** create a separate top-level numbered topic per tool. Nest them as numbered
subdirectories *inside* the parent subsection, continuing that parent's own
`01/02/03/04` numbering:

- If the parent's general content occupies only `01_theory/` (no `02_examples` etc. of
  its own) — nested tools become `02_<tool>/`, `03_<tool>/`, ... directly.
- If the parent's general content already occupies `01_theory/02_examples/03_exercises/
  04_exercises_answers` — first wrap ALL of that general content into its own
  `01_core/` subdirectory (with its own nested `01_theory/02_examples/...` inside),
  *then* nest tools starting at `02_<tool>/`. Never mix a bare `01_theory/` directly
  under the parent with numbered tool-subdirectories as siblings — the parent's
  top level must be uniform: either all leaf files, or all numbered sub-topics, never both.
- Reserve top-level numbered topics for things that don't cleanly belong inside one
  existing parent (cross-cutting bridge topics like Operators/CRDs, or reference/
  landscape pages like the ecosystem overview).
- Worked examples on disk: `4_kubernetes/06_security/{01_core/, 02_policy_engines/}`,
  `4_kubernetes/07_manifests_management/{01_theory/, 02_helm/, 03_kustomize/}`,
  `4_kubernetes/09_gitops/{01_theory/, 02_argocd/, 03_fluxcd/, 04_argo_rollouts/}`.

## Renumbering History (grep old names as plain text after any rename)

- 2026-10-14: `4_kubernetes/07_gitops` <-> `09_manifests_management` swapped
  (GitOps used Helm/Kustomize before they were taught) — now
  `07_manifests_management/` and `09_gitops/`.
- 2026-10-14: new beginner topic `4_kubernetes/00_first_steps/` (cluster,
  kind, kubectl basics, first Pod/Deployment/Service) before
  `01_architecture`.
- 2026-10-14: `13_books_certs_resources/{02_certifications,
  03_books_and_resources}` -> `{01_certifications, 02_books_and_resources}`.
- 2026-10-14: multi-file theory dirs got reading-order prefixes:
  `7_compute_platforms/02_aws/01_theory/00_aws_core.md` (overview first),
  `8_observability/02_*/01_theory/{01_prometheus,02_promql}.md`,
  `8_observability/05_*/01_theory/{01_loki,02_loki_logql}.md`,
  `8_observability/06_*/01_theory/{01_distributed_tracing,02_tracing}.md`.
- Older stale names seen in the wild: `7_observability`, `4_iac`,
  `3_kubernetes`, `2_containers` (pre-renumber) — must not reappear.

## Topic README Template

Every topic dir (`<section>/<NN_topic>/`) has a `README.md` with:
`# NN. Название`, `## Зачем` (concrete problem), `## Пререквизиты` (links;
tools used before they're taught get an explicit «Забегание вперёд» note
with a link and the minimum needed, or the part is marked optional),
`## Файлы` (every file/dir linked), `## Как проходить`,
`## Когда двигаться дальше` (self-check criteria + next topic link).
Section READMEs additionally carry `## Пререквизиты` and
`## Когда двигаться дальше`. Git is not taught in this repo — link to
`../4_python_my_knowledgebase/0_tooling_and_workflow/01_git_essentials/`.

## Cheat-Sheet Convention (CHEATSHEET.md)

Quick reference for an engineer who already knows the topic (added
2026-10-15). Format follows the sibling repos'
`4_python_my_knowledgebase/.../01_git_essentials/CHEATSHEET.md`.

- **One `CHEATSHEET.md` per topic dir** — every dir that holds
  `01_theory/` in sections 0–11 and 14, next to its `README.md`, even
  for small topics (chosen over combined per-section sheets so the
  README link is always `./CHEATSHEET.md` and no anchors break).
  Nested sub-tools (`02_helm/`, `03_fluxcd/`, ...) get their own sheet.
  None in `12_interview_questions_prep` (separate Q&A format) or
  `13_books_certs_resources`.
- Layout: `# <Тема> — шпаргалка`; first line links the theory file(s)
  and says `⚠️` = опасная команда / частая ловушка; unnumbered `##`
  groups with dense `| :--- |` tables (commands + key flags, query
  patterns, defaults/typical values, «когда что использовать»,
  «Симптом → куда смотреть», one-line pitfalls); short fenced snippets
  allowed; no prose paragraphs; ~1–3 screens. `|` inside cells is
  escaped as `\|`.
- Content comes only from what the topic's theory teaches; if a sheet
  and the theory disagree, fix the wrong one so both match.
- Last line: `> Проверка: <how verified, tool versions>; не проверено:
  <list or —>.` Never claim verification that wasn't run.
- Topic `README.md` links it right under the H1
  (`> Уже знакомы с темой? → [CHEATSHEET.md](./CHEATSHEET.md) ...`) and
  as the first `## Файлы` bullet; root `README.md` keeps a
  `## Шпаргалки` index grouped by section — update it when a topic is
  added/renamed.

## Canonical Homes (de-duplication)

- Pod Security Standards / PSA — `10_devsecops/05_pod_security/`;
  `3_containers/05_security` and `4_kubernetes/06_security` keep a short
  gloss + link.
- GitOps — `4_kubernetes/09_gitops/`; `6_cicd/05_gitops_cd` keeps only the
  CI side (tag bump, promotion) + link.
- Protocols — `2_networking/`; `1_linux_and_shell/06_networking_basics` is
  a Linux-tooling intro linking forward.
- Certifications — `13_books_certs_resources/01_certifications/`.

## Exercise Answer Format

- `04_exercises_answers/` holds `.md` files, not runnable `.sh` "answer
  scripts": per exercise `## Упражнение N — ...`, the commands a learner
  types in order (```bash), expected output (```text, approximate), and a
  short «почему так». Exercise numbers/titles must match
  `03_exercises/README.md`.
- Real config files that are part of the answer (`.yaml/.tf/.py/.conf`) stay
  as files and are referenced from the `.md`. A `.sh` may remain only when
  the exercise literally asks to write a script — then it must be correct
  (`set -euo pipefail`, `bash -n` clean, no `|| true`, no faked output).
- No `-auto-approve`, plan before apply, destroy at the end.
- Examples with destructive live commands (`terraform state rm`,
  `aws ec2 terminate-instances`) are `.md` with fenced code, never
  executable `.sh`.
- `12_interview_questions_prep/**/*.sh` Q&A files are a separate,
  intentional format — never convert them.
- The capstone `0_lab_setup/05_capstone_project/` is the FINAL project
  (done after the sections each stage depends on), despite living in
  `0_lab_setup`.

## Cross-Reference Discipline

Sections link to each other constantly via relative markdown links
(`[text](../../other_section/)`). Any rename, move, or nesting change breaks an
unpredictable number of these — depth changes by exactly one level of `../` for
every level of nesting added or removed.

**After any structural change, re-verify every relative link — don't rely on memory.**
A short script does this reliably: glob all `*.md` files, regex-match
`\]\(\.\./[^)]+\)` links, resolve each against its file's directory with
`os.path.normpath(os.path.join(dirname, link))`, and check `os.path.exists`. Run it
repo-wide (not just in the touched subtree) since other sections may link *into*
the paths you just changed.

For Kubernetes YAML that uses Kustomize, validate for real with `kubectl kustomize
<dir>` (kubectl is available in this environment) instead of only eyeballing syntax
— this has caught real bugs, e.g. `$patch: delete` being silently ignored when
nested under `metadata:` instead of placed as a top-level key alongside `apiVersion`/`kind`.

## Git & Workspace Discipline

- **Line Length (70–80 символов):** Весь текст — как в ответах пользователю
  в чате, так и во всех файлах репозитория — СТРОГО форматировать с жестким
  переносом строк по 70–80 символов (длинные неперенесённые строки
  неудобно читать с монитора 24 дюйма).
- **Permissive mode enabled (Правка файлов и запуск команд без уточнения):**
  Всегда править, модифицировать и создавать файлы напрямую без
  предварительного запроса подтверждения или лишних уточнений, если
  пользователь явно не запретил редактирование. Команды на чтение,
  диагностику, проверку синтаксиса, поиск и валидацию (python3, bash -n,
  git status/diff, grep, find, линтеры) выполнять автономно без лишних
  вопросов.
- **NEVER create git worktrees:** Agents must NEVER create or use git
  worktrees (`git worktree` / `git worktree add`) under any circumstances.
  Always work directly within the primary repository workspace.
- **Do not commit without explicit instruction:** Never create git commits
  unless the user explicitly asks to commit.

---

# Theory Files Formatting Rules

When generating or refactoring theoretical knowledge base files (like those in devops, python, or go knowledgebase repositories), YOU MUST ADHERE to the following strict structural and content guidelines.

## 1. Depth of Theory (Глубина теории)
- **Target Audience:** Senior DevOps / SRE engineers.
- **Content Depth:** Do not write superficial summaries. Dive deep into OS internals, kernel mechanisms, and "under the hood" concepts. 
- **Required Elements:** Mention specific system calls (e.g., `fork`, `exec`, `epoll`, `clone`), kernel structures (e.g., `inodes`, `dentry`, `Page Cache`), memory management (RSS vs VSZ, OOM Killer), IPC, and architecture differences (e.g., cgroups v1 vs v2, select vs epoll). Include practical `bash` command examples that an SRE would use to debug these concepts.

## 2. Document Structure
- **Table of Contents (TOC):** Always start the file with a numbered Table of Contents (`## Содержание`).
- **Numbered Headings:** Number all main H2 (`##`) chapters to exactly match the TOC (e.g., `## 1. Процесс — основная единица выполнения`).
- If there are sub-chapters (H3 `###`), number them hierarchically (e.g., `### 6.1 procfs (/proc)`).

## 3. Interview Q&A Section
- The final chapter must ALWAYS be `## N. Типовые вопросы на собеседовании (Interview Q&A)`.
- **Quantity:** **10 is the default target** for a single, focused topic — not a hard
  law. If a file legitimately merges several sub-themes (e.g. RBAC + SecurityContext +
  NetworkPolicy + Secrets in one security doc), it's fine to exceed 10 — more real,
  non-duplicate questions beat padding to hit a number or artificially trimming good
  content. If a doc is a short addendum/pointer section or a pure reference/landscape
  page, it's fine to have fewer questions, or skip the section entirely.
- **Quality & Depth:** Questions should be challenging, deep, and often contain a "trick" (подвох) or edge case (e.g., "Why does an unprivileged user fail to use `renice -10` on their own process?"). 
- **Relevance:** Questions must be strictly relevant to the exact topic of the file. Do not include questions that belong to a different technical domain.
- **Company Anonymity:** Never mention specific company names (e.g., Yandex, Sber, VK, Alibaba, Amazon etc.) when formulating or cataloging interview questions. Present all questions objectively without attributing them to any specific employer.
- **Format Constraint (.sh):** All interview question files MUST STRICTLY be created and maintained with a `.sh` file extension. NEVER convert them to `.md` or any other format. This is a hard requirement from the user.

## Example Structure:
```markdown
# Название темы (Например: Процессная модель)

## Содержание
1. [Глубокая тема 1](#1-глубокая-тема-1)
2. [Глубокая тема 2](#2-глубокая-тема-2)
3. [Типовые вопросы на собеседовании (Interview Q&A)](#3-типовые-вопросы-на-собеседовании-interview-qa)

---

## 1. Глубокая тема 1
(Здесь хардкорная теория, упоминание сисколлов, структур ядра, примеры в bash...)

## 2. Глубокая тема 2
...

## 3. Типовые вопросы на собеседовании (Interview Q&A)
**1. Вопрос с подвохом для Senior SRE?**
*Ответ:* Развернутый ответ с объяснением внутренней работы ядра...

(ровно 10 глубоких вопросов)
```

## 4. Universal Line Length Rule (70–80 characters, `.md` AND `.sh`)
- **Applies to ALL text in the repository**, both `.md` theory/documentation
  files and `.sh` interview-question files: hard-wrap prose at ~70-80
  characters (max 80), explicit line breaks, not reliance on a renderer's
  soft-wrap.
- **Known current gap, phased fix (explicit user decision, recorded here):**
  an audit found many existing `.md` theory files (including ones written
  this session, before this rule was reinstated) have unwrapped prose lines
  of 100-600+ characters. That content is **not** compliant and is technical
  debt, not an accepted exception — don't cite it as precedent for new
  content.
  - **Phase 1 (now, ongoing):** every `.md`/`.sh` file newly written, or
    edited for any other reason, must be wrapped at 70-80 chars as part of
    that same edit — both brand-new files and files you're touching for an
    unrelated change. Don't leave touched files at their old unwrapped width.
  - **Phase 2 (later, separate explicitly-scoped task):** a dedicated
    retroactive reflow pass across every pre-existing long-line `.md` file
    repo-wide (both this repo and the sibling `6_ai_engineering_knowledgebase`
    repo), done on its own, not bundled silently into unrelated work. Dry-run
    on copies first and scan for the reflow-script bug signature below before
    applying destructively.
- **Benefits:** comfortable reading in standard terminal viewports (`cat`,
  `less`, `vim`), clean/granular `git diff`, repo-wide consistency.
- **Allowed exceptions:** unbreakable URLs/links, code snippets where
  wrapping breaks executable syntax, Markdown tables, diagram definitions.
- When wrapping/rewrapping `.sh` files programmatically, dry-run on a copy
  first and scan the result for a specific failure mode seen before: two
  "label:\n- bullets" groups with no blank line between them can get merged
  (the second label silently glued onto the tail of the previous bullet).

## 5. Interview Questions (.sh) Formatting Rules
- **Line Length (Перенос строк):** Strictly adhere to the 70-80 characters
  per line limit (§4) with explicit line breaks. Apply indentation and
  spacing exactly as seen in the first two questions of `01_linux/05_bash.sh`.
- **Introductory Fundamentals:** Every `.sh` question file must begin with basic, foundational questions (e.g., "What is a process?", "What is Bash?", "What is Docker?", "What are cgroups and namespaces?"). Do not jump straight into advanced concepts without covering the underlying definitions and mechanisms first.
- **Multi-line question headers:** when a question is too long for one line,
  wrap the continuation WITHOUT repeating the `# ` prefix or any other marker
  — just plain indented/unindented continuation text. A past bug produced
  stray duplicated `#` prefixes mid-sentence; never reproduce that pattern.
- **Follow-up sub-questions:** when a user asks a conceptual follow-up about
  an *existing* numbered question, embed it inside that SAME question as a
  `**Доп. вопрос: ...?**` paragraph — don't create a new top-level numbered
  entry for it (keeps numbering stable; verify with
  `grep -cE '^# [0-9]+\.' file.sh` unchanged before/after).

## 6. Clarity Principle — explain WHAT/WHY before internals
A real bug found and fixed in this repo: a kubelet/PLEG section jumped
straight into an internal mechanism ("PLEG subscribes via gRPC streams")
without ever plainly stating what kubelet actually does, and the specific
mechanism claim was only half-true (true for newer Evented PLEG, false for
the default Generic PLEG, which polls). Two failure modes to actively check
for when writing or reviewing theory content:
- **Jargon-before-plain-language:** a component/mechanism is named and an
  internal detail asserted before the reader has been told, in plain terms,
  what it does and what problem it solves. Fix: lead with a short plain-
  language breakdown (numbered steps are fine) before any internals.
- **Imprecise mechanism claims:** describing a mechanism in its simplified,
  "commonly believed" form when the real mechanism is more specific (polling
  vs push, sync vs async, default vs newer-opt-in variant). Verify the actual
  mechanism before writing it down — don't repeat a plausible-sounding but
  half-right claim just because it's commonly stated that way elsewhere.
When auditing existing content at scale, parallel read-only fork/subagent
passes (one per group of files, explicitly told not to edit) are an
effective way to surface this class of issue across many files without
blowing up the reviewing agent's own context — then triage and fix directly.

## 7. Granularity Principle
Don't compress multiple independent sub-themes that each deserve their own
explanation/worked-example into one file or one section — split instead.
Cautionary tale from a sibling repo in this series
(`6_ai_engineering_knowledgebase`): several sections compressed 6-9 distinct
listed concepts into a single ~100-line lesson file with exactly one
self-check question, which under-serves every concept crammed into it.
If a topic's own planning doc lists more than ~3-4 genuinely distinct
sub-concepts, that's a signal to split into multiple theory files/sections
rather than one dense file — matches this repo's own existing "Nested
Sub-Tool Convention" and "exceed 10 Q&A questions rather than pad/trim"
guidance above: more real, well-separated content beats one crowded file.

## 8. Lessons From the Sibling Python Repo's Full Audit (2026-10-13)
A repo-wide clarity audit of `4_python_my_knowledgebase` found problems no
structural check catches. Those that carry over to this repo:
- **Every topic README answers "зачем"** — the concrete problem the topic
  solves, not only a list of files.
- **Run code you add or change — reading is not verification.** Bugs found
  only by running: a missing import, a parameter read from the wrong place,
  an example that didn't demonstrate what the prose claimed. Here: run the
  bash snippets/scripts, `kubectl kustomize`, `docker compose config`,
  `terraform validate` wherever the tool is available.
- **Reordering can move the bug instead of fixing it** — after moving a
  section/file earlier, re-check that it doesn't now use terms defined only
  later.
- **Audit full files, not the first file per topic** — spot-checks missed
  bugs a full read found immediately; parallel read-only forks per group of
  topics, each reading everything in full, worked well.
- **Pointers into sibling repos are not explanations** — a reader may not
  have that repo; explain inline briefly and link as "подробнее".
- **Mixed Latin+Cyrillic words** ("коммit", "formы", "momент") — see §9
  item 6.

## 9. Validation Checklist (run after any batch of edits)
Run these repo-wide (not just on touched files — other files may reference
what you changed), via a quick Bash/Python one-liner each:
1. **Line width** — no `.sh` interview file line over 80 chars.
2. **Fence balance** — ``` grep -c '^```' file ``` is even in every `.md`/`.sh`.
3. **Sequential numbering** — `.sh` files: `grep -cE '^# [0-9]+\.'` count matches
   the highest number used, no gaps, no duplicates.
4. **No company-name attribution** — interview questions never say "spotted
   at Yandex/Sber/Amazon/etc." (naming cloud products like AWS/GCP is fine;
   attributing a *question* to a specific employer is not).
5. **No trailing whitespace** — `grep -rnE ' +$'`.
6. **No stray mixed-script glyphs** — a known artifact from prior edits is a
   single CJK character accidentally inserted into Cyrillic/Latin text (e.g.
   "тема架ектурная", "raскатку" with a Latin r). Scan with
   `grep -nP '[\x{4e00}-\x{9fff}]'` across touched files. Also scan for words
   glued from Latin + Cyrillic:
   `grep -rnoP '\b\w*(?:[а-яё][a-z]|[a-z][а-яё])\w*\b' --include='*.md'
   --include='*.sh' .` — review hits by hand (string escapes like `\nтекст`
   are legit).
7. **Relative links resolve** — glob all `*.md`, regex `\]\(\.\./[^)]+\)` or
   `\]\(\./[^)]+\)`, resolve each with `os.path.normpath(os.path.join(dirname,
   link))`, assert `os.path.exists`. Run repo-wide after every structural
   change (see "Cross-Reference Discipline" above) — this has caught real
   off-by-one `../` depth errors when inserting new nested files.
8. **TOC/heading match** — count of numbered TOC entries equals count of
   numbered `## N.` headings in the same file; a real bug found this way was
   a TOC entry for "§5" with no corresponding `## 5.` heading in the body.
9. **Self-reporting hygiene** — if the repo (or a sibling repo) keeps a
   top-level doc that states exact inventory numbers (lesson count, question
   count, file count), update that doc in the SAME change that alters the
   structure it's counting. A stale "35 lessons" claim after a restructure is
   worse than no claim.
10. **Cheat-sheets complete & verified** — every topic dir with
   `01_theory/` in sections 0–11 and 14 has a `CHEATSHEET.md` linked from
   its README and from the root `## Шпаргалки` index; commands added or
   changed in a sheet were checked (`--help`, `bash -n`, `promtool check
   rules`, `yamllint`, `terraform validate` in a scratch dir, `kubectl`
   only with `--context kind-...`), and its `> Проверка:` line is
   updated. Run the glued Latin/Cyrillic and CJK scans (item 6) in
   Python — `grep` may be aliased to `ugrep`, where the PCRE Cyrillic
   class silently matches nothing.

