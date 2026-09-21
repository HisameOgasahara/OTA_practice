# Raspberry Pi OTA 실습 환경

Windows PC를 OTA 서버로, Raspberry Pi를 가상 차량으로 사용하여 펌웨어 변조의 영향과 보안 업데이트의 차단·복구 동작을 실습합니다. 전체 과정을 한 번에 실행하려면 **Integrated**, 교재의 개별 단계를 실습하려면 **DAY2·DAY3**, 접속만 하려면 **SSH_AutoConnect**를 사용합니다.

## 준비 환경

| 항목 | 환경 |
|---|---|
| Windows PC | Windows 10/11 64비트, Windows PowerShell 5.1 |
| Raspberry Pi | Raspberry Pi 5, Raspberry Pi OS 64비트, Python 3 |
| 저장장치 | microSD 32GB 이상 권장 |
| 네트워크 | PC와 Pi가 같은 Wi-Fi 또는 LAN에 연결 |
| SSH | Pi에서 활성화, 사용자 계정과 비밀번호 설정 |
| Day 3 서버 | Windows PC TCP 8001 기본값, 루트 `day3_port`로 변경 |
| Integrated 서버 | 루트 `day3_port` 사용. 같은 포트를 사용하는 DAY3 서버는 종료 후 실행 |
| Day 2 서버 | Windows PC TCP 8000, Pi에서 접근 가능하도록 방화벽 허용 |
| 접속 설정 | 루트 `config_example.json`을 `config.json`으로 복사해 작성. 실제 설정은 Git 제외 |

`SSH_AutoConnect`, `DAY2`, `DAY3`, `Integrated`는 같은 루트 `config.json`을 읽습니다. `DAY3/START.cmd`는 교재의 Secure OTA 5개 시나리오를 자동 실행합니다. `Integrated/START.cmd`는 검증 없는 OTA부터 공격 차단·A/B 복구까지 7개 시나리오를 통합 실행합니다. 자세한 내용은 [통합 실습 가이드](Integrated/Integrated_guide.md)를 참고하세요. IP 자동 탐색 없이 설정된 주소로 접속하며, `last_verified_at`은 마지막 접속 정보 검증 시각을 기록하는 참고 필드입니다.

## IP 확인과 설정 갱신

PC와 Pi의 IP는 재부팅, Wi-Fi 변경, 공유기의 주소 재할당 등으로 바뀔 수 있습니다. 실습 전이나 접속 오류가 발생했을 때 현재 주소를 확인하세요. Windows에서는 `ipconfig`, Pi에서는 `hostname -I`로 확인할 수 있습니다. Pi에 접속할 수 없다면 공유기의 연결 장치 목록 등에서 Pi 주소를 확인합니다.

현재 주소와 접속 대상을 확인·확정한 뒤 루트 `config.json`의 `ip`(Pi)와 `pc_ip`(Windows)를 수정하고, 확인 날짜·시각 필드인 `last_verified_at`도 갱신하세요. 예: `2026-09-21T14:00:00+09:00`. 주소를 추측해 입력한 상태에서는 검증 시각을 갱신하지 않습니다.

SSH 자동접속, DAY2, DAY3, Integrated는 로그인 후 장치 이름·계정·MAC 검증에 성공하면 `last_verified_at`을 자동 갱신합니다. 이 필드는 사람이나 AI의 디버깅 참고용이며, 프로그램은 날짜를 기준으로 접속 여부를 판단하거나 IP를 자동 탐색하지 않습니다.

## 참조 문서

