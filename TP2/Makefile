# Makefile - Semaforo Inteligente ARM+FPGA (TP2)
# Uso:
#   make sim         -> roda TODOS os testbenches Verilog (Icarus Verilog)
#   make sim-<nome>   -> roda um testbench especifico (ex.: make sim-debounce)
#   make asm          -> monta e linka todos os programas Assembly (aarch64)
#   make run-asm      -> executa todos os binarios Assembly nativamente na Raspberry Pi
#   make clean        -> remove artefatos gerados

AS      = as
LD      = ld
OBJDUMP = objdump
BUILD   = build

# pares (testbench : modulos rtl adicionais necessarios, alem do proprio nome)
SIM_TARGETS = tp1_decoder debounce sensor_veiculo botao_pedestre
ASM_TARGETS = tp1_fluxo_basico tp2_polling_contagem

.PHONY: sim asm run-asm clean $(addprefix sim-,$(SIM_TARGETS))

sim: $(addprefix sim-,$(SIM_TARGETS))

sim-tp1_decoder: $(BUILD)/tp1_decoder.vvp
	vvp $(BUILD)/tp1_decoder.vvp

$(BUILD)/tp1_decoder.vvp: rtl/estado_basico_decoder.v tb/tb_estado_basico_decoder.v
	mkdir -p $(BUILD)
	iverilog -g2012 -o $@ $^

sim-debounce: $(BUILD)/debounce.vvp
	vvp $(BUILD)/debounce.vvp

$(BUILD)/debounce.vvp: rtl/debounce.v tb/tb_debounce.v
	mkdir -p $(BUILD)
	iverilog -g2012 -o $@ $^

sim-sensor_veiculo: $(BUILD)/sensor_veiculo.vvp
	vvp $(BUILD)/sensor_veiculo.vvp

$(BUILD)/sensor_veiculo.vvp: rtl/debounce.v rtl/sensor_veiculo.v tb/tb_sensor_veiculo.v
	mkdir -p $(BUILD)
	iverilog -g2012 -o $@ $^

sim-botao_pedestre: $(BUILD)/botao_pedestre.vvp
	vvp $(BUILD)/botao_pedestre.vvp

$(BUILD)/botao_pedestre.vvp: rtl/debounce.v rtl/botao_pedestre.v tb/tb_botao_pedestre.v
	mkdir -p $(BUILD)
	iverilog -g2012 -o $@ $^

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

clean:
	rm -rf $(BUILD) *.vcd
