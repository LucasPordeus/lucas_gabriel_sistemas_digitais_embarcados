# Makefile - Semaforo inteligente (Tang Nano 4K + Raspberry Pi)
#
#   make sim             roda todos os testbenches (Icarus Verilog)
#   make sim-<modulo>    roda um testbench (ex.: make sim-top_semaforo)
#   make synth           sintese + place&route + bitstream com Yosys/nextpnr/Apicula
#                        (alternativa: Gowin EDA com rtl/*.v e constraints/*)
#   make asm             monta o monitor da Raspberry Pi (build/monitor_semaforo)
#   make run             executa o monitor (precisa de sudo na Raspberry Pi)
#   make clean           apaga build/
#
# Para montar o Assembly fora da Raspberry Pi (cross):
#   make asm AS=aarch64-linux-gnu-as LD=aarch64-linux-gnu-ld AR=aarch64-linux-gnu-ar

AS    ?= as
LD    ?= ld
AR    ?= ar
BUILD  = build

# --- Verilog ---
RTL = rtl/debounce.v rtl/sensor_veiculo.v rtl/botao_pedestre.v rtl/prescaler.v \
      rtl/contador_tempo.v rtl/fsm_semaforo.v rtl/estado_basico_decoder.v \
      rtl/bram_historico.v rtl/media_movel_dsp.v rtl/protocolo_serial.v rtl/top_semaforo.v
TESTES = debounce sensor_veiculo botao_pedestre contador_tempo estado_basico_decoder \
         bram_historico media_movel_dsp protocolo_serial fsm_semaforo top_semaforo

.PHONY: sim synth asm run clean

sim:
	@for t in $(TESTES); do $(MAKE) --no-print-directory sim-$$t || exit 1; done

# cada testbench compila com todo o RTL (o iverilog so' elabora o que o tb usa);
# o tb vem primeiro para que seu `timescale valha tambem para o RTL
sim-%: tb/tb_%.v $(RTL)
	@mkdir -p $(BUILD)
	@echo "=== tb_$* ==="
	iverilog -g2012 -Wall -Wno-timescale -o $(BUILD)/tb_$*.vvp -s tb_$* tb/tb_$*.v $(RTL)
	vvp -n $(BUILD)/tb_$*.vvp

# --- Sintese (fluxo aberto) ---
DEVICE = GW1NSR-LV4CQN48PC7/I6
FAMILY = GW1NS-4

synth: $(BUILD)/top_semaforo.fs

$(BUILD)/top_semaforo.json: $(RTL)
	@mkdir -p $(BUILD)
	yosys -q -l $(BUILD)/yosys.log -p "read_verilog $(RTL); synth_gowin -top top_semaforo -json $@"

$(BUILD)/top_semaforo_pnr.json: $(BUILD)/top_semaforo.json constraints/tangnano4k.cst
	nextpnr-himbaechel --device $(DEVICE) --vopt family=$(FAMILY) \
	    --vopt cst=constraints/tangnano4k.cst --freq 27 --json $< --write $@

$(BUILD)/top_semaforo.fs: $(BUILD)/top_semaforo_pnr.json
	gowin_pack -d $(FAMILY) -o $@ $<

# --- Assembly ARM64 (Raspberry Pi) ---
LIB_OBJS = $(BUILD)/lib/gpio_lib.o $(BUILD)/lib/strings_lib.o \
           $(BUILD)/lib/protocolo_serial_gpio.o $(BUILD)/lib/telemetria.o

asm: $(BUILD)/monitor_semaforo

$(BUILD)/lib/%.o: asm/lib/%.s
	@mkdir -p $(BUILD)/lib
	$(AS) -g -o $@ $<

$(BUILD)/lib/libembarcado.a: $(LIB_OBJS)
	$(AR) rcs $@ $^

$(BUILD)/monitor_semaforo.o: asm/monitor_semaforo.s
	@mkdir -p $(BUILD)
	$(AS) -g -o $@ $<

$(BUILD)/monitor_semaforo: $(BUILD)/monitor_semaforo.o $(BUILD)/lib/libembarcado.a
	$(LD) -o $@ $^

run: $(BUILD)/monitor_semaforo
	sudo ./$(BUILD)/monitor_semaforo

clean:
	rm -rf $(BUILD)
