# 통합 OTA 실습

## 실행 환경과 시작

Windows PowerShell 5.1, Raspberry Pi의 Python 3.9 이상과 OpenSSL을 사용합니다. PC에 Python을 설치할 필요는 없습니다. PC와 Pi는 같은 실습 네트워크에 연결합니다.

프로젝트 루트의 `config.json`을 작성하고 `Integrated/START.cmd`를 실행합니다. 설정 예시는 루트 `config_example.json`입니다. 통합 폴더 안에는 접속 설정을 복제하지 않습니다.

| 루트 설정 | 용도 |
|---|---|
| `ip`, `username`, `password`, `ssh_port` | Pi SSH 연결 |
| `ssh_host_key`, `host_name`, `mac` | 접속 대상 검증 |
| `pc_ip`, `day3_port` | 통합 HTTP 서버 주소와 포트 |
| `step_pause_seconds` | 시나리오 사이 표시 시간 |
| `ssh_connect_timeout_seconds` | SSH TCP 접속 확인 제한 시간 |
| `server_signal_timeout_seconds` | 서버 준비·게시 대기 제한 시간 |
| `http_timeout_seconds` | HTTP 요청 제한 시간 |
| `remote_command_timeout_seconds` | Pi 클라이언트 실행 제한 시간. SSH 원격 명령 전체에는 여기에 SSH 접속 제한 시간을 더해 적용 |
| `last_verified_at` | SSH 장치 확인 성공 시 갱신하는 참고 기록 |

통합 실습은 기본 8001인 `day3_port`를 공유하므로 DAY3 서버와 동시에 실행할 수 없습니다. 기존 DAY2의 `port`는 사용하지 않습니다. IP를 탐색하거나 방화벽을 변경하지 않습니다. Pi에서 설정한 PC 포트에 접근할 수 있어야 합니다.

## 전체 실습 흐름

접속과 장치 확인 → 자료 전송 → HTTP 서버 시작 → 아래 7개 시나리오 → 통합 결과 저장 → 서버 종료 순서입니다. HTTP 서버는 백그라운드에서 실행되고 요청 내역은 `server.log`에 남습니다. 실행 창에는 차량 동작과 검증 결과를 표시합니다.

| 시나리오 | 시작 상태 | 확인 결과 |
|---|---|---|
| 검증 없는 정상 업데이트 | v1으로 초기화 | 정상 v2 직접 설치, ON |
| 검증 없는 펌웨어 변조 | 앞 단계 v2 유지 | 변조 v3 직접 설치, OFF |
| 정상 보안 업데이트 | v1으로 초기화 | 정상 v2를 slot_B에 설치, ON |
| 보안 펌웨어 변조 | 정상 v2 유지 | 동일한 v3 변조를 해시 검사로 거부 |
| Manifest 변조 | 정상 v2 유지 | 서명 검사로 거부 |
| 정상 서명된 v1 제공 | 정상 v2 유지 | 버전 정책으로 거부 |
| Health 실패 업데이트 | 정상 v2 유지 | 실패 후보를 비활성 슬롯에 남기고 정상 slot_B 유지 |

두 초기화는 화면의 `[RESET]`과 결과의 `reset` 필드로 표시됩니다. 교재의 검증 없는 변조 실습은 v2를 사용하지만, 통합 실습은 동일 공격 조건 비교를 위해 두 정책 모두 v3 변조 자료를 사용합니다. 직접 설치 정책은 현재 슬롯을 덮어쓰고, 보안 정책은 비활성 슬롯에 설치한 뒤 Health가 통과해야 활성 슬롯을 바꿉니다.

시나리오마다 기대한 판단, 종료 코드, 저장된 차량 상태, 헤드램프 동작을 확인합니다. 공격 거부 세 경우는 상태 파일이 바뀌지 않아야 합니다. 복구에서는 기존 활성 펌웨어가 보존되고 실패 후보가 비활성 슬롯에 있어야 합니다. 예상한 공격 차단은 실습 성공이며, 통신 오류나 다른 원인의 실패는 실습 실패입니다. 실패하면 진행을 중단하고 결과를 저장합니다.

## 구조와 책임

