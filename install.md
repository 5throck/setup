# install.md — Workshop Setup Automated Install Guide (for AI agents)

> **To the AI reading this file (Claude Code / Codex / Gemini CLI / Antigravity, etc.)**
> This document is the **runbook** to follow when the user asks "read install.md and install everything".
> Work from top to bottom, and only move to the next step once the **Verify** check of the current step passes.
> The **language of messages shown to the user is determined in §3-0 from the language settings of the system being installed**.
> Supported languages are **English / Korean / Japanese / Spanish**. If none applies, or detection fails, use **English**.

Target repository (this folder = the install-script project):

| Component | Purpose |
|---|---|
| `setup-mac.sh` / `setup-linux.sh` | Automated install scripts for macOS / Linux (Ubuntu·Debian) |
| `setup-windows.ps1` | Automated install script for Windows (requires PowerShell 7+; relaunches itself if run under 5.1) |
| `setup-lib.sh` | Shared mac/linux helpers (progress UI, preflight checks, logging, `--force`, cleanup) |
| `setup-common.ts` | Cross-platform post-install verification script (`bun setup-common.ts`) |
| `SETUP.md` / `SETUP_ko.md` | Detailed setup guide (flags, troubleshooting) |
| `SETUP_CHECKLIST.md` / `SETUP_CHECKLIST_ko.md` | Pre-workshop checklist (accounts, subscriptions) |

Tools installed: base tools (Git everywhere; PowerShell 7 + Windows Terminal on Windows), runtimes (`bun`, `python3`, `uv`), CLIs (`gh`, `claude`, `codex`, `agy`, `gitleaks`), desktop apps (Chrome, Claude/Codex/Antigravity Desktop, Mark). Options: `--wezterm`, `--docker`, Windows `-WSL2`, and `--company <name>` for organizations.

> The commands and flags in this document must stay in sync with `SETUP.md`. If a flag in `SETUP.md` changes, update the matching parts of this document too (`check-docs-sync.sh` checks the SETUP documents for sync, but this document is maintained manually).

---

## 0. Execution principles (must follow)

1. **Delegate the installation to sub-agents** (§2 below). The main agent only handles conversation, guidance, and progress reports with the user.
2. **Because installation takes a long time**, the main agent delivers the **user guidance** from §3 while the sub-agents work. Do not just idly wait for the sub-agents to finish.
3. **Determine the guidance language once via §3-0**, and apply it to every message going out to the user (guidance, status bar titles, reports). Sub-agents may report in any language, but the main agent translates into the detected language when relaying to the user.
4. **No secrets**: never type or guess passwords, API keys, or tokens on the user's behalf. Logins (`gh auth login`, `claude login`, `codex login`) and subscription checks are done **by the user personally**. If a sudo/administrator password prompt appears, tell the user to enter it themselves.
5. **Steps that need administrator/sudo privileges**: tell the user before running them and get confirmation. If privileges are unavailable, skip that step and report it.
6. **Idempotency**: skip tools that are already installed (check with `command -v` / `Get-Command`). The scripts themselves also skip installed items, but add forced reinstall (`--force`/`-Force`) only when the user asks for it. Re-running must be safe.
7. **No `curl | bash` / `irm | iex`**: installer scripts are downloaded to a temporary file, their SHA-256 is printed and logged, and then they are executed (each script in this repository follows the same approach; there is no automatic comparison against an expected hash, so the hash is an audit record). Do not arbitrarily rewrite commands in this document into piped form.
8. **Pin versions only when the user asks**: by default, install the latest release. If the user says they need a reproducible environment, use the `BUN_VERSION` / `UV_VERSION` / `PYTHON_VERSION` environment variables (§4-5). `PYTHON_VERSION` is macOS/Linux only (Windows installs Python 3.13 as a fixed version), and `UV_VERSION` on macOS is not a full pin because Homebrew installs the latest uv.
9. **On a dry-run request, follow §0-1 with top priority** and change nothing.
10. On failure, record the log, continue with the next independent task, and report the list of failures all at once at the end.

