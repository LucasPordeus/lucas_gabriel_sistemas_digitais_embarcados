// tangnano4k.sdc: restricao de timing do oscilador de 27 MHz (periodo 37,037 ns)
create_clock -name clk -period 37.037 -waveform {0 18.518} [get_ports {clk}]
