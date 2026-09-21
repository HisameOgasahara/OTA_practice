# Day 3 자동 Secure OTA 실습

## 실행

루트 `config.json`의 접속 정보를 확인하고 `START.cmd`를 실행합니다. DAY2와 같이 추가 입력 없이 전체 실습을 진행하며 A 서버 창과 B Pi 실습 창에 결과가 남습니다. 완료 후 HTTP 서버는 종료되고 각 창에서 Enter를 누르면 닫힙니다.

Windows PowerShell 5.1과 Raspberry Pi의 Python 3.9 이상, OpenSSL 명령이 필요합니다. PC에 Python을 설치할 필요는 없습니다. 최초 실행 시 공식 Plink를 다운로드하고 `tools.json`의 SHA-256으로 검증합니다.

## 루트 설정

`config_example.json`을 참고하여 프로젝트 루트의 `config.json`을 작성합니다. 실제 비밀번호가 들어 있는 설정은 Git에서 제외됩니다.

| 항목 | 용도 | 예시/기본값 |
|---|---|---|
| `host_name`, `username`, `password`, `mac`, `ip` | Pi 접속 및 대상 검증 | 실제 장치 정보 |
| `ssh_host_key` | SSH 서버 지문 고정 | `SHA256:...` |
| `pc_ip` | Pi에서 접근할 Windows 주소 | 실제 PC IPv4 |
| `ssh_port` | DAY3 SSH 포트 | 22 |
| `day3_port` | DAY3 HTTP 서버와 클라이언트 포트 | 8001 |
| `step_pause_seconds` | 단계별 화면 대기 시간 | 4초 |
| `ssh_connect_timeout_seconds` | DAY3 SSH TCP 연결 대기 | 5초 |
| `server_signal_timeout_seconds` | DAY3 서버 준비·게시 완료 대기 | 20초 |
| `http_timeout_seconds` | DAY3 HTTP 요청 대기 | 5초 |
| `remote_command_timeout_seconds` | DAY3 Pi 검증기에서 실행하는 개별 Python 명령 제한 | 60초 |
| `last_verified_at` | SSH 로그인 후 장치 이름·계정·MAC 검증 성공 시각, 자동 갱신 | 참고용 |

기존 `port`는 DAY2용입니다. DAY3는 `day3_port`를 사용합니다. 새 SSH 포트와 제한 시간 항목은 DAY3에서 사용하며 기존 SSH 자동접속과 DAY2 동작은 그대로입니다. IP를 자동 탐색하거나 방화벽을 변경하지 않습니다. Pi가 접근할 수 있도록 설정한 DAY3 TCP 포트를 허용해야 합니다.

## 실습 순서

교재 12~14장(25~28쪽)의 순서를 따릅니다. SSH 로그인 후 장치 이름·계정·MAC과 Python·OpenSSL을 확인하고 실행별 독립 폴더에 자료를 준비합니다. 차량을 slot_A / v1.0 / NORMAL / ON으로 초기화한 뒤 다음 다섯 시나리오를 진행합니다.

| 시나리오 | 확인 결과 | 최종 활성 상태 |
|---|---|---|
| 정상 v2 | 서명·해시·버전·Health 통과, 업데이트 성공 | slot_B / v2.0 / ON |
| v3 펌웨어 변조 | 서명 통과, SHA-256 실패, 설치 거부 | 기존 상태 유지 |
| v3 Manifest 변조 | 서명 실패, 설치 거부 | 기존 상태 유지 |
| 정상 서명된 v1 | 서명·해시 통과, Anti-Rollback 거부 | 기존 상태 유지 |
| v3_badhealth | 검증 후 slot_A 설치, Health 실패, 복구 | slot_B / v2.0 / ON 유지 |

예상된 거부는 클라이언트의 종료 코드 1뿐 아니라 해당 검증 메시지와 저장된 차량 상태까지 일치해야 통과합니다. 앞의 세 거부 시나리오는 상태 파일이 바뀌지 않았는지도 확인합니다. Recovery는 실패한 후보가 비활성 슬롯에 있고 기존 정상 슬롯과 헤드램프 ON이 유지되는지 확인합니다.

## 파일과 결과

- `Run-Day3.ps1`: 설정 검증, SSH, 자료 전송, 시나리오 진행과 결과 저장.
- `Server.ps1`: Release 게시·변조, 제한된 HTTP 파일 제공, 요청 로그.
- `scenarios.json`: 교재 시나리오 순서·Release·예상 종료 코드·검증 메시지.
- `lab/vehicle`: 교재 차량 프로그램·공개키·실행 검증기. 클라이언트의 주소·포트·HTTP 제한 시간은 실행 설정에서 읽습니다.
- `lab/server/releases`: 교재의 서명된 v1, v2, v3, v3_badhealth 자료.
- `.runtime/실행ID/result.json`: 전체 성공 여부와 통과 시나리오 목록.
- `.runtime/실행ID/server.log`, `vehicle.log`: A/B 창 기록.
- Pi의 `~/ota_day3_runs/실행ID`: 개별 시나리오 결과와 최종 차량 상태.

`DAY3/scenarios.json`은 실행 시 Pi에 자동 전송됩니다. 실습 버전과 기대 상태는 교재 검증 기준이며 환경 설정과 구분됩니다. `lab`에는 교육용 공개키와 이미 서명된 자료만 포함하고 개인키는 포함하지 않습니다.

## 오류와 재실행

| 오류 | 조치 |
|---|---|
| PC 주소 불일치 | 현재 IPv4로 루트 `pc_ip` 수정 |
| SSH 연결·인증·장치 검증 실패 | Pi 전원, 접속 정보, SSH 지문 확인 |
| Python/OpenSSL 없음 | Pi에 교재의 필수 실행 도구 설치 |
| 포트 사용 중 | 해당 서버를 종료하거나 `day3_port` 변경 |
| HTTP 다운로드 실패 | A 창, 같은 LAN 연결, 해당 포트의 방화벽 허용 확인 |
| 검증 메시지·차량 상태 불일치 | `vehicle.log`에서 실제 실패 지점 확인 |

실패하면 다음 시나리오를 진행하지 않고 서버 종료를 요청합니다. B 창 강제 종료 시 A 서버는 소유 프로세스 종료를 확인해 중지합니다. 다시 실행하면 새 폴더를 사용하므로 이전 결과를 덮어쓰지 않습니다. 정상 종료와 처리된 오류에서는 임시 비밀번호 파일을 삭제합니다. 강제 종료 시 남을 수 있는 `.runtime`과 실제 `config.json`은 공유 자료에서 제외합니다.
