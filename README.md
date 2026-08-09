# ⏱️ Multi-Functional Embedded Time & Sensor Subsystem

본 프로젝트는 FPGA 환경에서 복합적인 타이밍 제어 알고리즘과 센서 인터페이스 아키텍처를 하드웨어(Verilog RTL) 레벨에서 설계하고 통합한 디지털 시스템입니다. 

스톱워치 및 디지털 시계의 정밀 주파수 제어와 더불어, 초음파(HC-SR04) 및 온습도(DHT11) 센서의 독자적인 유한상태머신(FSM) 제어, 그리고 외부 PC와의 연동을 위한 UART 통신 스택을 하나의 프로세서리스(Processor-less) 탑 모듈(`top_stopwatch_watch`)에 배치하여 설계했습니다.

---

## 📌 주요 기능 (Key Features)

- **정밀 타임 도메인 프레임워크 (Stopwatch & Clock)**:
  - 시스템 클록을 100Hz(10ms) 단위로 정밀 분주하여 1/100초까지 측정하는 업/다운 스톱워치 설계.
  - 사용자 설정 모드(Time Set Mode) 진입 시, 자율 카운팅을 정지하고 시/분/초 단위를 개별 선택하여 조정할 수 있는 독립 시계 데이터패스 내장.
- **센서 인터페이스 및 하드웨어 FSM**:
  - **HC-SR04 (초음파)**: 트리거(Trigger) 펄스 생성 및 에코(Echo) 펄스의 하이 구간을 1μs 단위 카운터로 정밀 계측하여 거리를 계산하는 FSM 설계 (타이밍 최적화를 위해 나눗셈 대신 뺄셈 연산기 적용).
  - **DHT11 (온습도)**: 단선(Single-wire) 양방향 버스 제어를 위한 3상태 버퍼(Tri-state Buffer) 스위칭 기술 적용 및 타임아웃 방지용 워치독 타이머(Watchdog Timer)가 내장된 프로토콜 디코딩.
- **UART PC 오버라이드 제어 스택**:
  - 표준 9600 Baudrate 기반의 UART Rx/Tx 하드웨어 구현 및 링 버퍼 기반의 커스텀 FIFO 적용으로 데이터 유실 방지.
  - 외부 PC 키보드 명령(ASCII)으로 보드의 물리적 스위치와 입력을 대체하는 소프트웨어적 오버라이드 제어 구축.
- **다이내믹 FND 디스플레이 매니지먼트**:
  - 1kHz 프리런 타이머 기반의 타임 슬롯 스캐닝 기법으로 4자리 7-Segment(FND) 잔상 제어.
  - 4:1 멀티플렉서 배열을 통합하여 디스플레이 출력 소스(스톱워치, 시계, 거리, 온습도)를 실시간 전환.

---

## 📊 시스템 블록 다이어그램 (System Block Diagram)

전체 시스템은 탑 모듈 아래에 기능별 서브시스템들이 결합된 형태를 띠며, 서로 유기적으로 데이터를 주고받습니다.

<img width="1272" height="583" alt="image" src="https://github.com/user-attachments/assets/3f09b1e7-e42d-4aaa-9f9c-5cfe70e7f363" />

---

## 📐 하드웨어 구조 및 모듈 계층 (System Hierarchy)

```text
top_stopwatch_watch (Top-Level Module)
 ├── btn_debounce (Switch Bounce Filter)
 ├── control_unit (FSM-driven Mode Switcher)
 ├── stopwatch_datapath (Stopwatch Core Engine)
 │    └── tick_counter (msec, sec, min, hour)
 ├── clk_datapath (Clock Core Engine with Time Setter)
 │    ├── select_unit (Digit selector)
 │    └── set_counter (Adjustable counters)
 ├── sr04_ctrl_top (Ultrasound Controller)
 │    └── sr04_ctrl (Echo width counter & Divider logic)
 ├── dht11_top (Temperature/Humidity Subsystem)
 │    └── dht11_controller (Tri-state Bus control & Protocol parser)
 ├── fnd_contr (Dynamic 7-Segment Controller)
 │    ├── mux (Data multiplexers)
 │    └── bcd (7-Segment Decoder)
 └── uart_top (PC Communication Interface)
      ├── uart_rx & uart_tx (Serial transceivers)
      ├── fifo (Circular Queue buffer)
      └── ascii_decoder (PC key-to-switch translator)
```

---

## 🚦 코어 FSM 상세 분석

### 1. Central Control Unit FSM (`control_unit.v`)
스톱워치와 시계 상태를 안전하게 격리하며 제어 명령을 분배합니다. 예를 들어 시계 모드 상태에서는 스톱워치의 런/스톱 신호가 하드웨어적으로 Masking(차단) 처리되어 버튼 오동작을 미연에 방지합니다.

### 2. DHT11 단선 프로토콜 분석 FSM (`dht11_top.v`)
단일 와이어(Single-wire) 통신을 수행하기 위해 입출력 방향(Hi-Z)을 동적으로 변환하는 3상태 버퍼 구조를 갖습니다. 
또한 임베디드 통신 멈춤(Stuck) 현상을 예방하도록 하드웨어 레벨의 **Watchdog Timer**(지정된 시간 초과 시 Idle 강제 복귀)가 적용되어 안정성을 크게 높였습니다.

### 3. UART 패킷 송신 전송 포맷 스트림 (`uart_top.v`)
PC로부터 특정 요청 신호 감지 시, 내부 하드웨어의 모든 BCD 데이터를 아스키(ASCII) 코드 스트림 블록으로 래핑하여 전송합니다.
* **전송 패킷 폼**: `[시간 정보] -> \r\n -> [온도 정보] -> \r\n -> [습도 정보]`

---

## 🔌 입출력 핀 명세 (I/O Pin Specifications)

| 포트 명칭 | 방향 | 비트 폭 | 연동 디바이스 및 기능 제어 명세 |
| :--- | :---: | :---: | :--- |
| `clk` | Input | 1-bit | 시스템 메인 클록 (100MHz) |
| `reset` | Input | 1-bit | 비동기 액티브 하이 리셋 신호 |
| `mode_sw` | Input | 5-bit | 물리 슬라이드 스위치 (모드 및 디스플레이 소스 선택) |
| `btn_u/m/d`| Input | 1-bit | 조그 버튼 (Run-Stop, Next, Clear/Setting 매핑) |
| `echo / trig` | I / O | 1-bit | HC-SR04 초음파 거리 센서 입출력 |
| `dhtio` | Inout | 1-bit | DHT11 온습도 센서 데이터 인터페이스 (양방향 버스) |
| `uart_rx/tx` | I / O | 1-bit | 외부 PC 제어 및 데이터 로깅용 UART 라인 |
| `fnd_digit`| Output| 4-bit | FND 디지트 활성화 포트 (Active-Low) |
| `fnd_data` | Output| 8-bit | FND 애노드/캐소드 발광 패턴 버스 |
| `out_led` | Output| 4-bit | 구동 상태 인디케이터용 LED 바 |