Log location: `~/workshop-setup-logs/` (Windows: `%USERPROFILE%\workshop-setup-logs\`)

---

## 0-1. Dry-run mode — preview the process without installing

Use this mode when the user asks with phrases such as **"dry-run", "simulate", "show me what would happen without installing", "드라이런", "시뮬레이션"**, etc. Without such a request, run in normal install mode. If it is ambiguous (e.g. "just try it"), ask the user which mode they want.

> The scripts in this repository have no documented dry-run flag (per `SETUP.md`). The dry run is **demonstrated by the agent at the procedure level only**.

### What a dry run **does**

- **Read-only** commands from the §1 preflight (OS detection, `--version`/`command -v`/`Get-Command`, disk space, checking `SETUP_CHECKLIST.md`)
- §3-0 guidance-language detection (read-only — the guidance itself is delivered exactly as in a real install)
- For each track, print the **list of commands that would actually have been run**, tailored to the current OS and scan results (already installed → `SKIP`, missing → `WOULD RUN`)
- Deliver the §3 user guidance **exactly as in a real install** (the goal is to let the user experience the guidance flow)
- An **expected-result report** in the §7 format (every status marked `[DRY-RUN]`)

### What a dry run **never does**

- Install/update/remove commands (`brew install`, `apt`, `winget install`, `bun install -g`, `wsl --install`, etc.)
- Running the OS install scripts (`bash setup-mac.sh`, `.\setup-windows.ps1`, etc. — running them at all changes the system)
- Downloading remote scripts (including the bun/uv/Codex/Antigravity install scripts — even just downloading is not done)
- Requesting administrator/sudo privileges, or login commands
- Creating log folders/files (including creating `~/workshop-setup-logs/`)

> If a command is borderline, do not run it; just list it as "would run". A dry run must leave **zero** traces on the system.

### Text to add to the sub-agent prompt

```
Mode: DRY-RUN. Use read-only tools only; do not run any command that changes the system or files.
Report each step in the form "[DRY-RUN] SKIP(already installed: <version>)" or "[DRY-RUN] WOULD RUN: <command>".
Also report the estimated duration and what the user must do (permissions, logins, subscriptions).
```

### Output format

Use the following form per track.

```
[DRY-RUN] Track A — OS install script (est. 10–30 min)
  SKIP         git 2.45.0 (already installed)
  WOULD RUN    bash setup-mac.sh            # needs administrator/sudo privileges
  USER ACTION  open a new terminal (to pick up PATH)
```

Finish with a summary.

```
## [DRY-RUN] Expected result — <OS>
To install N / skipped M / manual install K / user actions J / estimated total time about XX min
Changed: nothing
To actually install: "read install.md and install everything" (without mentioning dry-run)
```

Add one line noting that the estimated time is approximate (it varies greatly with the network) and not guaranteed.

---

## 0-2. Output separation rules and update cadence (status every 30 s / guidance every 3 min)

Installation time varies greatly from PC to PC (network, specs, what is already installed). So **do not promise an estimated time**; instead **update the status every 30 seconds and the user guidance every 3 minutes**. The main purpose of this waiting time is **to deliver guidance to the user**, so the guidance is the star of the screen and installation progress is shown only as a small status bar.

### Update cadence — status every 30 s, user guidance every 3 min

| What | Cadence | Format |
|---|---|---|
| **Install status update** | **every 30 s** | **one status-bar line only** (code block, no body) |
| **User guidance** | **one chunk every 3 min** (in §3 order) | status bar + `## 📘` body |
| **Immediate notice** | immediately on a status change | one `🔧 [Install]` line |

1. When installation starts, **record the start time** (`date +%s` / `Get-Date`). All times are **elapsed time** measured from this record.
2. **Every 30 seconds, run the "30-second check list" below**, then send one install status-bar line. Check the sub-agents' status (`⏳/✅/⚠️/❌`) and update it; elapsed time advances even when nothing changed. **Do not attach guidance body** to this message (keep it short).
3. **Every 3 minutes (= 6 status updates)**, send one chunk of user guidance together with the status bar above it. The user needs time to read the guidance, so do not send guidance every 30 seconds.
4. Between updates, leave the sub-agents in the background and **wait**.
   - Claude Code: repeat `sleep 30` to wait → check sub-agent status → print the status bar. When a completion notification arrives, break the wait and notify immediately.
   - Other tools: use whatever wait/timer mechanism is available; if none, compute elapsed time at each point you can check and print the status bar once more than 30 seconds have passed.
5. **Immediate notices**: track completion, warnings, failures, and user action needed (`🙋`) are reported right away without waiting for the next 30 seconds.
6. **Do not state an estimated remaining time.** Show only elapsed time and the completed/in-progress tracks. If you need to express time, just say "still in progress". (The only exception is the rough estimated time in the dry-run report, and even then add "varies by PC".)
7. If all guidance chunks are used up while installation continues, send **only the status bar** every 30 seconds instead of user guidance, and add a one-line encouragement every 3 minutes ("Still in progress" — in the §3-0 language). Do not repeat the same guidance.
8. If installation finishes before the guidance does, trim the remaining guidance to 3 key lines and send the install result table (§7).
9. If one track has been **in progress for 15 minutes or more**, tell the user once "This is taking a while — you may need to check your network" (in the §3-0 language), and point to the log path (`~/workshop-setup-logs/`). Do not abort on your own.
10. If the user says "stop the guidance"/"skip", stop only the user guidance and keep the 30-second status bar going. If they also ask to turn off status updates, send only completion/failure notices.

### 30-second check list — preventing the "never moved to the next step" problem

There have been cases where a sub-agent finished but the next track never started. Completion notifications may not arrive or may be missed, so **do not wait for the notification; directly verify the following at every 30-second status check**. Do this **before** printing the status bar.

| # | Check | Action |
|---|---|---|
| 1 | Query each sub-agent's **actual state** directly (done / running / unresponsive), regardless of whether a notification arrived | If it is done but you have not read the result yet, **read it now** and update the track status |
| 2 | Is there a **track whose prerequisites are met but that has not started**? (A done → start C) | **Start it immediately** and send `🔧 [Install] ✅ Track X done → starting Track Y`. Do not wait for the next 30 seconds |
| 3 | Have all tracks finished but the **final report (§7) not yet been sent**? | Send the §7 install result table immediately, then end status checks |
| 4 | Is a track `⏳` while its sub-agent has already **ended/failed/gone unresponsive**? | Do not leave it as `⏳`; update to `❌` (or `⚠️`) and report the reason. Keep independent tracks going |
| 5 | Has the same `⏳` shown **no change for 20 consecutive checks (10 min) or more**, with no sub-agent output either? | Notify "it looks stuck" + point to the log path + ask the user to choose retry/skip (do not abort on your own) |
| 6 | Is there a track that **depends on a failed track**? (e.g. A failed → C cannot proceed) | Do not leave it in the waiting state (`·`) forever; report "on hold due to a prerequisite failure" and ask the user to choose |

Core principle: it is not "the next step only when a completion notification arrives" but **"at every status check, verify that the next step has started"**. Even when you run sequentially because sub-agents are unavailable, start the next track in the same turn the moment a track finishes.

The status bar must reflect the check results. Example: if you missed a track start, found it during the check and started it, the status bar changes to `C ⏳` and a `🔧 [Install]` start notice must have gone out beforehand.

### Message types

| Type | Format | Role |
|---|---|---|
| **User guidance** (primary) | plain Markdown body starting with `## 📘 <guide title> n/5 — <title>` (headings, lists, tables, example commands) | The body the user reads. Reasonably detailed (10–20 lines) |
| **Install status bar** (secondary) | one code-block line. Alone in a 30-second status update; at the **very top** of a user-guidance message | Install progress |
| **Install event** | one `🔧 [Install] ✅/⚠️/❌ ...` line | Immediate notice of a status change |
| **User action needed** | **bold `**🙋 ...**`**, as a standalone message | Request for a login/subscription/permission/click |
| **Dry run** | `🧪` before the install status bar and install events | e.g. `🧪 🔧 Installing ...` (a dry run takes no real time, so demonstrate only the order without the 3-minute waits) |

> Write the body and title of user guidance in the §3-0 language. Status-bar symbols (`✅ ⏳ · ⚠️ ❌`), track names (A/B/C), and command/tool names (`bun`, `setup-mac.sh`, etc.) stay as they are regardless of language.

### Install status bar format (every 30 s; the top line in guidance messages)

````
```
🔧 Installing  A ✅ │ B ✅ │ C ⏳      elapsed 06:00
```
````

- Status symbols: `✅` done, `⏳` in progress, `·` waiting, `⚠️` warning, `❌` failed.
- Do **not** write install status outside the status bar (in the body), and do not write guidance explanations inside the status bar.

### Other rules

1. Write **the body at a readable length** (10–20 lines, including tables/example commands). Do not get by with a one-line tip.
2. Start notice: "While the installation runs, I'll post progress every 30 seconds and walk you through how to use this environment every 3 minutes." (in the §3-0 language). End notice: "That's all the guidance."
3. Do not paste raw sub-agent logs into guidance messages; summarize them in one `🔧 [Install]` line.
4. Do not mix the two kinds (install events and user guidance) in one message. If they share a message, put the event line first, then the status bar, then the body.

Example output:

````
🔧 [Install] Track A (OS install script) started - running in the background
While the installation runs, I'll post progress every 30 seconds and walk you through how to use this environment every 3 minutes.

```
🔧 Installing  A ⏳ │ B ✅ │ C ·      elapsed 00:30
```

(30 seconds later)

```
🔧 Installing  A ⏳ │ B ✅ │ C ·      elapsed 01:00
```

...(status bar only, every 30 seconds)...

(3 minutes elapsed: status bar + user guidance)

```
🔧 Installing  A ⏳ │ B ✅ │ C ·      elapsed 03:00
```

## 📘 Setup Guide 1/5 — What is being installed?
...

🔧 [Install] ✅ Track A done (bun 1.4.5, uv 0.4.20, gh 2.x) → starting Track C   ← immediate notice

```
🔧 Installing  A ✅ │ B ✅ │ C ⏳      elapsed 03:40
```
````

---

## 1. Preflight (main agent, directly, within 1 minute)

### 1-1. OS detection

| Detection | Method | Procedure to use |
|---|---|---|
| Windows | `$env:OS -eq 'Windows_NT'`, or `uname` is `MINGW*/MSYS*/CYGWIN*` | **Windows procedure** (§4-4) |
| macOS | `uname -s` = `Darwin` | **macOS procedure** (§4-2) |
| Linux (Debian/Ubuntu) | `uname -s` = `Linux` and `ID`/`ID_LIKE` in `/etc/os-release` contains `debian`/`ubuntu` | **Linux procedure** (§4-3) |
| Linux (Fedora/RHEL, Arch, etc.) | `ID`/`ID_LIKE` in `/etc/os-release` | **Out of supported scope** — substitute manual-install guidance and report to the user |
| WSL | `/proc/version` contains `microsoft` | **Linux procedure** (do not mix with Windows-side tools. For desktop apps, give Windows-side guidance) |

Even when running in Git Bash on Windows, perform the install commands the **PowerShell/winget** way (`setup-windows.ps1`).

### 1-2. Checks

- Internet connectivity (access to `https://github.com`, `https://bun.sh`)
- **5 GB or more** of free disk space
- Whether administrator (Windows)/sudo (macOS·Linux) is available — if not, tell the user in advance and get confirmation
- Ask the user whether they have **completed `SETUP_CHECKLIST.md`**: Claude Pro/Max, ChatGPT Plus/Pro (for Codex), Gemini Advanced subscriptions, and a GitHub account. Proceed with installation even if it is not complete, but deliver the guidance again in §5

### 1-3. Current state scan

Query all the tools below and build an `installed/missing` table (pass it to the sub-agents as the basis for "skip what is already installed").

```
bun, git, gh, python(3), uv, claude, codex, agy, gitleaks, pwsh
```

- On Windows use `python` (or `py -3`) and `pwsh`; on macOS/Linux use `python3`.
- Summarize the table above to the user once (in the §3-0 language) and confirm whether to proceed.

---

## 2. Sub-agent execution plan

Split the installation work into **tracks** and hand them to sub-agents.
Each sub-agent prompt receives only the OS detection result from §1, the tool scan table, and the procedure for its own track (§4–§6).

| Track | Sub-agent | Contents | Prerequisite |
|---|---|---|---|
| **A. OS install script** | `setup-os-script` | Run the per-OS install script from §4 | None |
| **B. Manual items guidance** | `setup-manual-apps` | Compile the list of manually-installed items from §5 + prepare user-action guidance | None (can run **in parallel** with A — changes nothing on the system) |
| **C. Verification** | `setup-verify` | Run `bun setup-common.ts` from §6 and summarize results | A done |

Execution order: **A ∥ B in parallel → C**

> Do not rely only on a sub-agent's completion notification for track transitions. At every check, use the **30-second check list** in §0-2 to verify directly whether prerequisites are met, and start the next track.

### How to call sub-agents per tool

- **Claude Code**: create the sub-agents above with the `Agent` tool using `run_in_background: true`. Call A and B **simultaneously in one message**. When a completion notification arrives, read the result and start the next track.
- **Codex**: use the sub-agent (spawn) feature to run the same split. If the feature is unavailable, run "sequentially, track by track", but keep delivering the §3 guidance between tracks.
- **Gemini CLI / Antigravity**: use sub-agent features the same way if available; otherwise substitute sequential per-track execution (background shell `&`/`Start-Process`).
- Sub-agent prompt template:

  ```
  Role: in charge of Workshop Setup install track <A|B|C>.
  Environment: OS=<...>, package manager=<winget|brew|apt|...>, pre-scan result=<table>
  Task: perform the procedure in install.md <§N> in order.
  Mode: <INSTALL|DRY-RUN>  (if DRY-RUN, follow the §0-1 rules)
  Rules: skip what is already installed. Do not touch secrets/logins/subscriptions; report them as "user action needed".
         If administrator/sudo privileges are needed, do not run it; report only the needed command.
  Report format: per-step ✅/⚠️/❌ + installed version + list of what the user must do. (within 500 words)
  ```

---

## 3. User guidance while waiting (main agent)

As soon as the sub-agents start, deliver the guidance below to the user **briefly, step by step**. Output all guidance in the **§0-2 format** (install status bar at the top + `## 📘 ... n/5 — title` body). 3-1 is not guidance but the start notice; the actual guidance is the 5 chunks (1/5–5/5) in 3-2 through 3-6, delivered **one chunk every 3 minutes** in order. Since the **main purpose of this time is user guidance**, do not summarize the content below; deliver it at a readable length.
Do not dump it all at once; deliver one chunk at a time between track completion notices.
Source documents: [SETUP.md](SETUP.md) · [SETUP_CHECKLIST.md](SETUP_CHECKLIST.md) · [README.md](README.md) (Korean translations: `SETUP_ko.md`, `SETUP_CHECKLIST_ko.md`) — provide the links if the user wants to read more

### 3-0. Guidance language detection (a rule unique to this document — always do this first)

**Once** before installation starts, check the language setting of the system being installed, and apply the result to all user guidance.

**Detection method (per OS):**

| OS | Command | Example output |
|---|---|---|
| Windows | PowerShell: `powershell -NoProfile -Command "(Get-UICulture).Name"` (on failure, `Get-WinSystemLocale`) | `ko-KR`, `ja-JP`, `es-ES`, `en-US` |
| macOS | `defaults read -g AppleLocale` (on failure, `defaults read -g AppleLanguages \| head -1`) | `ko_KR`, `ja_JP`, `es_ES`, `en_US` |
| Linux | `echo $LANG` or `locale | head -1` | `ko_KR.UTF-8`, `ja_JP.UTF-8`, `es_ES.UTF-8`, `en_US.UTF-8` |

**Mapping rule** — look at **only the first two letters (the language code)** of the value:

| Detection result | Guidance language |
|---|---|
| `ko*` | Korean (KO block) |
| `ja*` | Japanese (JA block) |
| `es*` | Spanish (ES block) |
| `en*` and **every other language**, detection failure, output of `C`/`POSIX` | **English (EN block — default)** |

- When detecting Windows from Git Bash, `$LANG` may be Git Bash's own default (`en_US.UTF-8`), so **prefer PowerShell `Get-UICulture`**.
- Perform detection only once at startup and record the result. If the user explicitly requests a different language, that request takes priority over the detection result.
- Each guidance chunk in §3-2 through 3-6 has **four language blocks: EN / KO / JA / ES**. Output **only the one block for the detected language** and never show the others.
- The guidance title, body, encouragement messages, and the "what the user must do themselves" part of the final report all use the same language. Keep commands, tool names, and track names verbatim.

### 3-1. "Installation is running now" (a `🔧 [Install]` message, not guidance)

> **[EN]** The installation is running in the background. Duration varies by machine, so I'll update progress every 30 seconds and introduce the environment every 3 minutes.
>
> **[KO]** 설치는 백그라운드에서 진행 중입니다. 걸리는 시간은 PC마다 달라서, 30초마다 진행 상황을 알려 드리고 3분마다 이 환경을 어떻게 쓰는지 소개할게요.
>
> **[JA]** インストールはバックグラウンドで進行中です。かかる時間はマシンによって異なるため、30秒ごとに進捗をお知らせし、3分ごとにこの環境の使い方を紹介します。
>
> **[ES]** La instalación se está ejecutando en segundo plano. La duración varía según el equipo, así que informaré del progreso cada 30 segundos y presentaré el entorno cada 3 minutos.

---

### 3-2. What is being installed? (guidance 1/5)

**[EN — English]** *(default)*

> ## 📘 Setup Guide 1/5 — What is being installed?
>
> - This installation prepares your machine for the AI workshop in one pass.
> - Install order: OS update → base tools (Git; on Windows, PowerShell 7 + Windows Terminal) → runtimes (`bun`, `python3`, `uv`) → CLI tools (`gh`, `claude`, `codex`, `agy`, `gitleaks`) → desktop apps → verify.
> - Runtimes: `bun` is the primary JavaScript/TypeScript runtime and package manager of this workshop; `python3` + `uv` cover the Python side.
> - CLI tools: `gh` is the GitHub CLI; `claude` / `codex` / `agy` are AI coding agents from Anthropic, OpenAI, and Google; `gitleaks` scans commits for leaked secrets.
> - Most steps run automatically, but a few desktop apps must be installed by hand — you'll get the exact list for your OS at the end.
> - Nothing is hidden: the install log is kept under `~/workshop-setup-logs/` (Windows: `%USERPROFILE%\workshop-setup-logs\`).

**[KO — 한국어]**

> ## 📘 사용법 안내 1/5 — 무엇을 설치하나요?
>
> - 이 설치는 AI 워크샵에서 쓸 개발 환경을 한 번에 준비하는 과정입니다.
> - 설치 순서: OS 업데이트 → 기본 도구(Windows 는 Git, PowerShell 7 + Windows Terminal) → 런타임(`bun`, `python3`, `uv`) → CLI 도구(`gh`, `claude`, `codex`, `agy`, `gitleaks`) → 데스크톱 앱 → 검증.
> - 런타임: `bun` 은 이 워크샵의 기본 JavaScript/TypeScript 실행기이자 패키지 관리자이고, `python3` + `uv` 는 파이썬 쪽을 담당합니다.
> - CLI 도구: `gh` 는 GitHub CLI, `claude`/`codex`/`agy` 는 각각 Anthropic/OpenAI/Google 의 AI 코딩 에이전트, `gitleaks` 는 커밋에 비밀정보가 섞이지 않았는지 검사하는 도구입니다.
> - 대부분 자동 설치되지만 일부 데스크톱 앱은 사용자가 직접 설치해야 합니다 — 마지막에 사용 중인 OS에 해당하는 목록을 안내해 드립니다.
> - 설치 기록은 `~/workshop-setup-logs/` (Windows: `%USERPROFILE%\workshop-setup-logs\`)에 남습니다.

**[JA — 日本語]**

> ## 📘 セットアップ案内 1/5 — 何をインストールするの?
>
> - このインストールは、AI ワークショップ用の開発環境を一括で準備するものです。
> - インストール順序: OS アップデート → 基本ツール(Windows では Git、PowerShell 7 + Windows Terminal)→ ランタイム(`bun`、`python3`、`uv`)→ CLI ツール(`gh`、`claude`、`codex`、`agy`、`gitleaks`)→ デスクトップアプリ → 検証。
> - ランタイム: `bun` はこのワークショップの中心的な JavaScript/TypeScript 実行環境かつパッケージマネージャー、`python3` + `uv` は Python 側を担当します。
> - CLI ツール: `gh` は GitHub CLI、`claude`/`codex`/`agy` はそれぞれ Anthropic/OpenAI/Google の AI コーディングエージェント、`gitleaks` はコミットに機密情報(API キー・トークン)が混ざっていないかを検査するツールです。
> - ほとんどは自動でインストールされますが、一部のデスクトップアプリは手動インストールが必要です — 最後にお使いの OS 向けの一覧をお知らせします。
> - インストールのログは `~/workshop-setup-logs/`(Windows: `%USERPROFILE%\workshop-setup-logs\`)に保存されます。

**[ES — Español]**

> ## 📘 Guía de uso 1/5 — ¿Qué se instala?
>
> - Esta instalación prepara tu equipo para el taller de IA de una sola vez.
> - Orden de instalación: actualización del sistema → herramientas base (Git; en Windows, PowerShell 7 + Windows Terminal) → runtimes (`bun`, `python3`, `uv`) → herramientas CLI (`gh`, `claude`, `codex`, `agy`, `gitleaks`) → aplicaciones de escritorio → verificación.
> - Runtimes: `bun` es el runtime y gestor de paquetes principal de JavaScript/TypeScript del taller; `python3` + `uv` cubren el lado de Python.
> - Herramientas CLI: `gh` es el CLI de GitHub; `claude`, `codex` y `agy` son agentes de programación con IA de Anthropic, OpenAI y Google; `gitleaks` revisa que no se filtren secretos en los commits.
> - La mayoría se instala automáticamente, pero algunas aplicaciones de escritorio requieren instalación manual — al final verás la lista exacta para tu sistema operativo.
> - El registro de instalación se guarda en `~/workshop-setup-logs/` (Windows: `%USERPROFILE%\workshop-setup-logs\`).

---

### 3-3. What each tool does (guidance 2/5)

**[EN — English]** *(default)*

> ## 📘 Setup Guide 2/5 — What each tool does
>
> - `bun`: runs scripts and installs JS/TS dependencies. The verification script of this repo (`setup-common.ts`) also runs with bun.
> - `gh`: GitHub from the terminal — clone repos, create PRs, read issues. Needs `gh auth login` before first use.
> - `claude` / `codex` / `agy`: AI coding agents. You talk to them in the terminal; they read/write files and run commands. Each needs its own login and (for most features) an active subscription.
> - `gitleaks`: a secret scanner — catches API keys and tokens before they get committed to a repository.
> - `uv`: a fast Python package manager (virtual environments, pinned dependencies).
> - Optional extras: WezTerm (GPU-accelerated terminal) and Docker Desktop via the `--wezterm` / `--docker` flags; on Windows also `-WSL2`.

**[KO — 한국어]**

> ## 📘 사용법 안내 2/5 — 각 도구가 하는 일
>
> - `bun`: 스크립트 실행과 JS/TS 의존성 설치를 담당합니다. 이 저장소의 검증 스크립트(`setup-common.ts`)도 bun 으로 실행합니다.
> - `gh`: 터미널에서 GitHub 을 쓰는 도구입니다 — 저장소 클론, PR 생성, 이슈 확인. 처음 쓰기 전에 `gh auth login` 이 필요합니다.
> - `claude` / `codex` / `agy`: AI 코딩 에이전트입니다. 터미널에서 대화하면 파일을 읽고 쓰고 명령을 실행해 줍니다. 각각 로그인이 필요하고, 대부분의 기능에는 구독이 필요합니다.
> - `gitleaks`: 비밀정보 검사기입니다 — API 키와 토큰이 저장소에 커밋되기 전에 잡아 줍니다.
> - `uv`: 빠른 파이썬 패키지 관리자입니다 (가상환경, 의존성 버전 고정).
> - 선택 도구: WezTerm(GPU 가속 터미널)과 Docker Desktop 은 `--wezterm` / `--docker` 플래그로 설치하며, Windows 는 `-WSL2` 도 있습니다.

**[JA — 日本語]**

> ## 📘 セットアップ案内 2/5 — 各ツールの役割
>
> - `bun`: スクリプトの実行と JS/TS 依存関係のインストールを担います。このリポジトリの検証スクリプト(`setup-common.ts`)も bun で実行します。
> - `gh`: ターミナルから GitHub を使うツールです — リポジトリのクローン、PR 作成、イシュー確認。初回利用前に `gh auth login` が必要です。
> - `claude` / `codex` / `agy`: AI コーディングエージェントです。ターミナルで会話すると、ファイルの読み書きやコマンド実行を行ってくれます。それぞれログインが必要で、多くの機能にはサブスクリプションが必要です。
> - `gitleaks`: シークレットスキャナーです — API キーやトークンがリポジトリにコミットされる前に検出します。
> - `uv`: 高速な Python パッケージマネージャーです(仮想環境、依存関係のバージョン固定)。
> - オプション: WezTerm(GPU アクセラレーション端末)と Docker Desktop は `--wezterm` / `--docker` フラグで、Windows ではさらに `-WSL2` もインストールできます。

**[ES — Español]**

> ## 📘 Guía de uso 2/5 — Qué hace cada herramienta
>
> - `bun`: ejecuta scripts e instala dependencias de JS/TS. El script de verificación de este repositorio (`setup-common.ts`) también se ejecuta con bun.
> - `gh`: GitHub desde la terminal — clonar repositorios, crear PRs, consultar issues. Requiere `gh auth login` antes del primer uso.
> - `claude` / `codex` / `agy`: agentes de programación con IA. Les hablas en la terminal; leen y escriben archivos y ejecutan comandos. Cada uno requiere su propio inicio de sesión y (para la mayoría de las funciones) una suscripción activa.
> - `gitleaks`: un escáner de secretos — detecta claves de API y tokens antes de que se comprometan en un repositorio.
> - `uv`: un gestor de paquetes de Python rápido (entornos virtuales, dependencias fijadas).
> - Extras opcionales: WezTerm (terminal con aceleración GPU) y Docker Desktop mediante las opciones `--wezterm` / `--docker`; en Windows también `-WSL2`.

---

### 3-4. What I need to do after installation (guidance 3/5)

**[EN — English]** *(default)*

> ## 📘 Setup Guide 3/5 — What YOU do after the install
>
> - When the OS script finishes, **close the terminal and open a new one** so PATH changes take effect.
> - Logins — run these yourself; the agent never types passwords or tokens:
>   - `gh auth login`
>   - `claude login` (or run `claude` and use `/login`)
>   - `codex login`
> - Subscriptions (from the checklist): **Claude Pro/Max**, **ChatGPT Plus/Pro** (for Codex), **Gemini Advanced** — these are subscriptions, **not** API keys.
> - GitHub account: create one if you don't have it yet.
> - Some desktop apps (for example Claude Desktop on Linux, and the Mark viewer on every OS) must be installed manually — the final report lists exactly which ones apply to your OS.

**[KO — 한국어]**

> ## 📘 사용법 안내 3/5 — 설치 후 내가 해야 할 일
>
> - OS 설치 스크립트가 끝나면 **터미널을 닫고 새로 열어야** PATH 변경이 반영됩니다.
> - 로그인 — 아래 명령은 사용자가 직접 실행합니다. 에이전트는 비밀번호나 토큰을 대신 입력하지 않습니다:
>   - `gh auth login`
>   - `claude login` (또는 `claude` 실행 후 `/login`)
>   - `codex login`
> - 구독 확인 (체크리스트 항목): **Claude Pro/Max**, **ChatGPT Plus/Pro** (Codex용), **Gemini Advanced** — API 키가 아니라 **구독**입니다.
> - GitHub 계정: 아직 없다면 미리 만들어 둡니다.
> - 일부 데스크톱 앱(예: Linux 의 Claude Desktop, 모든 OS의 Mark 뷰어)은 수동 설치가 필요합니다 — 최종 보고에서 사용 중인 OS에 해당하는 항목만 정확히 안내해 드립니다.

**[JA — 日本語]**

> ## 📘 セットアップ案内 3/5 — インストール後に自分でやること
>
> - OS インストールスクリプトが終わったら、**ターミナルを閉じて新しく開き直して**ください。PATH の変更が反映されます。
> - ログイン — 以下は自分で実行します。エージェントがパスワードやトークンを代わりに入力することはありません:
>   - `gh auth login`
>   - `claude login`(または `claude` を起動して `/login`)
>   - `codex login`
> - サブスクリプション(チェックリストの項目): **Claude Pro/Max**、**ChatGPT Plus/Pro**(Codex 用)、**Gemini Advanced** — API キーではなく**サブスクリプション**です。
> - GitHub アカウント: まだ持っていなければ先に作っておきます。
> - 一部のデスクトップアプリ(例: Linux の Claude Desktop、全 OS 共通の Mark ビューア)は手動インストールが必要です — 最終レポートで、お使いの OS に該当する項目だけを正確にお知らせします。

**[ES — Español]**

> ## 📘 Guía de uso 3/5 — Qué tienes que hacer tú tras la instalación
>
> - Cuando termine el script del sistema operativo, **cierra la terminal y abre una nueva** para que los cambios de PATH surtan efecto.
> - Inicios de sesión — ejecútalos tú mismo; el agente nunca escribe contraseñas ni tokens:
>   - `gh auth login`
>   - `claude login` (o ejecuta `claude` y usa `/login`)
>   - `codex login`
> - Suscripciones (del checklist): **Claude Pro/Max**, **ChatGPT Plus/Pro** (para Codex), **Gemini Advanced** — son suscripciones, **no** claves de API.
> - Cuenta de GitHub: si aún no la tienes, créala de antemano.
> - Algunas aplicaciones de escritorio (por ejemplo, Claude Desktop en Linux y el visor Mark en todos los sistemas) requieren instalación manual — en el informe final verás exactamente cuáles aplican a tu sistema operativo.

---

### 3-5. How to verify (guidance 4/5)

**[EN — English]** *(default)*

> ## 📘 Setup Guide 4/5 — How to verify
>
> - The final check is one command: `bun setup-common.ts`.
> - It prints a verification table of every tool with ✅/❌, including minimum-version checks for `bun`/`uv`, a platform-aware Python check, and login status for `claude`/`codex`/`gh`.
> - **All required rows must show ✅** — that is the "ready for the workshop" signal.
> - A ❌ right after install is usually just a PATH problem: restart the terminal and run the check again.
> - Machine-readable output (for scripting): `bun setup-common.ts --json`.
> - Installation logs live in `~/workshop-setup-logs/` (Windows: `%USERPROFILE%\workshop-setup-logs\`) — attach them when asking for help.

**[KO — 한국어]**

> ## 📘 사용법 안내 4/5 — 검증하는 법
>
> - 최종 확인은 명령 하나입니다: `bun setup-common.ts`.
> - 모든 도구의 ✅/❌ 검증 표를 출력합니다. `bun`/`uv` 최소 버전 검사, OS별 파이썬 검사, `claude`/`codex`/`gh` 로그인 상태도 함께 표시됩니다.
> - **필수 행이 모두 ✅** 여야 워크샵 준비 완료입니다.
> - 설치 직후의 ❌ 는 대부분 PATH 문제입니다: 터미널을 다시 열고 검증을 한 번 더 실행해 보세요.
> - 스크립트용 기계 판독 출력: `bun setup-common.ts --json`.
> - 설치 로그는 `~/workshop-setup-logs/` (Windows: `%USERPROFILE%\workshop-setup-logs\`)에 있습니다 — 도움을 요청할 때 함께 첨부하세요.

**[JA — 日本語]**

> ## 📘 セットアップ案内 4/5 — 検証の方法
>
> - 最終確認はコマンド 1 つです: `bun setup-common.ts`。
> - すべてのツールの ✅/❌ 検証テーブルを表示します。`bun`/`uv` の最低バージョン検査、OS ごとの Python 検査、`claude`/`codex`/`gh` のログイン状態も一緒に表示されます。
> - **必須の行がすべて ✅** であることが「ワークショップ準備完了」の合図です。
> - インストール直後の ❌ は、たいてい PATH の問題です: ターミナルを開き直して、もう一度検証を実行してみてください。
> - スクリプト向けの機械可読出力: `bun setup-common.ts --json`。
> - インストールログは `~/workshop-setup-logs/`(Windows: `%USERPROFILE%\workshop-setup-logs\`)にあります — サポートを依頼するときは一緒に添付してください。

**[ES — Español]**

> ## 📘 Guía de uso 4/5 — Cómo verificar
>
> - La verificación final es un solo comando: `bun setup-common.ts`.
> - Imprime una tabla de verificación de todas las herramientas con ✅/❌, incluyendo comprobaciones de versión mínima de `bun`/`uv`, la comprobación de Python según la plataforma y el estado de sesión de `claude`/`codex`/`gh`.
> - **Todas las filas obligatorias deben mostrar ✅** — esa es la señal de "listo para el taller".
> - Un ❌ justo después de instalar suele ser solo un problema de PATH: reinicia la terminal y ejecuta la verificación de nuevo.
> - Salida legible por máquina (para scripts): `bun setup-common.ts --json`.
> - Los registros de instalación están en `~/workshop-setup-logs/` (Windows: `%USERPROFILE%\workshop-setup-logs\`) — adjúntalos si pides ayuda.

---

### 3-6. Tips and learning more (guidance 5/5)

**[EN — English]** *(default)*

> ## 📘 Setup Guide 5/5 — Tips and where to learn more
>
> - Already-installed tools are skipped automatically. Use `--force` (`-Force` on Windows) only when you explicitly want a reinstall.
> - For a reproducible environment, pin versions: `BUN_VERSION=1.4.5 UV_VERSION=0.4.20 PYTHON_VERSION=3.13 bash setup-mac.sh`.
> - Windows execution-policy error: launch with `powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1` (see SETUP.md for the Group Policy case).
> - Docs: `SETUP.md` (full guide), `SETUP_CHECKLIST.md` (pre-workshop checklist), `README.md` (repo overview). Korean translations: `SETUP_ko.md`, `SETUP_CHECKLIST_ko.md`.
> - First thing to try: open a new terminal, run `claude`, and ask it to run `bun setup-common.ts` once more.

**[KO — 한국어]**

> ## 📘 사용법 안내 5/5 — 팁과 더 알아보기
>
> - 이미 설치된 도구는 자동으로 건너뜁니다. `--force`(Windows 는 `-Force`)는 재설치를 명시적으로 원할 때만 붙이세요.
> - 재현 가능한 환경이 필요하면 버전을 고정합니다: `BUN_VERSION=1.4.5 UV_VERSION=0.4.20 PYTHON_VERSION=3.13 bash setup-mac.sh`.
> - Windows 실행 정책 오류: `powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1` 로 실행합니다 (그룹 정책 케이스는 SETUP.md 참조).
> - 문서: `SETUP.md` (상세 가이드), `SETUP_CHECKLIST.md` (워크샵 전 체크리스트), `README.md` (저장소 개요). 한국어 번역: `SETUP_ko.md`, `SETUP_CHECKLIST_ko.md`.
> - 첫 실습: 새 터미널을 열고 `claude` 를 실행한 뒤, `bun setup-common.ts` 를 다시 실행해 달라고 요청해 보세요.

**[JA — 日本語]**

> ## 📘 セットアップ案内 5/5 — ヒントと、さらに学ぶには
>
> - すでにインストール済みのツールは自動的にスキップされます。`--force`(Windows は `-Force`)は、再インストールを明示的に希望するときだけ付けてください。
> - 再現可能な環境が必要なら、バージョンを固定します: `BUN_VERSION=1.4.5 UV_VERSION=0.4.20 PYTHON_VERSION=3.13 bash setup-mac.sh`。
> - Windows の実行ポリシーエラー: `powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1` で起動します(グループポリシーの場合は SETUP.md を参照)。
> - ドキュメント: `SETUP.md`(詳細ガイド)、`SETUP_CHECKLIST.md`(ワークショップ前チェックリスト)、`README.md`(リポジトリ概要)。韓国語訳: `SETUP_ko.md`、`SETUP_CHECKLIST_ko.md`。
> - 最初に試すこと: 新しいターミナルを開いて `claude` を起動し、`bun setup-common.ts` をもう一度実行するよう頼んでみてください。

**[ES — Español]**

> ## 📘 Guía de uso 5/5 — Consejos y dónde aprender más
>
> - Las herramientas ya instaladas se omiten automáticamente. Usa `--force` (`-Force` en Windows) solo cuando quieras reinstalar de forma explícita.
> - Para un entorno reproducible, fija las versiones: `BUN_VERSION=1.4.5 UV_VERSION=0.4.20 PYTHON_VERSION=3.13 bash setup-mac.sh`.
> - Error de política de ejecución en Windows: lanza con `powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1` (el caso de directiva de grupo está en SETUP.md).
> - Documentación: `SETUP.md` (guía completa), `SETUP_CHECKLIST.md` (checklist previo al taller), `README.md` (resumen del repositorio). Traducciones al coreano: `SETUP_ko.md`, `SETUP_CHECKLIST_ko.md`.
> - Primera prueba: abre una terminal nueva, ejecuta `claude` y pídele que ejecute `bun setup-common.ts` una vez más.

---

### 3-7. After completion (last)

Wrap up the user guidance ("That's all the guidance" — in the §3-0 language), and in a separate message send the install result table (§7, `🔧 [Install]`) together with "next steps" (logins, subscriptions, manually-installed apps) in the §3-0 language.

---

## 4. Track A — Run the OS install script (`setup-os-script`)

> Because the scripts skip already-installed items, the agent must not arbitrarily install individual tools by hand. Supplement only the items the script failed on, using the install methods in `SETUP.md`.

### 4-1. Option flags (ask the user first)

- `--wezterm` (Windows `-WezTerm`): additionally install WezTerm, the GPU-accelerated terminal
- `--docker` (Windows `-Docker`): additionally install Docker Desktop
- `-WSL2` (Windows only): install WSL2 (**a restart is required** — tell the user in advance and get their consent)
- `--force` (Windows `-Force`): force reinstall even tools that are already installed (default is to skip)
- `--company <name>`: install organization-specific extra tools (only when the user belongs to an organization and instructs it)
- `--help`: print usage

The principle is to run the default install **with no flags**. Ask the user before running optional tools, and attach only the ones selected.

### 4-2. macOS

```bash
bash setup-mac.sh            # [+ option flags chosen by the user]
```

- If Homebrew is missing, the script installs Xcode CLT + Homebrew, which **requires entering the sudo password**. If the password cannot be entered in a non-interactive environment, report it as "the user must run this directly in a terminal" (do not force it through with `NONINTERACTIVE=1`).
- With the Docker Desktop option, **the user must launch the Docker Desktop app once** after installation for the service to start.

### 4-3. Linux (Ubuntu/Debian)

```bash
bash setup-linux.sh          # [+ option flags chosen by the user]
```

- At steps that need `sudo`, **the user enters the sudo password personally**. The agent neither asks for nor types the password.
- The Docker option uses the `get.docker.com` script (the script downloads it to a file, prints and logs the hash, then runs it).

### 4-4. Windows

Open **PowerShell as administrator** and run it. The script requires PowerShell 7+ and, if started under 5.1, automatically relaunches itself with `pwsh` (installing PowerShell 7 via winget first if needed).

```powershell
# Start with an execution-policy bypass (prevents the script from being blocked at all)
powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1 [-WezTerm] [-Docker] [-WSL2] [-Force] [-Company <name>]

# Or bypass the policy for this session only, then run:
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\setup-windows.ps1
```

- Using `-WSL2` **requires a restart** — tell the user before running and get their consent.
- After running, **open a new terminal** for PATH to take effect. To keep using the same session:
  ```powershell
  $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
  ```

### 4-5. Version pinning (only when the user asks)

> `PYTHON_VERSION` is macOS/Linux only (Windows is fixed to `winget Python.Python.3.13`). On macOS, Homebrew installs the latest uv, so `UV_VERSION` only prints a warning and is not pinned. On Linux, `PYTHON_VERSION` falls back to the distro `python3` with a warning when the requested version is not in the distro's repositories; on macOS the pinned formula installs as `python3.x`, so `python3` may still resolve to the Apple CLT interpreter. By default the scripts resolve bun's latest release tag up front and install that exact tag. Pins apply to fresh installs — an already-installed `bun` is upgraded to the latest regardless, and an already-installed `uv`/`python` is left as-is.

```bash
# macOS / Linux
BUN_VERSION=1.4.5 UV_VERSION=0.4.20 PYTHON_VERSION=3.13 bash setup-mac.sh
```

```powershell
# Windows
$env:BUN_VERSION = "1.4.5"; $env:UV_VERSION = "0.4.20"; powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1
```

### Verify (Track A)

- The script's own exit code must be 0, and its final summary must contain no fatal-failure (❌) items.
- Pass warnings (⚠️, e.g. items needing manual install) on to §5.
- Logs: `~/workshop-setup-logs/` (Windows: `%USERPROFILE%\workshop-setup-logs\`) — report failed items together with their log file path.

---

## 5. Track B — Manual items and user actions (`setup-manual-apps`)

Without changing the system, compile what the user must do themselves and deliver it in the §3-0 language (runs in parallel with Track A).

### 5-1. Items that need manual installation (per OS)

| Item | macOS | Linux | Windows |
|---|---|---|---|
| Claude Desktop | Automatic (`brew install --cask claude`) | ⚠️ Manual | Automatic (`winget Anthropic.Claude`) |
| Codex Desktop | Automatic (DMG, signature verified) | ⚠️ CLI only (no desktop app) | Automatic (Microsoft Store, `winget` msstore) |
| Antigravity Desktop | ⚠️ Manual | ⚠️ Manual | ⚠️ Manual |
| Mark (Markdown viewer) | ⚠️ Manual | ⚠️ Manual | ⚠️ Manual |

For ⚠️ items, point to the official download page and have **the user** install them. Codex Desktop on Linux has no desktop app, so tell the user "only the CLI is available".

### 5-2. Logins (user actions — the agent does not do them on their behalf)

```bash
gh auth login
claude login        # or run claude and then /login
codex login
```

The agent checks login status **read-only** (e.g. `gh auth status`). If not logged in, tell the user to run the commands above themselves (`claude auth status` may be replaced by `/login` in the interactive CLI).

### 5-3. Subscriptions/accounts (checklist items)

- Claude Pro/Max (claude), ChatGPT Plus/Pro (codex), Gemini Advanced (agy) — these require **subscriptions**, not API keys.
- If the user has no GitHub account, guide them through signing up.
- Korean public-API keys and the like are outside this repository's install scope (covered separately in the workshop projects).

---

## 6. Track C — Final verification (`setup-verify`)

### 6-1. Run the verification script

```bash
bun setup-common.ts          # human-readable verification table
bun setup-common.ts --json   # machine-readable output (for CI/scripts)
```

This table includes ✅/❌ for every tool, minimum-version checks for `bun`/`uv`, per-OS Python checks (macOS/Linux `python3`, Windows `python`), and login status for `claude`/`codex`/`gh`.

### 6-2. Verdict

- **All required rows ✅** → ready for the workshop. Proceed to the §7 final report.
- If there are ❌ items:
  1. Possible "PATH problem" → try re-verifying in a new terminal (including the `$env:Path` reload in §4-4).
  2. If still ❌, apply the matching fix from the **Troubleshooting** section of `SETUP.md` (see the §8 table).
  3. A login-status ❌ is classified as a user action (§5-2) and is not counted as an install failure.
- Offline/corporate network: if downloading the remote install scripts (bun, uv, Codex CLI, Antigravity CLI) is blocked, do not proceed with installation; report it as "user action needed (proxy setup or manual install)". Do not substitute an arbitrary mirror/fork.

---

## 7. Final report format (main agent to the user — in the §3-0 language)

```
## Install result — <OS>   *(Language used: <KO/JA/ES/EN> — §3-0 detection result)*
| Track | Result | Notes |
|---|---|---|
| A OS install script | ✅/⚠️/❌ | installed versions (bun, uv, python, gh, claude, codex, agy, gitleaks) |
| B Manual items | ✅/⚠️/❌ | list of apps needing manual install |
| C Verification | ✅/⚠️/❌ | bun setup-common.ts result |

### What you need to do yourself
- [ ] Open a new terminal to pick up PATH
- [ ] Log in to gh / claude / codex
- [ ] Confirm subscriptions: Claude Pro/Max, ChatGPT Plus/Pro, Gemini Advanced
- [ ] (per OS) manually-installed apps: <⚠️ items such as Antigravity Desktop, Mark>
- [ ] (Windows) restart if you installed `-WSL2`
- [ ] (failed items) <cause and next step + log path>

### Getting started
bun setup-common.ts   →   if everything is ✅, run claude / codex / agy in a new terminal
```

---

## 8. Troubleshooting (agent reference — keep in sync with `SETUP.md` Troubleshooting)

| Symptom | Action |
|---|---|
| `bun: command not found` after install | Restart the terminal. macOS/Linux: `export PATH="$HOME/.bun/bin:$PATH"`. Windows: bun is registered in the User PATH automatically, so check in a new terminal |
| `claude: command not found` (after bun install) | The script automatically retries with an npm fallback. If it persists, check `bun pm ls -g` and add the bin directory to PATH |
| `codex: command not found` | The script installs a standalone binary. Restart the terminal to pick up `~/.local/bin` (Linux) or the winget links dir (Windows) |
| `agy: command not found` | The Antigravity CLI installs to `~/.local/bin` or `/usr/local/bin`. `source ~/.bashrc` or restart the terminal |
| Windows: `execution of scripts is disabled` | Start with `powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1`. Permanent per-user setting: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`. If it is **Group Policy (MachinePolicy/UserPolicy)**, it cannot be changed locally — contact IT. A downloaded `.ps1` may need `Unblock-File` |
| Windows: ran without administrator privileges | The script warns and continues, but some installs (winget, WSL2) may fail. Re-running in an administrator PowerShell is recommended |
| mac/linux: cannot enter the sudo password | Report that step as "the user must run it directly in a terminal" and proceed with the rest. Do not force it through with `NONINTERACTIVE=1` |
| Unsupported Linux distribution (Fedora/RHEL, Arch, etc.) | Do not run the script; guide a manual install based on the install-method table in `SETUP.md` (no arbitrary substitute installs) |
| Insufficient privileges | Hand only that command to the user and proceed with the rest |
| Checking logs | `~/workshop-setup-logs/` (Windows: `%USERPROFILE%\workshop-setup-logs\`) |

---

## 9. Maintaining this document

- Install commands and flags use `SETUP.md` as the **source of truth**. Do not duplicate versions into this document (versions in tables are example values at the time of writing).
- If a flag in `SETUP.md` changes, update §4-1, §4-2 to 4-5, §6, and §8 of this document **together**. `check-docs-sync.sh` and CI (docs-sync in `.github/workflows/test-setup.yml`) check only the sync of `SETUP.md`/`SETUP_ko.md`; this document is not checked.
- If an install target tool is added, add one line each to the §0 tool list, the §1-3 scan list, and the §5-1 manual-install table.
- **To change the set of guidance languages**: update the mapping table in §3-0 and the language blocks in §3-2 to 3-6 together. Keeping English as the default (fallback) is a rule of this document.
