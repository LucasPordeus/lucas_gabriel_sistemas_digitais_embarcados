# Makefile - Semaforo Inteligente ARM+FPGA (TP4)
# Uso:
#   make sim         -> roda TODOS os testbenches Verilog (Icarus Verilog)
#   make sim-<nome>   -> roda um testbench especifico (ex.: make sim-fsm_semaforo)
#   make asm          -> monta e linka todos os programas Assembly (aarch64)
#   make run-asm      -> executa todos os binarios Assembly nativamente na Raspberry Pi
#   make objdump-<bin> -> mostra o disassembly de um binario Assembly (uso de objdump)
#   make clean        -> remove artefatos gerados

AS      = as
LD      = ld
OBJDUMP = objdump
GDB     = gdb
BUILD   = build

SIM_TARGETS = tp1_decoder debounce sensor_veiculo botao_pedestre contador_tempo fsm_semaforo protocolo_paralelo bram_historico media_movel_dsp
ASM_TARGETS = tp1_fluxo_basico tp2_polling_contagem gpio_map tp3_controle_fluxo tp4_numerico tp4_neon_simd

.PHONY: sim asm run-asm clean $(addprefix sim-,$(SIM_TARGETS))

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

asm: $(addprefix $(BUILD)/,$(ASM_TARGETS))

$(BUILD)/%.o: asm/%.s
	mkdir -p $(BUILD)
	$(AS) -g -o $@ $<

$(BUILD)/%: $(BUILD)/%.o
	$(LD) -o $@ $<

run-asm: asm
	@for bin in $(ASM_TARGETS); do \
		echo "--- $$bin ---"; \
		$(BUILD)/$$bin; \
	done

objdump-%: $(BUILD)/%
	$(OBJDUMP) -d $(BUILD)/$*

clean:
	rm -rf $(BUILD) *.vcd
