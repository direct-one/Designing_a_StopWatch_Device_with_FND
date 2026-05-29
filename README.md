# ⏱️ Multi-Functional Embedded Time & Sensor Subsystem

본 프로젝트는 FPGA/MCU 환경에서 복합적인 타이밍 제어 알고리즘과 센서 인터페이스 아키텍처를 하드웨어(Verilog RTL) 레벨에서 설계하고 통합한 디지털 시스템입니다. 

스톱워치 및 디지털시계의 정밀 주파수 분주 제어와 더불어, 초음파(HC-SR04) 및 온습도(DHT11) 센서의 독자적인 유한상태머신(FSM) 제어, 그리고 외부 PC와의 연동을 위한 UART 통신 스택을 하나의 프로세서리스(Processor-less) 탑 모듈에 온전하게 모듈화하여 배치했습니다.

---

## 📌 주요 기능 (Key Features)

- **정밀 타임 도메인 프레임워크 (Stopwatch & Clock)**:
  - 시스템 클록을 $100\text{Hz}$($10\text{ms}$) 단위로 정밀 분주하여 $1/100$초까지 측정하는 업/다운 스톱워치 데이터패스 구축.
  - 사용자 설정 모드(Time Set Mode) 진입 시, 자율 카운팅을 정지하고 시/분/초 단위를 개별 선택하여 조정할 수 있는 독립 시계 데이터패스 내장.
- **센서 인터페이스 및 하드웨어 FSM**:
  - **HC-SR04 (초음파)**: 트리거 신호 생성 및 에코(Echo) 펄스의 하이 구간을 $1\mu\text{s}$ 단위 카운터로 정밀 계측 후, 타이밍 성능 최적화(Negative Slack 방지)를 위해 나눗셈 대신 뺄셈 연산 가속기를 적용한 거리 변환 FSM 설계.
  - **DHT11 (온습도)**: 단선(Single-wire) 양방향 버스 제어를 위한 3상태 버퍼(Tri-state Buffer) 스위칭 및 타임아웃 방지용 워치독 타이머(Watchdog Timer)가 내장된 프로토콜 디코딩 FSM 설계.
- **UART PC 오버라이드 제어 스택**:
  - 표준 9600 Baudrate 기반의 UART Rx/Tx 하드웨어 매크로 구현.
  - 링 버퍼 기반의 커스텀 FIFO를 통해 데이터 유실을 방지하고, ASCII 디코더를 매핑하여 외부 PC 키보드 명령('M', '0'~'4')으로 보드의 물리적 스위치와 입력 동작을 완전히 소프트웨어적으로 오버라이드 제어하는 모드 구축.
- **다이내믹 FND 디스플레이 매니지먼트**:
  - $1\text{kHz}$ 프리런 타이머 및 디코더를 조합한 타임 슬롯 스캐닝 기법으로 4자리 7-Segment(FND) 잔상 제어.
  - 스톱워치, 시계, 거리, 온습도 중 메인 화면을 결정하는 4:1 고속 멀티플렉서 배열 통합.

---

## 📐 하드웨어 구조 및 모듈 계층 (System Hierarchy)

시스템 전체 모듈은 계층형 구조로 결합되어 있으며, 탑 모듈(`top_stopwatch_watch`)을 중심으로 주변장치 및 데이터패스가 밀결합되어 상호 연동됩니다.

```text
top_stopwatch_watch (Top-Level Module)
 ├── btn_debounce (U_BTN_U, U_BTN_D, U_BTN_M, U_SR04_BTN, U_DHT11_BTN)
 ├── control_unit (FSM-driven Central Operation Mode Switcher)
 ├── stopwatch_datapath (Stopwatch Core Engine)
 │    └── tick_counter (msec, sec, min, hour sub-counters)
 ├── clk_datapath (Clock Core Engine with Time Setter)
 │    ├── select_unit (Digit selector)
 │    └── set_counter (MSEC, SEC, MIN, HOUR adjustable counters)
 ├── sr04_ctrl_top (HC-SR04 Ultrasound Controller Subsystem)
 │    ├── tick_gen_1us
 │    └── sr04_ctrl (Echo width counter & Divider logic)
 ├── dht11_top (DHT11 Temperature/Humidity Sensor Subsystem)
 │    └── dht11_controller (Tri-state Bus control & Protocol parser)
 │         └── tick_gen_10us
 ├── fnd_contr (Dynamic 7-Segment Display Controller)
 │    ├── mux_4x1_set & mux_8x1 & mux_2x1 (Data multiplexers)
 │    ├── clk_div (1kHz refresh driver) & counter8 & decoder2x4
 │    └── bcd (7-Segment Anode/Cathode decoder)
 └── uart_top (PC Communication Interface)
      ├── baud_tick (9600 Baudrate clock gen)
      ├── uart_rx & uart_tx (Serial transceivers)
      ├── fifo (Circular Queue buffer for Tx protection)
      ├── ascii_decoder (PC key-to-switch translator)
      └── uart_time_sender (Data serialization packet stream formatter)
```

