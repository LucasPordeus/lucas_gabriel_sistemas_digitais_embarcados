# Makefile - Semaforo Inteligente ARM+FPGA
# Uso:
#   make sim        -> roda todos os testbenches Verilog (Icarus Verilog)
#   make asm         -> monta e linka todos os programas Assembly (aarch64)
#   make run-asm     -> executa os binarios Assembly montados nativamente na Raspberry Pi
#   make clean       -> remove artefatos gerados

AS      = as
LD      = ld
OBJDUMP = objdump

BUILD   = build

RTL_TB_PAIRS = tp1_decoder

.PHONY: sim asm run-asm clean

sim: $(BUILD)/tp1_decoder.vvp
	vvp $(BUILD)/tp1_decoder.vvp

$(BUILD)/tp1_decoder.vvp: rtl/estado_basico_decoder.v tb/tb_estado_basico_decoder.v
	mkdir -p $(BUILD)
	iverilog -g2012 -o $@ $^

asm: $(BUILD)/tp1_fluxo_basico

$(BUILD)/tp1_fluxo_basico.o: asm/tp1_fluxo_basico.s
	mkdir -p $(BUILD)
	$(AS) -g -o $@ $<

$(BUILD)/tp1_fluxo_basico: $(BUILD)/tp1_fluxo_basico.o
	$(LD) -o $@ $<

run-asm: asm
	$(BUILD)/tp1_fluxo_basico

clean:
	rm -rf $(BUILD) *.vcd
