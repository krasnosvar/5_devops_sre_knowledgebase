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
  `4_kubernetes/07_gitops/{01_theory/, 02_argocd/, 03_fluxcd/, 04_argo_rollouts/}`,
  `4_kubernetes/09_manifests_management/{01_theory/, 02_helm/, 03_kustomize/}`.

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
- **No duplication across files:** before adding a question, check whether the same
  concept is already asked (verbatim or near-verbatim) in a file this one cross-links
  to — pick ONE home for it and point the other file there instead of repeating it.
- **Quality & Depth:** Questions should be challenging, deep, and often contain a "trick" (подвох) or edge case (e.g., "Why does an unprivileged user fail to use `renice -10` on their own process?"). 
- **Relevance:** Questions must be strictly relevant to the exact topic of the file. Do not include questions that belong to a different technical domain.

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
