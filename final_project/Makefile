# Makefile - Semaforo Inteligente ARM+FPGA (TP5 / final_project)
# Uso:
#   make sim          -> roda TODOS os testbenches Verilog (Icarus Verilog)
#   make sim-<nome>    -> roda um testbench especifico (ex.: make sim-top_semaforo)
#   make lib           -> monta a biblioteca estatica libembarcado.a
#   make asm           -> monta e linka os programas Assembly (usa a lib quando necessario)
#   make run-asm       -> executa todos os binarios Assembly nativamente na Raspberry Pi
#   make objdump-<bin> -> mostra o disassembly de um binario Assembly
#   make clean         -> remove artefatos gerados

AS      = as
LD      = ld
AR      = ar
OBJDUMP = objdump
GDB     = gdb
BUILD   = build

SIM_TARGETS = tp1_decoder debounce sensor_veiculo botao_pedestre contador_tempo \
              fsm_semaforo protocolo_paralelo bram_historico media_movel_dsp \
              protocolo_serial top_semaforo
ASM_STANDALONE = tp1_fluxo_basico tp2_polling_contagem gpio_map tp3_controle_fluxo tp4_numerico tp4_neon_simd
ASM_COM_LIB    = test_lib main_tp5 monitor_semaforo monitor_semaforo_hw
LIB_OBJS = $(BUILD)/lib/gpio_lib.o $(BUILD)/lib/strings_lib.o $(BUILD)/lib/buffer_lib.o $(BUILD)/lib/protocolo_serial_gpio.o

.PHONY: sim asm lib run-asm clean $(addprefix sim-,$(SIM_TARGETS))

sim: $(addprefix sim-,$(SIM_TARGETS))

sim-tp1_decoder: $(BUILD)/tp1_decoder.vvp
	vvp $(BUILD)/tp1_decoder.vvp
$(BUILD)/tp1_decoder.vvp: rtl/estado_basico_decoder.v tb/tb_estado_basico_decoder.v
	mkdir -p $(BUILD); iverilog -g2012 -o $@ $^

sim-debounce: $(BUILD)/debounce.vvp
	vvp $(BUILD)/debounce.vvp
$(BUILD)/debounce.vvp: rtl/debounce.v tb/tb_debounce.v
	mkdir -p $(BUILD); iverilog -g2012 -o $@ $^

sim-sensor_veiculo: $(BUILD)/sensor_veiculo.vvp
	vvp $(BUILD)/sensor_veiculo.vvp
$(BUILD)/sensor_veiculo.vvp: rtl/debounce.v rtl/sensor_veiculo.v tb/tb_sensor_veiculo.v
	mkdir -p $(BUILD); iverilog -g2012 -o $@ $^

sim-botao_pedestre: $(BUILD)/botao_pedestre.vvp
	vvp $(BUILD)/botao_pedestre.vvp
$(BUILD)/botao_pedestre.vvp: rtl/debounce.v rtl/botao_pedestre.v tb/tb_botao_pedestre.v
	mkdir -p $(BUILD); iverilog -g2012 -o $@ $^

sim-contador_tempo: $(BUILD)/contador_tempo.vvp
	vvp $(BUILD)/contador_tempo.vvp
$(BUILD)/contador_tempo.vvp: rtl/contador_tempo.v tb/tb_contador_tempo.v
	mkdir -p $(BUILD); iverilog -g2012 -o $@ $^

sim-fsm_semaforo: $(BUILD)/fsm_semaforo.vvp
	vvp $(BUILD)/fsm_semaforo.vvp
$(BUILD)/fsm_semaforo.vvp: rtl/contador_tempo.v rtl/fsm_semaforo.v tb/tb_fsm_semaforo.v
	mkdir -p $(BUILD); iverilog -g2012 -o $@ $^

sim-protocolo_paralelo: $(BUILD)/protocolo_paralelo.vvp
	vvp $(BUILD)/protocolo_paralelo.vvp
$(BUILD)/protocolo_paralelo.vvp: rtl/protocolo_paralelo.v tb/tb_protocolo_paralelo.v
	mkdir -p $(BUILD); iverilog -g2012 -o $@ $^

sim-bram_historico: $(BUILD)/bram_historico.vvp
	vvp $(BUILD)/bram_historico.vvp