| 경로 | 책임 |
|---|---|
| `Run-Lab.ps1` | 모듈을 호출해 전체 진행과 종료 조율 |
| `modules/Config.psm1` | 루트 설정 읽기와 입력 검증 |
| `modules/Ssh.psm1` | 접속 도구 검증, SSH 장치 확인, 전송과 원격 실행 |
| `modules/Runtime.psm1` | HTTP 서버 시작과 시나리오 요청·응답 대기 |
| `modules/Results.psm1` | 통합 결과 저장 |
| `server/Start-Server.ps1` | 허용된 HTTP 파일 제공과 요청 로그 |
| `server/Repository.psm1` | 원본 릴리스에서 실행 작업본 생성·변조 |
| `server/releases/` | 서명된 원본 자료 |
| `vehicle/ota_client.py` | 공통 다운로드·업데이트 흐름 |
| `vehicle/verification.py` | 서명·해시·버전 검증 |
| `vehicle/installation.py` | 직접 설치·A/B 설치·복구 |
| `vehicle/ecu.py` | 가상 차량 상태 저장과 헤드램프 관찰 |
| `scenarios/scenarios.json` | 정책·공격·초기화·기대 결과 |
| `scenarios/verify_scenario.py` | 실제 클라이언트 실행과 상태 검증 |

기존 SSH_AutoConnect, DAY2, DAY3의 실행 코드와 자료를 참조하지 않습니다. 루트 접속 설정만 공유합니다. 실습 클라이언트는 기대 결과를 읽지 않고 실제 파일 검증과 설치를 수행하며, 별도 검증기가 결과를 판정합니다.

## 결과와 재실행

- PC: `Integrated/.runtime/실행ID/result.json`, `vehicle.log`, `server.log`
- Pi: `~/ota_integrated_runs/실행ID/`의 차량 상태와 시나리오별 결과
- 원본 배포 자료는 유지하고, 변조는 실행 폴더의 `repository/` 작업본에 적용합니다.
- 다시 실행하면 새 실행 폴더를 만듭니다. 이전 실행 결과를 덮어쓰지 않습니다.
- SSH 대상 검증 성공 시 루트 설정의 `last_verified_at`을 갱신합니다. 시각은 접속 판단에 사용하지 않습니다.

실제 `config.json`에는 비밀번호가 있으므로 공유하지 않습니다. `.runtime/`, `.tools/`는 Git에서 제외됩니다. 비밀번호는 명령 인자로 직접 전달하지 않으며 임시 파일은 정상 종료와 처리된 오류 시 삭제합니다. 강제 종료 후에는 임시 파일이 남았는지 확인합니다. 서버는 지정한 PC 주소에만 바인딩하고 Pi·PC 주소의 요청만 허용합니다. 제공 파일은 Manifest, 펌웨어, 서명으로 제한합니다.

## 실습 범위와 검증

교재의 가상 ECU 동작을 재구성한 실습입니다. 실제 차량 제어, 실제 부팅 슬롯 전환이나 저장소 침입 과정은 포함하지 않습니다. 공격자는 배포 저장소를 수정할 수 있다고 가정하고 업데이트 검증과 복구 결과를 관찰합니다. 개인 서명키는 포함하지 않습니다.

개발 검증은 PC의 Python과 OpenSSL이 있는 환경에서 다음 명령으로 실행합니다. 테스트는 임시 폴더와 루프백 서버를 사용하며 실제 Pi에 접속하지 않습니다.

```cmd
python Integrated\tests\test_lab.py
powershell -NoProfile -ExecutionPolicy Bypass -File Integrated\tests\test_powershell.ps1
```

테스트는 실제 PowerShell HTTP 서버와 Python 클라이언트로 전체 시나리오를 실행하고, 허용하지 않은 파일 요청 차단, 잘못된 기대 결과 검출, 통신 실패의 오인 방지를 확인합니다. 실제 Pi의 SSH 인증·네트워크·방화벽 상태는 별도로 실제 실행에서 확인해야 합니다.

PowerShell 검증은 대체 접속 프로그램으로 공백이 있는 파일 경로 전달, 비밀번호 출력 마스킹, 원격 명령 실패·시간 초과 처리와 결과 저장을 검사합니다. 실제 접속 정보는 읽지 않습니다.
