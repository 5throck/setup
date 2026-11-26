# install.md — Workshop Setup 자동 설치 가이드 (AI 에이전트용)

> **이 파일을 읽는 AI(Claude Code / Codex / Gemini CLI / Antigravity 등)에게**
> 이 문서는 사용자가 "install.md 를 읽고 설치해줘" 라고 요청했을 때 따라야 할 **실행 절차서**입니다.
> 위에서 아래로 순서대로 수행하고, 각 단계의 **검증(Verify)** 이 통과해야 다음 단계로 넘어가세요.
> 사용자에게 보여줄 **안내 언어는 §3-0 에 따라 설치되는 시스템의 언어 설정에서 판별**합니다.
> 지원 언어는 **영어 / 한국어 / 일본어 / 스페인어**이며, 해당되는 언어가 없거나 판별에 실패하면 **영어**로 안내합니다.

대상 저장소 (이 폴더 = 설치 스크립트 프로젝트):

| 구성 요소 | 용도 |
|---|---|
| `setup-mac.sh` / `setup-linux.sh` | macOS / Linux (Ubuntu·Debian) 자동 설치 스크립트 |
| `setup-windows.ps1` | Windows 자동 설치 스크립트 (PowerShell 7+ 필요, 5.1 이면 자동 재실행) |
| `setup-lib.sh` | mac/linux 공용 헬퍼 (진행 UI, 사전 점검, 로그, `--force`, 정리) |
| `setup-common.ts` | 설치 후 교차 플랫폼 검증 스크립트 (`bun setup-common.ts`) |
| `SETUP.md` / `SETUP_ko.md` | 상세 설치 안내 (플래그, 문제 해결) |
| `SETUP_CHECKLIST.md` / `SETUP_CHECKLIST_ko.md` | 워크샵 전 준비물 체크리스트 (계정·구독) |

설치 대상 도구: 기본 도구(Git, PowerShell 7, Windows Terminal), 런타임(`bun`, `python3`, `uv`), CLI(`gh`, `claude`, `codex`, `agy`, `gitleaks`), 데스크톱 앱(Chrome, Claude/Codex/Antigravity Desktop, Mark). 옵션으로 `--wezterm`, `--docker`, Windows `-WSL2`, 조직용 `--company <name>`.

> 이 문서의 명령·플래그는 `SETUP.md` 와 동기화가 유지되어야 합니다. `SETUP.md` 의 플래그가 바뀌면 이 문서의 해당 부분도 함께 갱신하세요 (`check-docs-sync.sh` 가 SETUP 문서의 동기화는 검사하지만, 이 문서는 수동 유지보수 대상입니다).

---

## 0. 실행 원칙 (반드시 지킬 것)

1. **설치는 서브 에이전트에 위임**합니다 (아래 §2). 메인 에이전트는 사용자와의 대화·안내·진행 보고만 담당합니다.
2. **설치가 오래 걸리므로** 서브 에이전트가 일하는 동안 메인 에이전트는 §3 의 **사용자 안내**를 전달합니다. 서브 에이전트 완료를 멍하니 기다리지 마세요.
3. **안내 언어는 §3-0 으로 한 번 판별**하고, 사용자에게 나가는 모든 메시지(안내·상태바 제목·보고)에 그 언어를 적용합니다. 서브 에이전트의 보고 언어는 자유이지만, 메인 에이전트가 사용자에게 전달할 때는 판별된 언어로 옮깁니다.
4. **비밀값 금지**: 비밀번호, API 키, 토큰을 대신 입력하거나 추측하지 마세요. 로그인(`gh auth login`, `claude login`, `codex login`)과 구독 확인은 **사용자가 직접** 합니다. sudo/관리자 비밀번호 입력 창이 뜨면 사용자가 직접 입력하도록 안내합니다.
5. **관리자/sudo 권한이 필요한 단계**는 실행 전에 사용자에게 알리고 확인을 받으세요. 권한이 없으면 해당 단계를 건너뛰고 보고합니다.
6. **멱등성**: 이미 설치된 도구는 건너뜁니다(`command -v` / `Get-Command` 로 확인). 스크립트 자체도 설치된 항목을 스킵하지만, 강제 재설치(`--force`/`-Force`)는 사용자가 요청할 때만 붙입니다. 재실행해도 안전해야 합니다.
7. **`curl | bash` / `irm | iex` 금지**: 설치 스크립트는 임시 파일로 내려받아 SHA-256 을 출력·기록한 뒤 실행합니다 (본 저장소의 각 스크립트도 이 방식을 따릅니다. 기대 해시와 자동 비교는 하지 않으므로 감사용 기록입니다). 이 문서의 명령을 임의로 파이프 형태로 바꾸지 마세요.
8. **버전 핀은 사용자가 요청할 때만**: 기본은 최신 릴리스를 설치합니다. 재현 가능한 환경이 필요하다고 사용자가 밝히면 `BUN_VERSION` / `UV_VERSION` / `PYTHON_VERSION` 환경변수를 사용합니다 (§4-5). `PYTHON_VERSION` 은 macOS/Linux 전용이며(Windows 는 Python 3.13 고정 설치), macOS 의 `UV_VERSION` 은 Homebrew 가 최신 uv 를 설치하므로 완전한 핀이 아닙니다.
9. **드라이런 요청 시 §0-1 을 최우선**으로 따르며 어떤 것도 변경하지 않습니다.
10. 실패 시 로그를 남기고 다음 독립 작업은 계속 진행한 뒤, 마지막에 실패 목록을 한 번에 보고합니다.