$(BUILD)/bram_historico.vvp: rtl/bram_historico.v tb/tb_bram_historico.v
	mkdir -p $(BUILD); iverilog -g2012 -o $@ $^

sim-media_movel_dsp: $(BUILD)/media_movel_dsp.vvp
	vvp $(BUILD)/media_movel_dsp.vvp
$(BUILD)/media_movel_dsp.vvp: rtl/media_movel_dsp.v tb/tb_media_movel_dsp.v
	mkdir -p $(BUILD); iverilog -g2012 -o $@ $^

sim-protocolo_serial: $(BUILD)/protocolo_serial.vvp
	vvp $(BUILD)/protocolo_serial.vvp
$(BUILD)/protocolo_serial.vvp: rtl/protocolo_serial.v tb/tb_protocolo_serial.v
	mkdir -p $(BUILD); iverilog -g2012 -o $@ $^

sim-top_semaforo: $(BUILD)/top_semaforo.vvp
	vvp $(BUILD)/top_semaforo.vvp
$(BUILD)/top_semaforo.vvp: rtl/debounce.v rtl/sensor_veiculo.v rtl/botao_pedestre.v \
                           rtl/contador_tempo.v rtl/fsm_semaforo.v rtl/estado_basico_decoder.v \
                           rtl/bram_historico.v rtl/media_movel_dsp.v rtl/protocolo_serial.v \
                           rtl/top_semaforo.v tb/tb_top_semaforo.v
	mkdir -p $(BUILD); iverilog -g2012 -o $@ $^

lib: $(BUILD)/lib/libembarcado.a

$(BUILD)/lib/%.o: asm/lib/%.s
	mkdir -p $(BUILD)/lib
	$(AS) -g -o $@ $<

$(BUILD)/lib/libembarcado.a: $(LIB_OBJS)
	$(AR) rcs $@ $(LIB_OBJS)

asm: $(addprefix $(BUILD)/,$(ASM_STANDALONE)) $(addprefix $(BUILD)/,$(ASM_COM_LIB))

$(BUILD)/%.o: asm/%.s
	mkdir -p $(BUILD)
	$(AS) -g -o $@ $<

$(BUILD)/tp1_fluxo_basico: $(BUILD)/tp1_fluxo_basico.o
	$(LD) -o $@ $<
$(BUILD)/tp2_polling_contagem: $(BUILD)/tp2_polling_contagem.o
	$(LD) -o $@ $<
$(BUILD)/gpio_map: $(BUILD)/gpio_map.o
	$(LD) -o $@ $<
$(BUILD)/tp3_controle_fluxo: $(BUILD)/tp3_controle_fluxo.o
	$(LD) -o $@ $<
$(BUILD)/tp4_numerico: $(BUILD)/tp4_numerico.o
	$(LD) -o $@ $<
$(BUILD)/tp4_neon_simd: $(BUILD)/tp4_neon_simd.o
	$(LD) -o $@ $<

$(BUILD)/test_lib: $(BUILD)/test_lib.o $(BUILD)/lib/libembarcado.a
	$(LD) -o $@ $(BUILD)/test_lib.o $(BUILD)/lib/libembarcado.a
$(BUILD)/main_tp5: $(BUILD)/main_tp5.o $(BUILD)/lib/libembarcado.a
	$(LD) -o $@ $(BUILD)/main_tp5.o $(BUILD)/lib/libembarcado.a
$(BUILD)/monitor_semaforo: $(BUILD)/monitor_semaforo.o $(BUILD)/lib/libembarcado.a
	$(LD) -o $@ $(BUILD)/monitor_semaforo.o $(BUILD)/lib/libembarcado.a
$(BUILD)/monitor_semaforo_hw: $(BUILD)/monitor_semaforo_hw.o $(BUILD)/lib/libembarcado.a
	$(LD) -o $@ $(BUILD)/monitor_semaforo_hw.o $(BUILD)/lib/libembarcado.a

run-asm: asm
	@for bin in $(ASM_STANDALONE) $(ASM_COM_LIB); do \
		echo "--- $$bin ---"; \
		$(BUILD)/$$bin; \
	done

objdump-%: $(BUILD)/%
	$(OBJDUMP) -d $(BUILD)/$*

clean:
	rm -rf $(BUILD) *.vcd