- [Microsoft Windows OpenSSH 안내](https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse)
- [mDNS 표준 RFC 6762](https://www.rfc-editor.org/info/rfc6762/)
- [PuTTY / Plink 공식 다운로드](https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html)

## 실행 방법

1. Pi에서 SSH를 활성화하고, PC와 Pi를 같은 네트워크에 연결합니다. DAY3·Integrated에는 Pi의 Python 3.9 이상과 OpenSSL이 필요합니다.
2. 루트 `config_example.json`을 같은 폴더의 `config.json`으로 복사합니다. 이미 설정 파일이 있다면 현재 주소와 접속 정보를 확인합니다.
3. `config.json`에 Pi 주소(`ip`), PC 주소(`pc_ip`), 계정·비밀번호, 장치명(`host_name`), MAC 주소, 확인한 SSH 호스트 지문(`ssh_host_key`)을 입력합니다. Integrated는 `ssh_port`, `day3_port`와 예시 파일의 제한 시간 항목도 사용합니다.
4. PC에서 해당 실습 HTTP 포트로 Pi가 접근할 수 있게 방화벽을 설정하고, 아래 실행 파일을 더블클릭합니다. 프로그램은 방화벽이나 IP를 자동 변경하지 않습니다.

처음 설정할 때 저장소 루트에서 실행할 수 있는 명령입니다. 이미 작성한 `config.json`은 덮어쓰지 않습니다.

```cmd
if not exist config.json copy config_example.json config.json
notepad config.json
Integrated\START.cmd
```

| 구분 | 실행 파일 | 실행 결과 |
|---|---|---|
| SSH 자동접속 | [SSH_AutoConnect/START.cmd](SSH_AutoConnect/START.cmd) | Pi에 자동 로그인하고 명령 입력 창을 유지합니다. 종료는 `exit`입니다. |
| DAY2 | [DAY2/START.cmd](DAY2/START.cmd) | 정상 OTA와 변조 OTA를 자동 실행하고 결과를 A/B 창에 표시합니다. |
| DAY3 | [DAY3/START.cmd](DAY3/START.cmd) | 정상 Secure OTA, 변조 차단, 구버전 차단, A/B 복구를 자동 실행하고 결과를 A/B 창에 표시합니다. |
| Integrated | [Integrated/START.cmd](Integrated/START.cmd) | SSH 준비부터 검증 없는 OTA·공격 차단·복구까지 실행합니다. 서버는 백그라운드에서 동작하며 결과를 실행 창과 로그에 남깁니다. |

DAY2와 DAY3는 SSH 접속까지 자동으로 진행합니다. 완료 후 각 창에서 Enter를 누르면 닫힙니다.

## Integrated의 목적과 기존 실습과의 관계

**Integrated는 SSH 연결부터 검증 없는 OTA, 공격 차단, A/B 복구까지 하나의 실행으로 비교하는 통합 실습입니다.** 날짜별 실행 구분을 업데이트 정책·공격 조건·차량 상태로 재구성했습니다. 검증 없는 방식과 보안 방식에 동일한 v3 변조 펌웨어를 제공하여, 설치 허용과 무결성 검사에 의한 차단의 차이를 확인합니다.

기존 `SSH_AutoConnect`, `DAY2`, `DAY3`는 개별 실습용으로 유지합니다. Integrated는 이 폴더의 실행 파일을 순서대로 호출하지 않으며, 필요한 코드와 실습 자료를 자체적으로 가지고 **루트 `config.json`만 공유**합니다. 중복 제거 범위는 Integrated 내부입니다. 기존 폴더까지 공통 모듈로 전환한 구조는 아닙니다.

### 중복 제거와 책임 분리

기존 실행기에서 반복하던 설정 검사, 접속 도구 검증, SSH 장치 확인, 자료 전송, 서버 대기와 결과 저장을 각각 공통 모듈로 모았습니다. 차량 쪽도 다운로드 흐름과 상태 처리를 공유하고, 검증 정책과 설치 방식을 분리했습니다.

| 구성 | 담당 책임 |
|---|---|
| `Integrated/Run-Lab.ps1` | 준비 → 시나리오 반복 → 결과 집계 → 종료 조율 |
| `modules/Config.psm1` | 루트 설정 읽기와 입력 검증 |
| `modules/Ssh.psm1` | Plink 검증, SSH 연결·장치 확인·자료 전송·원격 명령 |
| `modules/Runtime.psm1` | 백그라운드 서버 시작과 게시 요청·대기 |
| `modules/Results.psm1` | 전체 실행 결과 저장 |
| `server/Start-Server.ps1` | HTTP 파일 제공과 요청 기록 |
| `server/Repository.psm1` | 릴리스 게시·변조 작업본 생성 |
| `vehicle/ota_client.py` | 공통 다운로드와 업데이트 진행 |
| `vehicle/verification.py` | 서명·해시·버전 검증 |
| `vehicle/installation.py` | 직접 설치·A/B 설치·Health 실패 복구 |
| `vehicle/ecu.py` | 가상 차량 상태 저장과 헤드램프 동작 확인 |
| `scenarios/scenarios.json` | 시나리오 순서·초기 상태·정책·공격·기대 결과 |
| `scenarios/verify_scenario.py` | 실제 판단과 저장 상태를 기대 결과와 비교 |

표의 하위 경로는 `Integrated/` 기준입니다. SSH는 실습 준비·제어를 담당하고, HTTP OTA는 펌웨어를 전달합니다. 검증 없는 OTA를 선택해도 SSH 접속 대상 검증은 유지됩니다. 클라이언트는 기대 결과를 읽지 않고 실제 검증·설치를 수행하며, 별도 검증기가 결과를 판정합니다.

### 한 번에 실행하는 7개 시나리오

| 순서 | 시나리오 | 기대 결과 |
|---|---|---|
| 1 | 검증 없는 정상 업데이트 | v1 초기화 후 v2 직접 설치, 헤드램프 ON |
| 2 | 검증 없는 펌웨어 변조 | 변조 v3 설치 허용, 헤드램프 OFF |
| 3 | 정상 보안 업데이트 | v1 초기화 후 정상 v2를 slot_B에 설치, ON |
| 4 | 동일한 v3 펌웨어 변조 | SHA-256 검사 실패로 거부, 정상 v2 유지 |
| 5 | Manifest 변조 | 서명 검사 실패로 거부, 정상 v2 유지 |
| 6 | 정상 서명된 구버전 v1 제공 | 버전 정책으로 거부, 정상 v2 유지 |
| 7 | Health 실패 업데이트 | 실패 후보를 비활성 슬롯에 남기고 정상 slot_B 유지 |

1·3단계의 초기화는 화면에 `[RESET]`으로 표시하고 결과에도 기록합니다. 이후 보안 시나리오는 정상 v2 상태를 이어서 사용합니다. 교재의 검증 없는 변조 실습에 쓰는 v2 대신 통합 실습에서는 비교 조건을 맞추기 위해 v3를 사용합니다.

예상한 공격 차단과 복구는 실습 성공입니다. 종료 코드뿐 아니라 거부 원인, 저장 상태, 헤드램프 동작도 일치해야 통과합니다. 통신 오류나 예상과 다른 실패가 발생하면 진행을 중단합니다.

### 결과 확인과 재실행

Integrated는 차량 실행 결과를 한 창에 표시하고 HTTP 서버는 백그라운드에서 실행합니다. 완료 후 서버를 종료하며, 결과 확인 후 Enter를 누르면 실행 창이 닫힙니다.

| 위치 | 내용 |
|---|---|
| `Integrated/.runtime/실행ID/result.json` | 전체 성공 여부, 오류, 시나리오별 판단·전후 상태 |
| 같은 폴더의 `vehicle.log` | SSH 확인과 차량 실행 기록 |
| 같은 폴더의 `server.log` | 릴리스 게시·변조와 실제 HTTP 요청 기록 |
| Pi의 `~/ota_integrated_runs/실행ID/` | 차량 상태와 시나리오별 결과 |

매 실행마다 새 폴더를 사용합니다. 서버 원본 자료는 보존하고 실행별 작업본만 변조하므로, 이전 결과를 덮어쓰지 않고 다시 실습할 수 있습니다. 최종 정상 상태는 **slot_B / v2.0 / 헤드램프 ON**입니다.

| 오류 | 확인할 내용 |
|---|---|
| `SSH connection timeout` | Pi 전원·부팅·네트워크, 현재 Pi IP, SSH 활성화와 포트. 일시적 지연이면 잠시 후 재실행 |
| SSH 인증 또는 장치 정보 불일치 | 루트 설정의 계정·비밀번호·호스트 지문·장치명·MAC |
| PC 주소 불일치 | `ipconfig`로 확인한 현재 주소와 `pc_ip` |
| HTTP 포트 사용 중 | 기존 DAY3·Integrated 서버와 설정한 `day3_port` |
| HTTP 다운로드 실패 | PC 서버 로그, 같은 네트워크 연결, Windows 방화벽 |

상세 설정과 개발 검증 방법은 [Integrated 가이드](Integrated/Integrated_guide.md)에 있습니다. Windows 로컬 검증과 실제 Raspberry Pi에서 7개 시나리오의 전체 실행을 확인했습니다.

## 실습 범위와 공유 파일

가상 ECU의 JSON 상태로 차량 동작과 A/B 복구를 모사합니다. 실제 차량이나 부팅 파티션을 변경하지 않습니다. 공격자가 배포 저장소를 수정할 수 있는 조건에서 업데이트 검증의 효과를 관찰하며, 저장소 침입 과정은 포함하지 않습니다. 배포 자료에는 교육용 공개키와 이미 서명된 릴리스가 들어 있습니다.

실제 계정 정보가 들어 있는 루트 `config.json`, 실행 기록·임시 파일이 들어 있는 `.runtime/`, 다운로드 도구가 들어 있는 `.tools/`는 Git에서 제외합니다. 폴더를 ZIP으로 공유할 때에도 제외하세요. 임시 비밀번호 파일은 정상 종료와 처리된 오류에서 삭제되며, 강제 종료하면 남을 수 있습니다.