로그 위치: `~/workshop-setup-logs/` (Windows: `%USERPROFILE%\workshop-setup-logs\`)

---

## 0-1. 드라이런(Dry-run) 모드 — 설치하지 않고 진행 과정만 미리 보기

사용자가 **"드라이런", "dry-run", "시뮬레이션", "설치하지 말고 어떻게 되는지만 보여줘"** 등으로 요청하면 이 모드로 진행합니다. 요청이 없으면 일반 설치 모드입니다. 모호하면(예: "한번 해봐줘") 어느 모드인지 사용자에게 물어보세요.

> 이 저장소의 스크립트에는 문서화된 드라이런 플래그가 없습니다 (`SETUP.md` 기준). 드라이런은 **에이전트가 절차 수준에서만 시연**합니다.

### 드라이런에서 **하는 것**

- §1 사전 점검의 **읽기 전용** 명령 (OS 판별, `--version`/`command -v`/`Get-Command`, 디스크 여부, `SETUP_CHECKLIST.md` 확인)
- §3-0 안내 언어 판별 (읽기 전용 — 실제로 안내도 동일하게 진행)
- 각 트랙에서 **실제로 실행했을 명령 목록**을 현재 OS·스캔 결과에 맞춰 출력 (이미 설치된 것은 `SKIP`, 없는 것은 `WOULD RUN`)
- §3 사용자 안내를 **실제 설치와 동일하게** 진행 (안내 흐름을 체험하게 하는 것이 목적)
- §7 형식의 **예상 결과 리포트** (모든 상태에 `[DRY-RUN]` 표시)

### 드라이런에서 **절대 하지 않는 것**

- 설치/업데이트/삭제 명령 (`brew install`, `apt`, `winget install`, `bun install -g`, `wsl --install` 등)
- OS 설치 스크립트 실행 (`bash setup-mac.sh`, `.\setup-windows.ps1` 등 — 실행 자체가 시스템을 변경함)
- 원격 스크립트 다운로드 (bun/uv/Codex/Antigravity 설치 스크립트 포함 — 내려받기만 해도 하지 않음)
- 관리자/sudo 권한 요청, 로그인 명령
- 로그 폴더·파일 생성 (`~/workshop-setup-logs/` 생성 포함)

> 판단이 애매한 명령은 실행하지 말고 "실행 예정"으로만 표기하세요. 드라이런이 시스템에 남기는 흔적은 **0** 이어야 합니다.

### 서브 에이전트 프롬프트에 추가할 문구

```
모드: DRY-RUN. 읽기 전용 도구만 사용하고, 시스템/파일을 변경하는 명령은 실행하지 말 것.
각 단계를 "[DRY-RUN] SKIP(이미 설치: <버전>)" 또는 "[DRY-RUN] WOULD RUN: <명령>" 형식으로 보고.
예상 소요 시간과 사용자가 해야 할 일(권한, 로그인, 구독)도 함께 보고.
```

### 출력 형식

트랙별로 다음 형태를 사용합니다.

```
[DRY-RUN] 트랙 A — OS 설치 스크립트 (예상 10~30분)
  SKIP         git 2.45.0 (이미 설치)
  WOULD RUN    bash setup-mac.sh            # 관리자/sudo 권한 필요
  USER ACTION  새 터미널 열기 (PATH 반영)
```

마지막에 요약합니다.

```
## [DRY-RUN] 예상 결과 — <OS>
설치 예정 N개 / 건너뜀 M개 / 수동 설치 K개 / 사용자 작업 J개 / 예상 총 소요 시간 약 XX분
변경된 것: 없음
실제로 설치하려면: "install.md 를 읽고 설치해줘" (드라이런 언급 없이)
```

예상 소요 시간은 대략치이며(네트워크에 따라 크게 달라짐) 보증하지 않는다는 점을 한 줄 덧붙이세요.

---

## 0-2. 출력 구분 규칙과 업데이트 주기 (상태 30초 / 안내 3분)

설치 시간은 PC(네트워크, 사양, 이미 설치된 도구)마다 크게 다릅니다. 그래서 **예상 시간을 약속하지 않고**, **30초마다 상태를, 3분마다 사용자 안내를 업데이트**하는 방식으로 진행합니다. 이 시간 동안 **사용자에게 안내를 전달하는 것이 가장 큰 목적**이므로 화면의 주인공은 사용자 안내이고, 설치 진행은 작은 상태바로만 보여 줍니다.

### 업데이트 주기 — 상태는 30초, 사용자 안내는 3분

| 무엇 | 주기 | 형식 |
|---|---|---|
| **설치 상태 업데이트** | **30초마다** | 상태바 **한 줄만** (코드 블록, 본문 없음) |
| **사용자 안내** | **3분마다** 1토막 (§3 순서대로) | 상태바 + `## 📘` 본문 |
| **즉시 알림** | 상태 변화 시 즉시 | `🔧 [설치]` 한 줄 |

1. 설치를 시작할 때 **시작 시각을 기록**합니다 (`date +%s` / `Get-Date`). 모든 시간은 이 기록 기준의 **경과 시간**입니다.
2. **30초마다 아래 "30초 점검 체크리스트"를 수행한 뒤** 설치 상태바 한 줄을 보냅니다. 서브 에이전트의 상태(`⏳/✅/⚠️/❌`)를 확인해 갱신하고, 변화가 없어도 경과 시간은 올라갑니다. 이 메시지에는 **안내 본문을 붙이지 않습니다**(짧게 유지).
3. **3분(= 상태 업데이트 6회)마다** 상태바 위에 사용자 안내 1토막을 함께 보냅니다. 사용자가 안내를 읽을 시간이 필요하므로 안내를 30초마다 보내지 않습니다.
4. 업데이트 사이에는 서브 에이전트를 백그라운드로 두고 **대기**합니다.
   - Claude Code: `sleep 30` 으로 대기 → 서브 에이전트 상태 확인 → 상태바 출력을 반복합니다. 완료 알림이 오면 대기를 끊고 즉시 알립니다.
   - 다른 도구: 가능한 대기/타이머 수단을 쓰고, 없으면 확인 가능한 시점마다 경과 시간을 계산해 30초가 넘었으면 상태바를 출력합니다.
5. **즉시 알림**: 트랙 완료, 경고, 실패, 사용자 작업 필요(`🙋`)는 다음 30초를 기다리지 않고 바로 알립니다.
6. **예상 남은 시간은 쓰지 않습니다.** 경과 시간과 완료/진행 중 트랙만 보여 줍니다. 시간 표현이 필요하면 "아직 진행 중"이라고만 말합니다. (드라이런 리포트의 대략적 예상 시간만 예외이며, 그때도 "PC마다 다름"을 덧붙입니다.)
7. 안내할 토막이 모두 소진됐는데 설치가 계속 중이면 사용자 안내 대신 **상태바만** 30초마다 보내고, 3분마다 한 줄 격려("아직 진행 중입니다" — §3-0 의 언어로)를 덧붙입니다. 같은 안내를 반복하지 않습니다.
8. 설치가 안내보다 먼저 끝나면 남은 안내는 핵심 3줄로 줄이고, 설치 결과 표(§7)를 보냅니다.
9. 한 트랙이 **15분 이상** 진행 중이면 "오래 걸리고 있어요 — 네트워크 상태 확인이 필요할 수 있어요" (§3-0 의 언어로) 라고 한 번 알리고, 로그 경로(`~/workshop-setup-logs/`)를 안내합니다. 임의로 중단하지는 않습니다.
10. 사용자가 "안내 그만"/"건너뛰기"라고 하면 사용자 안내만 중단하고 30초 상태바는 계속합니다. 상태 업데이트도 끄라고 하면 완료/실패 알림만 보냅니다.

### 30초 점검 체크리스트 — 다음 단계로 안 넘어가는 문제 방지

서브 에이전트가 끝났는데도 다음 트랙이 시작되지 않는 일이 있었습니다. 완료 알림이 오지 않거나 놓칠 수 있으므로, **알림을 기다리지 말고 30초 상태 체크마다 아래를 직접 확인**하세요. 상태바를 출력하기 **전에** 먼저 수행합니다.

| # | 점검 | 조치 |
|---|---|---|
| 1 | 각 서브 에이전트의 **실제 상태**를 직접 조회 (완료/실행 중/응답 없음). 알림 수신 여부와 무관 | 완료인데 결과를 아직 읽지 않았다면 **지금 읽고** 트랙 상태를 갱신 |
| 2 | **선행 조건이 충족됐는데 시작 안 된 트랙**이 있는가? (A 완료 → C 시작) | **즉시 시작**하고 `🔧 [설치] ✅ 트랙 X 완료 → 트랙 Y 시작` 알림. 다음 30초를 기다리지 않음 |
| 3 | 모든 트랙이 끝났는데 **최종 보고(§7)가 아직 안 나갔는가?** | 즉시 §7 설치 결과 표 전송 후 상태 체크 종료 |
| 4 | 트랙이 `⏳` 인데 서브 에이전트가 이미 **종료/실패/응답 없음** 상태인가? | `⏳` 로 두지 말고 `❌`(또는 `⚠️`)로 갱신하고 사유를 알림. 독립 트랙은 계속 진행 |
| 5 | 같은 `⏳` 가 **연속 20회(10분) 이상** 변화 없음 + 서브 에이전트 출력도 없음 | "멈춘 것 같아요" 알림 + 로그 경로 안내 + 사용자에게 재시도/건너뛰기 선택 요청 (임의 중단 금지) |
| 6 | 실패한 트랙에 **의존하는 트랙**이 있는가? (예: A 실패 → C 진행 불가) | 대기 상태(`·`)로 영원히 두지 말고 "선행 실패로 보류" 를 알리고 사용자 선택 요청 |

핵심 원칙: **"완료 알림이 와야 다음 단계"가 아니라 "상태 체크 때마다 다음 단계가 시작됐는지 확인"** 입니다. 서브 에이전트를 쓸 수 없어 순차 실행하는 경우에도, 한 트랙이 끝나는 즉시 같은 턴에서 다음 트랙을 시작하세요.

상태바에 점검 결과가 반영되어야 합니다. 예: 트랙 시작을 놓쳤다가 점검에서 발견해 시작했다면 상태바는 `C ⏳` 로 바뀌고, 앞서 `🔧 [설치]` 시작 알림이 나가야 합니다.

### 메시지 종류

| 종류 | 형식 | 역할 |
|---|---|---|
| **사용자 안내** (주) | `## 📘 <안내 제목> n/5 — <제목>` 으로 시작하는 일반 마크다운 본문 (제목, 목록, 표, 예시 명령) | 사용자가 읽는 본문. 충분히 자세하게 (10~20줄) |
| **설치 상태바** (보조) | 코드 블록 한 줄. 30초 상태 업데이트에서는 단독, 사용자 안내 메시지에서는 **맨 위** | 설치 진행 상황 |
| **설치 이벤트** | `🔧 [설치] ✅/⚠️/❌ ...` 한 줄 | 상태 변화 즉시 알림 |
| **사용자 작업 필요** | `**🙋 ...**` 굵게, 단독 메시지 | 로그인/구독/권한/클릭 요청 |
| **드라이런** | 설치 상태바와 설치 이벤트 앞에 `🧪` | 예: `🧪 🔧 설치 진행 ...` (드라이런은 실제 시간이 걸리지 않으므로 3분 대기 없이 순서만 시연) |

> 사용자 안내의 본문·제목은 §3-0 의 언어로 씁니다. 상태바 기호(`✅ ⏳ · ⚠️ ❌`), 트랙 이름(A/B/C), 명령어·도구명(`bun`, `setup-mac.sh` 등)은 언어와 무관하게 그대로 유지합니다.

### 설치 상태바 형식 (30초마다, 안내 메시지에서는 맨 위 1줄)

````
```
🔧 설치 진행  A ✅ │ B ✅ │ C ⏳      경과 06:00
```
````

- 상태 기호: `✅` 완료, `⏳` 진행 중, `·` 대기, `⚠️` 경고, `❌` 실패.
- 상태바 **밖**(본문)에는 설치 상태를 쓰지 않고, 상태바에는 안내 설명을 쓰지 않습니다.

### 그 밖의 규칙

1. **본문은 읽을 만한 분량**(10~20줄, 표/예시 명령 포함)으로 씁니다. 짧은 한 줄 팁으로 때우지 마세요.
2. 시작 알림: "설치가 진행되는 동안 30초마다 진행 상태를, 3분마다 이 환경을 어떻게 쓰는지 안내할게요." (§3-0 의 언어로). 종료 알림: "안내는 여기까지입니다".
3. 서브 에이전트의 원문 로그는 안내 메시지에 붙이지 않고 `🔧 [설치]` 한 줄로 요약합니다.
4. 두 종류(설치 이벤트와 사용자 안내)를 한 메시지에 섞지 않습니다. 같은 메시지라면 이벤트 줄을 맨 위에, 상태바, 본문 순서로 둡니다.

출력 예시:

````
🔧 [설치] 트랙 A (OS 설치 스크립트) 시작 - 백그라운드 진행 중
설치가 진행되는 동안 30초마다 진행 상태를, 3분마다 이 환경을 어떻게 쓰는지 안내할게요.

```
🔧 설치 진행  A ⏳ │ B ✅ │ C ·      경과 00:30
```

(30초 후)

```
🔧 설치 진행  A ⏳ │ B ✅ │ C ·      경과 01:00
```

...(30초 간격으로 상태바만)...

(3분 경과: 상태바 + 사용자 안내)

```
🔧 설치 진행  A ⏳ │ B ✅ │ C ·      경과 03:00
```

## 📘 사용법 안내 1/5 — 무엇을 설치하나요?
...

🔧 [설치] ✅ 트랙 A 완료 (bun 1.1.34, uv 0.4.20, gh 2.x) → 트랙 C 시작   ← 즉시 알림

```
🔧 설치 진행  A ✅ │ B ✅ │ C ⏳      경과 03:40
```
````

---

## 1. 사전 점검 (메인 에이전트가 직접, 1분 이내)

### 1-1. OS 판별

| 판별 | 방법 | 사용할 절차 |
|---|---|---|
| Windows | `$env:OS -eq 'Windows_NT'` 또는 `uname` 이 `MINGW*/MSYS*/CYGWIN*` | **Windows 절차** (§4-W) |
| macOS | `uname -s` = `Darwin` | **macOS 절차** (§4-M) |
| Linux (Debian/Ubuntu) | `uname -s` = `Linux` 이고 `/etc/os-release` 의 `ID`/`ID_LIKE` 에 `debian`/`ubuntu` | **Linux 절차** (§4-L) |
| Linux (Fedora/RHEL, Arch 등) | `/etc/os-release` 의 `ID`/`ID_LIKE` | **지원 범위 밖** — 수동 설치 안내로 대체하고 사용자에게 보고 |
| WSL | `/proc/version` 에 `microsoft` 포함 | **Linux 절차** (Windows 쪽 도구와 섞지 말 것. 데스크톱 앱은 Windows 쪽 안내) |

Windows 에서 Git Bash 로 실행 중이어도 설치 명령은 **PowerShell/winget** 기준(`setup-windows.ps1`)으로 수행합니다.

### 1-2. 점검 항목

- 인터넷 연결 (`https://github.com`, `https://bun.sh` 접근)
- 여유 디스크 **5 GB 이상**
- 관리자(Windows)/sudo(macOS·Linux) 사용 가능 여부 — 없으면 미리 알리고 확인을 받습니다
- **`SETUP_CHECKLIST.md` 완료 여부**를 사용자에게 묻습니다: Claude Pro/Max, ChatGPT Plus/Pro (Codex용), Gemini Advanced 구독, GitHub 계정. 완료되지 않았어도 설치는 진행하되 §5 에서 안내를 다시 전달합니다

### 1-3. 현재 상태 스캔

아래 도구를 모두 조회해 `설치됨/없음` 표를 만듭니다 (서브 에이전트에게 "이미 설치된 것은 건너뛰기" 근거로 전달).

```
bun, git, gh, python(3), uv, claude, codex, agy, gitleaks, pwsh
```

- Windows 는 `python`(또는 `py -3`)과 `pwsh`, macOS/Linux 는 `python3`.
- 위 표를 사용자에게 (§3-0 의 언어로) 한 번 요약해 보여주고 진행 여부를 확인합니다.

---

## 2. 서브 에이전트 실행 계획

설치 작업을 **트랙**으로 나누어 서브 에이전트에게 맡깁니다.
각 서브 에이전트 프롬프트에는 §1 의 OS 판별 결과, 도구 스캔 표, 그리고 해당 트랙 절차(§4~§6)만 전달합니다.

| 트랙 | 서브 에이전트 | 내용 | 선행 조건 |
|---|---|---|---|
| **A. OS 설치 스크립트** | `setup-os-script` | §4 OS별 설치 스크립트 실행 | 없음 |
| **B. 수동 항목 안내** | `setup-manual-apps` | §5 수동 설치 필요 항목 목록 정리 + 사용자 작업 안내 준비 | 없음 (A와 **병렬** 가능 — 시스템을 변경하지 않음) |
| **C. 검증** | `setup-verify` | §6 `bun setup-common.ts` 실행 및 결과 정리 | A 완료 |

실행 순서: **A ∥ B 병렬 → C**

> 트랙 전환은 서브 에이전트의 완료 알림에만 의존하지 마세요. §0-2 의 **30초 점검 체크리스트**로 매번 선행 조건 충족 여부를 직접 확인해 다음 트랙을 시작합니다.

### 도구별 서브 에이전트 호출 방법

- **Claude Code**: `Agent` 도구로 위 서브 에이전트를 `run_in_background: true` 로 생성합니다. A 와 B 는 **한 메시지에서 동시에** 호출합니다. 완료 알림이 오면 결과를 읽고 다음 트랙을 시작합니다.
- **Codex**: 서브 에이전트(spawn) 기능을 사용해 같은 분할로 실행합니다. 기능이 없으면 "트랙 단위로 순차 실행"하되 §3 안내는 각 트랙 사이에 계속합니다.
- **Gemini CLI / Antigravity**: 서브 에이전트 기능이 있으면 동일하게 사용하고, 없으면 트랙 단위 순차 실행(백그라운드 셸 `&`/`Start-Process`)으로 대체합니다.
- 서브 에이전트 프롬프트 템플릿:

  ```
  역할: Workshop Setup 설치 트랙 <A|B|C> 담당.
  환경: OS=<...>, 패키지 관리자=<winget|brew|apt|...>, 사전 스캔 결과=<표>
  할 일: install.md 의 <§N> 절차를 순서대로 수행.
  모드: <INSTALL|DRY-RUN>  (DRY-RUN 이면 §0-1 규칙을 따를 것)
  규칙: 이미 설치된 것은 건너뜀. 비밀값/로그인/구독은 건드리지 말고 "사용자 작업 필요"로 보고.
        관리자/sudo 권한이 필요하면 실행하지 말고 필요한 명령만 보고.
  보고 형식: 단계별 ✅/⚠️/❌ + 설치된 버전 + 사용자가 해야 할 일 목록. (500단어 이내)
  ```

---

## 3. 대기 시간 동안의 사용자 안내 (메인 에이전트)

서브 에이전트를 시작하자마자 사용자에게 아래 안내를 **짧게, 단계별로** 전달합니다. 모든 안내는 **§0-2 형식**(맨 위 설치 상태바 + `## 📘 ... n/5 — 제목` 본문)으로 출력합니다. 3-1 은 안내가 아니라 시작 알림이고, 실제 안내는 3-2~3-6 의 5토막(1/5~5/5)이며 **3분마다 한 토막씩** 순서대로 전달합니다. **이 시간의 주목적은 사용자 안내**이므로 아래 내용을 요약하지 말고 읽을 만한 분량으로 전달합니다.
한 번에 길게 쏟지 말고, 트랙 완료 알림 사이사이에 한 토막씩 전달하세요.
원문 자료: [SETUP.md](SETUP.md) · [SETUP_CHECKLIST.md](SETUP_CHECKLIST.md) · [README.md](README.md) (한국어 번역: `SETUP_ko.md`, `SETUP_CHECKLIST_ko.md`) — 사용자가 더 읽고 싶어 하면 링크를 제공

### 3-0. 안내 언어 판별 (이 문서 고유 규칙 — 반드시 먼저 수행)

설치 시작 전 **한 번만**, 설치되는 시스템의 언어 설정을 확인하고 그 결과를 모든 사용자 안내에 적용합니다.

**판별 방법 (OS별):**

| OS | 확인 명령 | 예시 출력 |
|---|---|---|
| Windows | PowerShell: `powershell -NoProfile -Command "(Get-UICulture).Name"` (실패 시 `Get-WinSystemLocale`) | `ko-KR`, `ja-JP`, `es-ES`, `en-US` |
| macOS | `defaults read -g AppleLocale` (실패 시 `defaults read -g AppleLanguages \| head -1`) | `ko_KR`, `ja_JP`, `es_ES`, `en_US` |
| Linux | `echo $LANG` 또는 `locale | head -1` | `ko_KR.UTF-8`, `ja_JP.UTF-8`, `es_ES.UTF-8`, `en_US.UTF-8` |

**매핑 규칙** — 값의 **앞 두 글자(언어 코드)만** 본다:

| 판별 결과 | 안내 언어 |
|---|---|
| `ko*` | 한국어 (KO 블록) |
| `ja*` | 일본어 (JA 블록) |
| `es*` | 스페인어 (ES 블록) |
| `en*` 및 **그 외 모든 언어**, 판별 실패, 출력이 `C`/`POSIX` | **영어 (EN 블록 — 기본값)** |

- Git Bash 에서 Windows 를 판별할 때 `$LANG` 는 Git Bash 자체 기본값(`en_US.UTF-8`)일 수 있으므로 **PowerShell `Get-UICulture` 를 우선** 사용하세요.
- 판별은 시작 시 한 번만 수행하고 결과를 기록합니다. 사용자가 명시적으로 다른 언어를 요청하면 그 요청이 판별 결과보다 우선합니다.
- §3-2~3-6 의 각 안내 토막에는 **EN / KO / JA / ES 4개 언어 블록**이 있습니다. 그중 **판별된 언어 블록 하나만** 출력하고 나머지는 절대 보여주지 마세요.
- 안내 제목, 본문, 격려 메시지, 최종 보고의 "사용자가 직접 해야 할 일" 모두 같은 언어를 사용합니다. 명령어·도구명·트랙 이름은 원문 그대로 유지합니다.

### 3-1. "지금 설치 중입니다" (`🔧 [설치]` 메시지, 안내 아님)

> **[EN]** The installation is running in the background. Duration varies by machine, so I'll update progress every 30 seconds and introduce the environment every 3 minutes.
>
> **[KO]** 설치는 백그라운드에서 진행 중입니다. 걸리는 시간은 PC마다 달라서, 30초마다 진행 상황을 알려 드리고 3분마다 이 환경을 어떻게 쓰는지 소개할게요.
>
> **[JA]** インストールはバックグラウンドで進行中です。かかる時間はマシンによって異なるため、30秒ごとに進捗をお知らせし、3分ごとにこの環境の使い方を紹介します。
>
> **[ES]** La instalación se está ejecutando en segundo plano. La duración varía según el equipo, así que informaré del progreso cada 30 segundos y presentaré el entorno cada 3 minutos.

---

### 3-2. 무엇을 설치하나요? (안내 1/5)

**[EN — English]** *(기본값)*

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

### 3-3. 각 도구가 하는 일 (안내 2/5)

**[EN — English]** *(기본값)*

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

### 3-4. 설치 후 내가 해야 할 일 (안내 3/5)

**[EN — English]** *(기본값)*

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

### 3-5. 검증하는 법 (안내 4/5)

**[EN — English]** *(기본값)*

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

### 3-6. 팁과 더 알아보기 (안내 5/5)

**[EN — English]** *(기본값)*

> ## 📘 Setup Guide 5/5 — Tips and where to learn more
>
> - Already-installed tools are skipped automatically. Use `--force` (`-Force` on Windows) only when you explicitly want a reinstall.
> - For a reproducible environment, pin versions: `BUN_VERSION=1.1.34 UV_VERSION=0.4.20 PYTHON_VERSION=3.13 bash setup-mac.sh`.
> - Windows execution-policy error: launch with `powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1` (see SETUP.md for the Group Policy case).
> - Docs: `SETUP.md` (full guide), `SETUP_CHECKLIST.md` (pre-workshop checklist), `README.md` (repo overview). Korean translations: `SETUP_ko.md`, `SETUP_CHECKLIST_ko.md`.
> - First thing to try: open a new terminal, run `claude`, and ask it to run `bun setup-common.ts` once more.

**[KO — 한국어]**

> ## 📘 사용법 안내 5/5 — 팁과 더 알아보기
>
> - 이미 설치된 도구는 자동으로 건너뜁니다. `--force`(Windows 는 `-Force`)는 재설치를 명시적으로 원할 때만 붙이세요.
> - 재현 가능한 환경이 필요하면 버전을 고정합니다: `BUN_VERSION=1.1.34 UV_VERSION=0.4.20 PYTHON_VERSION=3.13 bash setup-mac.sh`.
> - Windows 실행 정책 오류: `powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1` 로 실행합니다 (그룹 정책 케이스는 SETUP.md 참조).
> - 문서: `SETUP.md` (상세 가이드), `SETUP_CHECKLIST.md` (워크샵 전 체크리스트), `README.md` (저장소 개요). 한국어 번역: `SETUP_ko.md`, `SETUP_CHECKLIST_ko.md`.
> - 첫 실습: 새 터미널을 열고 `claude` 를 실행한 뒤, `bun setup-common.ts` 를 다시 실행해 달라고 요청해 보세요.

**[JA — 日本語]**

> ## 📘 セットアップ案内 5/5 — ヒントと、さらに学ぶには
>
> - すでにインストール済みのツールは自動的にスキップされます。`--force`(Windows は `-Force`)は、再インストールを明示的に希望するときだけ付けてください。
> - 再現可能な環境が必要なら、バージョンを固定します: `BUN_VERSION=1.1.34 UV_VERSION=0.4.20 PYTHON_VERSION=3.13 bash setup-mac.sh`。
> - Windows の実行ポリシーエラー: `powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1` で起動します(グループポリシーの場合は SETUP.md を参照)。
> - ドキュメント: `SETUP.md`(詳細ガイド)、`SETUP_CHECKLIST.md`(ワークショップ前チェックリスト)、`README.md`(リポジトリ概要)。韓国語訳: `SETUP_ko.md`、`SETUP_CHECKLIST_ko.md`。
> - 最初に試すこと: 新しいターミナルを開いて `claude` を起動し、`bun setup-common.ts` をもう一度実行するよう頼んでみてください。

**[ES — Español]**

> ## 📘 Guía de uso 5/5 — Consejos y dónde aprender más
>
> - Las herramientas ya instaladas se omiten automáticamente. Usa `--force` (`-Force` en Windows) solo cuando quieras reinstalar de forma explícita.
> - Para un entorno reproducible, fija las versiones: `BUN_VERSION=1.1.34 UV_VERSION=0.4.20 PYTHON_VERSION=3.13 bash setup-mac.sh`.
> - Error de política de ejecución en Windows: lanza con `powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1` (el caso de directiva de grupo está en SETUP.md).
> - Documentación: `SETUP.md` (guía completa), `SETUP_CHECKLIST.md` (checklist previo al taller), `README.md` (resumen del repositorio). Traducciones al coreano: `SETUP_ko.md`, `SETUP_CHECKLIST_ko.md`.
> - Primera prueba: abre una terminal nueva, ejecuta `claude` y pídele que ejecute `bun setup-common.ts` una vez más.

---

### 3-7. 완료 후 (마지막)

사용자 안내를 마무리하고("안내는 여기까지입니다" — §3-0 의 언어로), 별도 메시지로 설치 결과 표(§7, `🔧 [설치]`)와 함께 "다음에 할 일"(로그인, 구독, 수동 설치 앱)을 §3-0 의 언어로 안내합니다.

---

## 4. 트랙 A — OS 설치 스크립트 실행 (`setup-os-script`)

> 스크립트가 이미 설치된 항목을 건너뛰므로, 에이전트가 임의로 개별 도구를 수동 설치하지 마세요. 스크립트가 실패한 항목만 `SETUP.md` 의 설치 방법으로 보완합니다.

### 4-1. 옵션 플래그 (사용자에게 먼저 물어볼 것)

- `--wezterm` (Windows `-WezTerm`): GPU 가속 터미널 WezTerm 추가 설치
- `--docker` (Windows `-Docker`): Docker Desktop 추가 설치
- `-WSL2` (Windows 전용): WSL2 설치 (**재시작 필요** — 사전에 사용자에게 알리고 동의를 받습니다)
- `--force` (Windows `-Force`): 이미 설치된 도구도 강제 재설치 (기본은 스킵)
- `--company <name>`: 조직 추가 도구 설치 (사용자가 조직 소속이고 지시할 때만)
- `--help`: 사용법 출력

기본 설치는 **플래그 없이** 실행하는 것이 원칙입니다. 옵션 도구는 실행 전 사용자에게 물어보고 선택된 것만 붙입니다.

### 4-2. macOS

```bash
bash setup-mac.sh            # [+ 사용자가 선택한 옵션 플래그]
```

- Homebrew 가 없으면 스크립트가 Xcode CLT + Homebrew 를 설치하며 **sudo 비밀번호 입력이 필요**합니다. 비대화형 환경에서 비밀번호를 입력할 수 없으면 "사용자가 직접 터미널에서 실행해야 함"으로 보고하세요 (`NONINTERACTIVE=1` 로 억지 진행하지 않음).
- Docker Desktop 옵션은 설치 후 **사용자가 Docker Desktop 앱을 한 번 실행**해야 서비스가 시작됩니다.

### 4-3. Linux (Ubuntu/Debian)

```bash
bash setup-linux.sh          # [+ 사용자가 선택한 옵션 플래그]
```

- `sudo` 가 필요한 단계에서 **sudo 비밀번호는 사용자가 직접 입력**합니다. 에이전트는 비밀번호를 묻거나 입력하지 않습니다.
- Docker 옵션은 `get.docker.com` 스크립트를 사용합니다 (스크립트가 파일로 내려받아 해시를 출력·기록한 뒤 실행).

### 4-4. Windows

**PowerShell 을 관리자 권한으로** 열어 실행합니다. 스크립트는 PowerShell 7+ 이 필요하며, 5.1 에서 시작하면 `pwsh` 로 자동 재실행합니다 (필요 시 winget 으로 PowerShell 7 을 먼저 설치).

```powershell
# 실행 정책 회피를 포함해 시작 (스크립트 차단 자체를 방지)
powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1 [-WezTerm] [-Docker] [-WSL2] [-Force] [-Company <name>]

# 또는 세션 한정 정책 우회 후 실행:
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\setup-windows.ps1
```

- `-WSL2` 사용 시 **재시작이 필요**합니다 — 실행 전 사용자에게 알리고 동의를 받습니다.
- 실행 후 **새 터미널을 열어야** PATH 가 반영됩니다. 같은 세션을 이어서 쓰려면:
  ```powershell
  $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
  ```

### 4-5. 버전 고정 (사용자가 요청할 때만)

> `PYTHON_VERSION` 은 macOS/Linux 전용입니다 (Windows 는 `winget Python.Python.3.13` 고정). macOS 는 Homebrew 가 최신 uv 를 설치하므로 `UV_VERSION` 은 경고만 출력하고 핀되지 않습니다.

```bash
# macOS / Linux
BUN_VERSION=1.1.34 UV_VERSION=0.4.20 PYTHON_VERSION=3.13 bash setup-mac.sh
```

```powershell
# Windows
$env:BUN_VERSION = "1.1.34"; $env:UV_VERSION = "0.4.20"; powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1
```

### 검증 (트랙 A)

- 스크립트 자체의 종료 코드가 0 이고, 마지막 요약에 치명적 실패(❌) 항목이 없어야 합니다.
- 경고(⚠️, 예: 수동 설치 필요 항목)는 §5 로 전달합니다.
- 로그: `~/workshop-setup-logs/` (Windows: `%USERPROFILE%\workshop-setup-logs\`) — 실패 항목은 로그 파일 경로와 함께 보고합니다.

---

## 5. 트랙 B — 수동 항목과 사용자 작업 (`setup-manual-apps`)

시스템을 변경하지 않고, 사용자가 직접 해야 할 일을 정리해 §3-0 의 언어로 전달합니다 (트랙 A와 병렬 진행).

### 5-1. 수동 설치가 필요한 항목 (OS별)

| 항목 | macOS | Linux | Windows |
|---|---|---|---|
| Claude Desktop | 자동 (`brew install --cask claude`) | ⚠️ 수동 | 자동 (`winget Anthropic.Claude`) |
| Codex Desktop | 자동 (DMG, 서명 검증) | ⚠️ CLI 전용 (데스크톱 없음) | 자동 (Microsoft Store, `winget` msstore) |
| Antigravity Desktop | ⚠️ 수동 | ⚠️ 수동 | ⚠️ 수동 |
| Mark (Markdown 뷰어) | ⚠️ 수동 | ⚠️ 수동 | ⚠️ 수동 |

⚠️ 항목은 공식 다운로드 페이지를 안내하고 **사용자가 직접** 설치하도록 합니다. Linux 의 Codex Desktop 은 데스크톱 앱이 존재하지 않으므로 "CLI 만 사용 가능"으로 안내합니다.

### 5-2. 로그인 (사용자 작업 — 에이전트가 대행하지 않음)

```bash
gh auth login
claude login        # 또는 claude 실행 후 /login
codex login
```

에이전트는 로그인 상태를 **읽기 전용으로만** 확인합니다 (`gh auth status` 등). 안 되어 있으면 위 명령을 사용자가 직접 실행하도록 안내합니다 (`claude auth status` 는 대화형 CLI 에서 `/login` 으로 대체될 수 있음).

### 5-3. 구독/계정 (체크리스트 항목)

- Claude Pro/Max (claude), ChatGPT Plus/Pro (codex), Gemini Advanced (agy) — **구독**이 필요하고 API 키가 아닙니다.
- GitHub 계정이 없으면 가입을 안내합니다.
- 한국 공공 API 키 등은 이 저장소의 설치 범위 밖입니다 (워크샵 프로젝트에서 별도 안내).

---

## 6. 트랙 C — 최종 검증 (`setup-verify`)

### 6-1. 검증 스크립트 실행

```bash
bun setup-common.ts          # 사람이 읽는 검증 표
bun setup-common.ts --json   # 기계 판독 출력 (CI/스크립트용)
```

이 표에는 모든 도구의 ✅/❌, `bun`/`uv` 최소 버전 검사, OS별 파이썬 검사(macOS/Linux `python3`, Windows `python`), `claude`/`codex`/`gh` 로그인 상태가 포함됩니다.

### 6-2. 판정

- **필수 행이 모두 ✅** → 워크샵 준비 완료. §7 최종 보고로 진행합니다.
- ❌ 항목이 있으면:
  1. "PATH 문제" 가능성 → 새 터미널에서 재검증을 시도합니다 (§4-4 의 `$env:Path` 재로드 포함).
  2. 그래도 ❌ 면 `SETUP.md` 의 **Troubleshooting** 절의 해당 조치를 적용합니다 (§8 표 참조).
  3. 로그인 상태 ❌ 는 사용자 작업(§5-2)으로 분류하고 설치 실패로 세지 않습니다.
- 오프라인/사내망 환경: 원격 설치 스크립트(bun, uv, Codex CLI, Antigravity CLI) 다운로드가 막혀 있으면 설치를 진행하지 말고 "사용자 작업 필요(프록시 설정 또는 수동 설치)"로 보고합니다. 임의의 미러/포크로 대체하지 마세요.

---

## 7. 최종 보고 형식 (메인 에이전트가 사용자에게 — §3-0 의 언어로)

```
## 설치 결과 — <OS>   *(Language used: <KO/JA/ES/EN> — §3-0 판별 결과)*
| 트랙 | 결과 | 비고 |
|---|---|---|
| A OS 설치 스크립트 | ✅/⚠️/❌ | 설치된 버전 (bun, uv, python, gh, claude, codex, agy, gitleaks) |
| B 수동 항목 | ✅/⚠️/❌ | 수동 설치 필요 앱 목록 |
| C 검증 | ✅/⚠️/❌ | bun setup-common.ts 결과 |

### 사용자가 직접 해야 할 일
- [ ] 새 터미널을 열어 PATH 반영
- [ ] gh / claude / codex 로그인
- [ ] 구독 확인: Claude Pro/Max, ChatGPT Plus/Pro, Gemini Advanced
- [ ] (OS별) 수동 설치 앱: <Antigravity Desktop, Mark 등 ⚠️ 항목>
- [ ] (Windows) `-WSL2` 를 설치했다면 재시작
- [ ] (실패 항목) <원인과 다음 조치 + 로그 경로>

### 시작하기
bun setup-common.ts   →   모두 ✅ 이면 새 터미널에서 claude / codex / agy 실행
```

---

## 8. 문제 해결 (에이전트 참고 — `SETUP.md` Troubleshooting 과 동기화 유지)

| 증상 | 조치 |
|---|---|
| 설치 후 `bun: command not found` | 터미널 재시작. macOS/Linux: `export PATH="$HOME/.bun/bin:$PATH"`. Windows: bun 은 User PATH 에 자동 등록되므로 새 터미널에서 확인 |
| `claude: command not found` (bun install 후) | 스크립트가 npm 폴백으로 자동 재시도합니다. 계속되면 `bun pm ls -g` 확인 후 bin 디렉터리를 PATH 에 추가 |
| `codex: command not found` | 스크립트는 단독 바이너리를 설치합니다. 터미널 재시작으로 `~/.local/bin`(Linux) 또는 winget links dir(Windows) 반영 |
| `agy: command not found` | Antigravity CLI 는 `~/.local/bin` 또는 `/usr/local/bin` 에 설치됩니다. `source ~/.bashrc` 또는 터미널 재시작 |
| Windows: `execution of scripts is disabled` | `powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1` 로 시작. 영구 설정(사용자 단위): `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`. **그룹 정책(MachinePolicy/UserPolicy)** 이면 로컬 변경 불가 — IT 에 문의. 다운로드한 `.ps1` 은 `Unblock-File` 필요할 수 있음 |
| Windows: 관리자 권한 없이 실행됨 | 스크립트는 경고 후 계속하지만 일부 설치(winget, WSL2)가 실패할 수 있음. 관리자 PowerShell 로 재실행 권장 |
| mac/linux: sudo 비밀번호 입력 불가 | 해당 단계를 "사용자가 직접 터미널에서 실행"으로 보고하고 나머지 진행. `NONINTERACTIVE=1` 로 억지 진행하지 않음 |
| 지원 범위 밖 Linux 배포판 (Fedora/RHEL, Arch 등) | 스크립트를 실행하지 말고 `SETUP.md` 의 설치 방법 표를 기준으로 수동 설치를 안내 (임의 치환 설치 금지) |
| 권한 부족 | 해당 명령만 사용자에게 전달하고 나머지 진행 |
| 로그 확인 | `~/workshop-setup-logs/` (Windows: `%USERPROFILE%\workshop-setup-logs\`) |

---

## 9. 이 문서의 유지보수

- 설치 명령·플래그는 `SETUP.md` 를 **기준**으로 합니다. 이 문서에 버전을 복제하지 마세요 (표의 버전은 작성 시점 예시 값).
- `SETUP.md` 의 플래그가 바뀌면 이 문서의 §4-1, §4-2~4-5, §6, §8 을 **함께** 갱신하세요. `check-docs-sync.sh` 와 CI(`.github/workflows/test-setup.yml` 의 docs-sync)는 `SETUP.md`/`SETUP_ko.md` 의 동기화만 검사하며, 이 문서는 검사 대상이 아닙니다.
- 설치 대상 도구가 추가되면 §0 도구 목록, §1-3 스캔 목록, §5-1 수동 설치 표에 한 줄씩 추가하세요.
- **안내 언어 집합을 바꾸려면**: §3-0 의 매핑 표와 §3-2~3-6 의 언어 블록을 함께 갱신하세요. 기본값(폴백)은 영어를 유지하는 것이 이 문서의 규칙입니다.
