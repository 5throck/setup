# 워크숍 환경 설정

[English](README.md)

워크숍 실습을 위한 원샷 환경 설정 스크립트입니다. 기본 도구, 런타임(`bun`, `python3`, `uv`), CLI 도구(`gh`, `claude`, `agy`), 데스크톱 앱까지 macOS / Linux(Ubuntu·Debian) / Windows에서 자동으로 설치합니다.

## 빠른 시작

1. 먼저 [`SETUP_CHECKLIST_ko.md`](SETUP_CHECKLIST_ko.md)를 읽고 사전 준비를 완료하세요.
2. OS에 맞는 스크립트를 관리자/sudo 권한으로 실행합니다.

```bash
# macOS
bash setup-mac.sh

# Linux (Ubuntu/Debian)
bash setup-linux.sh

# Windows (PowerShell을 관리자 권한으로 실행)
powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1
```

3. 설치가 제대로 됐는지 검증합니다.

```bash
bun setup-common.ts
```

전체 설치 흐름, 선택 플래그(`--wezterm`, `--docker`, `-WSL2`, `--force`), 트러블슈팅은 [`SETUP_ko.md`](SETUP_ko.md)를 참고하세요.

## 저장소 구성

| 파일 | 설명 |
|---|---|
| [`SETUP_ko.md`](SETUP_ko.md) | 전체 설치 가이드(설치 흐름, 플래그, 트러블슈팅) |
| [`SETUP_CHECKLIST_ko.md`](SETUP_CHECKLIST_ko.md) | 워크숍 전 체크리스트(계정, 구독, 사전 요구사항) |
| `setup-mac.sh` / `setup-linux.sh` | OS별 설치 스크립트 |
| `setup-lib.sh` | mac/linux 스크립트가 공통으로 source하는 bash 헬퍼: 진행률 UI, 사전 점검, 로그 저장, `--force`, 정리(cleanup) |
| `setup-windows.ps1` | Windows 설치 스크립트 (PowerShell) |
| `setup-common.ts` | OS 스크립트 실행 후 사용하는 크로스플랫폼 검증 스크립트 |
| `check-docs-sync.sh` | `SETUP.md` 문서가 스크립트의 실제 플래그와 어긋나면 실패하는 CI 가드 |
| `.github/workflows/test-setup.yml` | CI: ShellCheck, 컨테이너에서 `setup-linux.sh` 실제 실행, PowerShell 구문 검사 |

영문 문서: [`SETUP.md`](SETUP.md), [`SETUP_CHECKLIST.md`](SETUP_CHECKLIST.md).

## 재현 가능한 설치 (버전 고정)

항상 최신 버전을 설치하는 대신 `bun`/`uv`/`python3` 버전을 고정할 수 있습니다.

```bash
BUN_VERSION=1.1.34 UV_VERSION=0.4.20 bash setup-mac.sh
```

```powershell
$env:BUN_VERSION = "1.1.34"; $env:UV_VERSION = "0.4.20"; powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1
```

## 보안 참고사항

이 스크립트들은 `bun`, `uv`, Antigravity CLI를 각 서비스의 공식 원격 설치 스크립트로 설치합니다. 다운로드한 내용을 바로 쉘에 흘려보내는 `curl | bash` / `irm | iex` 방식 대신, 설치 스크립트를 먼저 디스크에 내려받아 SHA-256 해시를 출력·로그로 남긴 뒤에 실행합니다 — 실행 전 내용을 직접 검토하지는 않지만 최소한 실행 이력을 추적할 수 있습니다. 자세한 내용은 각 스크립트 상단의 보안 주석을 참고하세요.

## CI

설치 스크립트가 변경될 때마다 다음이 실행됩니다.
- **docs-sync** — `SETUP.md`에 문서화된 플래그가 스크립트와 일치하는지 확인
- **shellcheck** — `setup-linux.sh` / `setup-mac.sh` / `setup-lib.sh` 린트
- **linux-dry-run** — Ubuntu 컨테이너에서 `setup-linux.sh`를 실제로 실행한 뒤 `setup-common.ts --json`으로 검증
- **windows-syntax-check** — `setup-windows.ps1`을 구문 파싱만 수행 (실행하지 않음)