---

## 🚦 모드별 레지스터 및 데이터패스 명세

### 1. Central Control Unit FSM (`control_unit.v`)
스톱워치와 시계 상태를 안전하게 격리하며 제어 명령을 디스패치합니다. 시계 모드(`clock_mode = 1`) 상태에서는 스톱워치 런/스톱 신호가 하드웨어적으로 마스크(Mask) 처리되어 오동작을 미연에 방지합니다.

```verilog
// control_unit.v FSM 핵심 설계 레벨
always @(*) begin
    n_state = c_state;
    o_run_stop = 1'b0;
    o_clear = 1'b0;
    case (c_state)
        STOP:  if (sw_runstop_in) n_state = RUN;
               else if (sw_clear_in) n_state = CLEAR;
        RUN:   begin o_run_stop = 1'b1; if (sw_runstop_in) n_state = STOP; end
        CLEAR: begin o_clear = 1'b1; n_state = STOP; end
    endcase
end
```

### 2. DHT11 단선 프로토콜 분석 FSM (`dht11_top.v`)
단일 와이어를 통해 데이터를 정밀하게 파싱하기 위해 입출력 방향(Hi-Z 체계)을 동적으로 전전하는 FSM 구조입니다. 임베디드 오동작으로 인한 시스템 가동 중지(Stuck) 현상을 예방하도록 하드웨어 워치독 타이머가 기저단에서 지속 감시합니다.

```verilog
// Tri-state Buffer 할당 스펙
assign dhtio = (io_sel_reg) ? dhtio_reg : 1'bz;

// Watchdog Timer에 의한 데드락 방지 로직 (999ms 이상 비정상 지연 시 강제 복귀)
if (c_state != IDLE && timeout_rst_reg >= 17'd99_999) begin
    n_state = IDLE;
    dhtio_next = 1'b1;
    io_sel_next = 1'b1;
end
```

### 3. UART 패킷 송신 전송 포맷 스트림 (`uart_top.v`)
외부 PC 요청 신호(`s` 키 수신) 감지 시, 하드웨어 내에서 가공된 모든 BCD 데이터를 아스키(ASCII) 코드 스트림 블록으로 변환하여 순차 패킷 전송을 실행합니다.

* **전송 스트림 레이아웃 규격**:
  $$\text{시간 정보} \rightarrow \text{CRLF}(\backslash\text{r}\backslash\text{n}) \rightarrow \text{온도 정보} \rightarrow \text{CRLF} \rightarrow \text{습도 정보} \rightarrow \text{CRLF}$$

```verilog
// 내부 메시지 구조 버퍼 매핑 명세
msg[0]  = 8'h30 + h10;       // Hour 10의 자리
msg[1]  = 8'h30 + h1;        // Hour 1의 자리
msg[2]  = 8'h3A;             // ':' 구분자 기호
// ... (중략) ...
msg[13] = 8'h54;             // 'T' (Temperature Label)
msg[22] = 8'h48;             // 'H' (Humidity Label)
```

---

## 🔌 입출력 인터페이스 핀 사양 (I/O Pin Specifications)

| 포트 명칭 (Port Name) | 방향 (Direction) | 비트 폭 (Width) | 연동 디바이스 및 기능 제어 명세 |
| :--- | :---: | :---: | :--- |
| `clk` | Input | 1비트 | 시스템 메인 시스템 마스터 클록 ($100\text{MHz}$) |
| `reset` | Input | 1비트 | 하드웨어 비동기 액티브 하이 리셋 신호 |
| `mode_sw` | Input | 5비트 | 보드 물리 슬라이드 스위치 (모드 및 디스플레이 선택용) |
| `btn_u`, `btn_m`, `btn_d` | Input | 1비트 | 조그 버튼 입력 (Run-Stop, Next, Clear/Setting 매핑) |
| `echo` / `trigger` | I / O | 1비트 | HC-SR04 초음파 거리 센서 반사 파형 입출력 포트 |
| `dhtio` | Inout | 1비트 | DHT11 온습도 센서 데이터 인터페이스 싱글 와이어 버스 |
| `uart_rx` / `uart_tx` | I / O | 1비트 | 외부 제어 전송용 전이중(Full-Duplex) 시리얼 통신 라인 |
| `fnd_digit` | Output | 4비트 | 4자리 공통 디지트 활성화 선택 포트 (Active-Low) |
| `fnd_data` | Output | 8비트 | 7-Segment 애노드/캐소드 발광 데이터 패턴 버스 ($a \sim g, dp$) |
| `out_led` | Output | 4비트 | 현재 구동 상태 모드 인디케이터용 LED 바 |

---

## 전체 시스템 Block Diagram (System Overview Block Diagram)
<img width="1792" height="980" alt="image" src="https://github.com/user-attachments/assets/98a7a4af-0507-4948-9326-552c1b4e78c4" />

- **System Overview** 

