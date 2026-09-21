# Day 2 자동 OTA 실습

## 실행

프로젝트 루트의 `config_example.json`을 같은 위치의 `config.json`으로 복사해 접속 정보를 채운 뒤 `START.cmd`를 더블클릭합니다. 최초 실행에서는 공식 Plink 0.85를 다운로드하고 SHA-256을 검증합니다. Windows 10/11의 64비트 환경과 PowerShell 5.1을 사용하며, 별도 Python 설치는 PC에 필요하지 않습니다.

- A 창: Windows OTA 서버 초기화, 파일 요청 로그, 펌웨어 변조, 서버 종료.
- B 창: Pi 접속, 장치 확인, 파일 준비, 정상 OTA, 변조 OTA, 결과 검증.

설정이 맞으면 추가 입력 없이 끝까지 진행됩니다. 완료 후 결과를 볼 수 있도록 두 창은 남고 HTTP 서버는 중지됩니다. 각 창에서 Enter를 누르면 닫힙니다. 창을 닫은 후에도 `START.cmd`로 다시 시작할 수 있습니다.

## 설정

| 필드 | 입력 내용 |
|---|---|
| `host_name` | Pi의 실제 호스트 이름. 로그인 후 일치 여부를 확인합니다. |
| `username` | Pi 로그인 계정 |
| `password` | Pi 비밀번호 |
| `mac` | Pi의 Wi-Fi 또는 유선 MAC 주소. 로그인 후 일치 여부를 확인합니다. |
| `ip` | 접속할 Pi IPv4 |
| `pc_ip` | Pi에서 접속할 Windows PC IPv4 |
| `ssh_host_key` | 최초 SSH 접속에서 확인한 장치 지문. `SHA256:`으로 시작하는 값을 입력합니다. |
| `port` | 교재의 Day 2 포트인 `8000` |
| `step_pause_seconds` | 화면을 읽을 수 있도록 단계 사이에 기다리는 시간. 기본 4초. |
| `last_verified_at` | 마지막 SSH 로그인 및 장치 정보 검증 성공 시각. 시간대가 포함됩니다. |

IP와 MAC은 설정 파일에서 읽습니다. IP 자동 탐색이나 자동 변경을 하지 않습니다. 주소가 달라지면 오류 메시지를 확인한 후 설정을 수정합니다. `last_verified_at`은 사람이나 AI가 디버깅할 때 참고하는 기록이며 실행 조건이나 접속 대상 선택에 사용하지 않습니다. 전체 OTA 성공 여부는 별도 실행 결과에서 확인합니다.

## 실습 순서와 결과

1. 저장된 IP로 SSH 로그인하고 호스트 이름, 계정, IP, MAC, Python을 확인합니다.
2. 별도 Pi 실행 폴더에 교재의 Day 2 파일을 배치하고 PC 주소를 설정합니다.
3. 차량을 v1.0 / NORMAL / ON으로 초기화합니다.
4. 정상 v2.0 펌웨어를 HTTP로 받아 설치하고 NORMAL / ON을 확인합니다.
5. 차량을 v1.0으로 되돌리고 서버의 펌웨어만 FORCE_HEADLAMP_OFF로 변조합니다. Manifest가 그대로인지 확인합니다.
6. 다시 OTA를 실행해 v2.0 / FORCE_HEADLAMP_OFF / OFF를 확인합니다.
7. 두 경우 모두 설치가 ACCEPTED이고 보안 검사가 NONE인 결과를 비교합니다.

실제 차량이나 하드웨어 헤드램프를 제어하지 않으며 교재의 가상 ECU 프로그램을 사용합니다. 각 실행은 Pi의 `~/ota_day2_runs/실행ID`와 PC의 `.runtime/실행ID`에 독립적으로 보관됩니다. 기존 수동 실습 폴더는 변경하지 않습니다. 최종 실행 폴더에는 변조 OTA 결과가 남습니다.

## 오류와 재실행

| 오류 | 조치 |
|---|---|
| 설정 누락, IP 형식 오류 | `config.json` 수정 |
| PC 주소 불일치 | `ipconfig`로 확인해 `pc_ip` 수정 |
| SSH 연결·인증 실패 | Pi 전원과 `ip`, `username`, `password`, `ssh_host_key` 확인 |
| 호스트 이름 또는 MAC 불일치 | 접속 대상과 설정 확인 |
| 8000 포트 사용 중 | 기존 실습 서버를 종료한 뒤 다시 실행. 다른 프로세스는 자동 종료하지 않습니다. |
| HTTP 다운로드 실패 | A 서버 창, PC 주소, 같은 LAN 연결, Windows 방화벽의 TCP 8000 허용 확인 |
| 실습이 이미 실행 중 | 실행 중인 B 창 종료 후 다시 실행 |

방화벽은 자동으로 변경하지 않습니다. 이 도구의 서버는 설정한 PC IP에 바인딩하고, 설정한 Pi/PC IP에서 오는 두 실습 JSON 파일 요청만 처리합니다. 실패하면 다음 실습으로 넘어가지 않고 오류를 표시합니다. B 창을 강제로 닫아도 A 서버는 소유 프로세스 종료를 확인해 중지합니다.

## 로컬 파일과 Git

프로젝트 루트의 `config.json`에는 비밀번호가 평문으로 저장됩니다. 해당 파일, `.runtime/`의 로그·결과·임시 파일, `.tools/`의 실행 파일은 `.gitignore`로 제외합니다. 비밀번호는 명령줄이나 로그에 출력하지 않고 임시 비밀번호 파일을 통해 Plink에 전달하며, 정상 종료나 처리된 오류에서는 임시 파일을 삭제합니다. B 창 강제 종료 시 임시 파일이 남을 수 있으므로 전체 폴더를 ZIP으로 공유하기 전에는 `.runtime/`과 `config.json`을 제외하세요.

Git에 포함되는 예시 설정은 실제 계정 정보를 담지 않습니다. 실행 결과는 `.runtime/실행ID/result.json`, A 로그는 `server.log`, B 로그는 `vehicle.log`에서 확인합니다.

## 자료

`lab/`에는 제공된 Raspberry Pi OTA 실습 자료 중 Day 2에 필요한 파일만 포함합니다. 서버의 초기 JSON과 차량 클라이언트·상태·동작 프로그램은 교재 자료를 사용하며, Windows 서버와 실행 순서 제어는 자동 실습용입니다. 공개 배포 시 교재 자료의 배포 권한을 확인하세요.

- [Plink 공식 다운로드](https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html)
- [Plink 공식 설명서](https://the.earth.li/~sgtatham/putty/0.85/htmldoc/Chapter7.html)
