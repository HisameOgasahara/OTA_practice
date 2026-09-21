# Raspberry Pi OTA 실습 환경

| 항목 | 환경 |
|---|---|
| Windows PC | Windows 10/11 64비트, Windows PowerShell 5.1 |
| Raspberry Pi | Raspberry Pi 5, Raspberry Pi OS 64비트, Python 3 |
| 저장장치 | microSD 32GB 이상 권장 |
| 네트워크 | PC와 Pi가 같은 Wi-Fi 또는 LAN에 연결 |
| SSH | Pi에서 활성화, 사용자 계정과 비밀번호 설정 |
| Day 3 서버 | Windows PC TCP 8001 기본값, 루트 `day3_port`로 변경 |
| Day 2 서버 | 루트 설정의 `port`는 DAY2용이며 `8000` 고정. Pi에서 접근 가능하도록 Windows PC TCP 8000 방화벽 허용 |
| 접속 설정 | 루트 `config_example.json`을 `config.json`으로 복사해 작성. 실제 설정은 Git 제외 |

`SSH_AutoConnect`, `DAY2`, `DAY3`, `Integrated`는 같은 루트 `config.json`을 읽습니다. `DAY3/START.cmd`는 교재의 Secure OTA 5개 시나리오를 자동 실행합니다. `Integrated`는 SSH 자동접속과 DAY2·DAY3의 실습을 한 번에 실행하는 통합 폴더입니다. 통합 코드 안에서 공통 기능의 중복을 줄이고 접속·서버·업데이트 검증 등의 책임을 분리했으며, 기존 개별 실습 폴더는 유지합니다. IP 자동 탐색 없이 설정된 주소로 접속하며, `last_verified_at`은 마지막 접속 정보 검증 시각을 기록하는 참고 필드입니다.

## IP 확인과 설정 갱신

PC와 Pi의 IP는 재부팅, Wi-Fi 변경, 공유기의 주소 재할당 등으로 바뀔 수 있습니다. 실습 전이나 접속 오류가 발생했을 때 현재 주소를 확인하세요. Windows에서는 `ipconfig`, Pi에서는 `hostname -I`로 확인할 수 있습니다. Pi에 접속할 수 없다면 공유기의 연결 장치 목록 등에서 Pi 주소를 확인합니다.

현재 주소와 접속 대상을 확인·확정한 뒤 루트 `config.json`의 `ip`(Pi)와 `pc_ip`(Windows)를 수정하고, 확인 날짜·시각 필드인 `last_verified_at`도 갱신하세요. 예: `2026-09-21T14:00:00+09:00`. 주소를 추측해 입력한 상태에서는 검증 시각을 갱신하지 않습니다.

SSH 자동접속, DAY2, DAY3, Integrated는 로그인 후 장치 이름·계정·MAC 검증에 성공하면 `last_verified_at`을 자동 갱신합니다. 이 필드는 사람이나 AI의 디버깅 참고용이며, 프로그램은 날짜를 기준으로 접속 여부를 판단하거나 IP를 자동 탐색하지 않습니다.

## 참조 문서

- [Microsoft Windows OpenSSH 안내](https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse)
- [mDNS 표준 RFC 6762](https://www.rfc-editor.org/info/rfc6762/)
- [PuTTY / Plink 공식 다운로드](https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html)

## 실행 방법

루트 `config_example.json`을 `config.json`으로 복사해 접속 정보를 작성한 뒤 원하는 파일을 더블클릭합니다.

| 구분 | 실행 파일 | 실행 결과 |
|---|---|---|
| SSH 자동접속 | [SSH_AutoConnect/START.cmd](SSH_AutoConnect/START.cmd) | Pi에 자동 로그인하고 명령 입력 창을 유지합니다. 종료는 `exit`입니다. |
| DAY2 | [DAY2/START.cmd](DAY2/START.cmd) | 정상 OTA와 변조 OTA를 자동 실행하고 결과를 A/B 창에 표시합니다. |
| DAY3 | [DAY3/START.cmd](DAY3/START.cmd) | 정상 Secure OTA, 변조 차단, 구버전 차단, A/B 복구를 자동 실행하고 결과를 A/B 창에 표시합니다. |
| Integrated | [Integrated/START.cmd](Integrated/START.cmd) | SSH 준비부터 검증 없는 OTA·공격 차단·A/B 복구까지 통합 실행합니다. |

DAY2와 DAY3는 SSH 접속까지 자동으로 진행합니다. 완료 후 각 창에서 Enter를 누르면 닫힙니다.

Integrated는 루트 `day3_port`를 사용하므로 DAY3 서버를 종료한 뒤 실행합니다. 서버는 백그라운드에서 동작하고 결과는 실행 창과 `Integrated/.runtime/`에 남습니다. 상세 구조와 시나리오는 [Integrated 가이드](Integrated/Integrated_guide.md)를 참고하세요.
