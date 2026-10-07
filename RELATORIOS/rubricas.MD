# Base de Conhecimento e Requisitos: Semáforo Inteligente (ARM + FPGA)

Abaixo estão os contextos, tarefas e rubricas de avaliação para cada um dos 5 Testes de Performance (TPs) e para a Entrega Final do Projeto. Você deve seguir estes requisitos rigorosamente ao gerar os códigos e relatórios.

---

## [TP1] - Estruturação e Arquitetura Preliminar

### Contexto[cite: 6]
O Raspberry Pi Zero 2W (Assembly ARM 64 bits) e a Tang Nano 4K (Verilog) trabalharão juntos. O ARM atua como unidade de controle e interface, enquanto o FPGA executa lógica dedicada (FSMs, aritméticos, controle de hardware). Este TP define o escopo, arquitetura preliminar e os fundamentos iniciais[cite: 6].

### Tarefas[cite: 6]
1. Elaborar planejamento coerente para o protótipo.
2. Configurar ambiente de desenvolvimento (Raspberry Pi OS 64 bits, GCC, GAS, GDB, Gowin IDE).
3. Construir artefatos iniciais: Diagrama preliminar de arquitetura, um módulo combinacional simples em Verilog com testbench, um programa básico em Assembly ARM 64 bits, e fotos das conexões.
4. Produzir relatório técnico com visão geral, arquitetura, ambiente e primeiras implementações.

### Rúbricas (Critérios de Aceite)[cite: 6]
- [ ] Explicou entradas, saídas e fluxo básico de dados relacionando ARM, FPGA e hardware.
- [ ] Definiu e justificou a divisão de responsabilidades.
- [ ] Implementou módulo combinacional simples em Verilog e desenvolveu testbench funcional.
- [ ] Estruturou corretamente a simulação em Verilog.
- [ ] Codificou programa em Assembly ARM 64 bits utilizando registradores, LDR/STR, decisão e loops.
- [ ] Demonstrou compreensão de manipulação de dados estruturados em Assembly.

---

## [TP2] - Circuitos Combinacionais e Rotinas Estruturadas

### Contexto[cite: 5]
Foco em consolidar elementos funcionais. Uso mais profundo da Tang Nano 4K com testbenches completos e síntese física. No ARM, desenvolvimento de programas estruturados explorando memória e fluxo de controle. A arquitetura inicial deve ser expandida incorporando os primeiros ensaios de comunicação[cite: 5].

### Tarefas[cite: 5]
1. Revisar a arquitetura especificando sinais digitais, fluxo de dados e diagramas detalhados.
2. Implementar ao menos dois módulos combinacionais em Verilog, criar testbenches, registrar waveforms e sintetizar na Tang Nano 4K.
3. Implementar Assembly com registradores, LDR/STR, CMP, B, loops e decisões, rodando no Raspberry Pi Zero 2W.
4. Produzir evidências (snippets, capturas de simulação/GDB, fotos do hardware).

### Rúbricas (Critérios de Aceite)[cite: 5]
- [ ] Arquitetura ARM-FPGA detalhada com responsabilidades e fluxo de dados.
- [ ] Justificou escolhas baseadas em requisitos de tempo real.
- [ ] Diagramas técnicos incluindo sinais digitais, entradas e saídas.
- [ ] Implementou combinacionais em Verilog e validou com testbenches e waveforms.
- [ ] Sintetizou e executou módulo no hardware físico da Tang Nano 4K.
- [ ] Analisou waveforms para evidenciar validação de comportamento.
- [ ] Programas Assembly com loops e decisões condicionais.
- [ ] Controle de fluxo estruturado em Assembly.
- [ ] Rotinas aritméticas e manipulação de memória no ARM.
- [ ] Descreveu/implementou mecanismos de interação ARM-FPGA.
- [ ] Propôs mecanismo de sinais/comandos de comunicação.
- [ ] Registrou evidências (códigos, simulação, fotos).

---

## [TP3] - Máquinas de Estado e Controle GPIO

### Contexto[cite: 4]
Integração profunda entre software e hardware. Criação de Máquinas de Estados Finitos (FSMs) em Verilog. No ARM, loops, tabelas de salto e parsing. Início do mapeamento GPIO do Raspberry Pi para preparar a comunicação com o FPGA. Automação do projeto com Makefiles[cite: 4].

### Tarefas[cite: 4]
1. Projetar e implementar FSMs em Verilog de forma hierárquica, validar com testbenches e sintetizar na FPGA.
2. Criar estruturas de controle Assembly: loops, if-elseif-else, tabelas de salto e parsing simples.
3. Mapear registradores GPIO do Raspberry Pi e demonstrar acesso a bits específicos com LDR/STR.
4. Criar Makefile básico e modular para automatizar o build; usar objdump e GDB.
5. Atualizar diagrama de arquitetura com FSMs, fluxo ARM e mapeamento GPIO.

### Rúbricas (Critérios de Aceite)[cite: 4]
- [ ] Analisou requisitos de temporização ao simular transições das FSMs.
- [ ] Arquitetura atualizada com hierarquia Verilog e controle ARM.
- [ ] Diagrama mapeando FSMs e início do mapeamento GPIO ARM-FPGA.
- [ ] FSMs Verilog desenvolvidas, testadas e com waveforms analisados.
- [ ] FSMs sintetizadas na Tang Nano 4K validadas com fotos.
- [ ] Estruturas de controle Assembly avançadas (múltiplas condições, tabelas de salto).
- [ ] Rotinas de parsing para interpretação de comandos no ARM.
- [ ] Endereços e registradores GPIO mapeados (acesso LDR/STR).
- [ ] Escrita/leitura simulada nos registradores GPIO demonstrada.
- [ ] Integração testada fisicamente na FPGA e Raspberry Pi.
- [ ] Evidências com waveforms, objdump e GDB registradas.
- [ ] Build automatizado com Makefile modular.
- [ ] Relatório técnico de integração parcial estruturado.

---

## [TP4] - Matemática, BRAM, DSP e NEON SIMD

### Contexto[cite: 3]
Ampliação da complexidade lógica e aritmética. No FPGA: uso de BRAM, DSP e PLL para unidades aritméticas e armazenamento. No ARM: rotinas numéricas multi-palavra, shifts, máscaras, conversões e paralelização com NEON SIMD[cite: 3].

### Tarefas[cite: 3]
1. Projetar módulo aritmético em Verilog utilizando BRAM e DSP; registrar waveforms e sintetizar.
2. Criar rotinas numéricas Assembly (multi-palavra, int-float, lookup tables, bitwise).
3. Executar operações SIMD (NEON) no Raspberry (inteiros e ponto flutuante).
4. Atualizar arquitetura detalhando fluxos numéricos, uso de BRAM/DSP e rotinas SIMD.
5. Registrar testes de estabilidade, latência e ciclos de clock no relatório.

### Rúbricas (Critérios de Aceite)[cite: 3]
- [ ] Arquitetura atualizada com BRAM, DSP, fluxos numéricos e rotinas SIMD.
- [ ] Módulos aritméticos Verilog (com BRAM/DSP) simulados e validados no hardware físico.
- [ ] Rotinas Assembly multi-palavra, conversões, lookup tables e operações bitwise desenvolvidas e organizadas em macros.
- [ ] FPGA, ARM e periféricos integrados e sincronizados eletricamente.
- [ ] Comunicação ARM-FPGA validada com envio/recebimento de dados, detecção de erros e telemetria.
- [ ] Integração parcial validada e documentada intermediariamente.
- [ ] Desempenho (clock, latência) e estabilidade medidos e tabulados.
- [ ] Relatório técnico completo validando o funcionamento integrado dos módulos.

---

## [TP5] - Integração Final e Bibliotecas

### Contexto[cite: 2]
O momento de consolidar tudo em um protótipo funcional em tempo real. Implementação final da comunicação ARM↔FPGA com handshaking, estruturação do projeto Assembly em múltiplos arquivos (bibliotecas .a) e execução standalone[cite: 2].

### Tarefas[cite: 2]
1. Finalizar módulos Verilog (casos de borda, configurações OE, pinos).
2. Integrar comunicação ARM↔FPGA (protocolo final, handshaking, telemetria).
3. Estruturar Assembly (arquivos temáticos, bibliotecas .a, Makefiles robustos).
4. Desenvolver funções avançadas Assembly (buffers, strings, macros parametrizadas).
5. Realizar testes contínuos de desempenho (throughput, latência, tempo de resposta).
6. Atualizar a documentação definitiva da arquitetura.

### Rúbricas (Critérios de Aceite)[cite: 2]
- [ ] Arquitetura completamente documentada com todos os blocos e fluxos.
- [ ] Projeto Assembly em múltiplos módulos, bibliotecas, manipulação de strings e macros.
- [ ] Protocolo digital finalizado com handshaking funcional, telemetria e troca real de dados.
- [ ] Protótipo validado com testes de latência e throughput em cenário representativo.
- [ ] Relatório final demonstrando domínio técnico e clareza das melhorias.

---

## [FINAL_PROJECT] - Entrega de Projeto Obrigatório

### Contexto[cite: 1]
Entrega final sintetizando todas as competências. Não há novos desenvolvimentos obrigatórios, apenas ajustes, correções finais baseadas no TP5 e consolidação. O sistema embarcado híbrido ARM-FPGA deve funcionar como um protótipo real, perfeitamente coerente e profissionalmente documentado[cite: 1].

### Tarefas[cite: 1]
1. Demonstrar protótipo final funcionando (ARM -> FPGA -> hardware/interface).
2. Organizar documentação técnica revisada (arquitetura, divisões, sinais, testes, waveforms).
3. Consolidar repositório GitHub com códigos finais, Makefiles e documentação.

### Rúbricas Consolidadas (Critérios de Aceite Finais)[cite: 1]
1. **Arquitetura (ARM-FPGA):**
   - Entradas, saídas e fluxos claramente explicados[cite: 1].
   - Divisão de responsabilidades técnica e justificada[cite: 1].
   - Requisitos de tempo real (BRAM, DSP, PLL, banda) totalmente dominados[cite: 1].
   - Diagramas integrais de todo o sistema[cite: 1].
2. **Hardware Verilog:**
   - Módulos combinacionais e testbenches corretos[cite: 1].
   - Waveforms comprovando temporização adequada[cite: 1].
   - FSMs modulares validadas no hardware físico[cite: 1].
   - Integração aritmética e BRAM/DSP perfeitamente correspondente à simulação[cite: 1].
3. **Software Assembly ARM 64-bit:**
   - Rotinas de LDR/STR, registradores, decisões e loops eficientes[cite: 1].
   - Manipulação de vetores, strings e parsers[cite: 1].
   - Operações NEON SIMD e cálculos avançados[cite: 1].
   - Modularidade avançada (arquivos, macros, bibliotecas estáticas)[cite: 1].
4. **Integração:**
   - Sinais básicos via GPIO mapeados[cite: 1].
   - Protocolo de comandos com bitfields e handshaking implementado[cite: 1].
   - Integração com periféricos perfeitamente sincronizada eletricamente[cite: 1].
   - Detecção de erros e sistema altamente confiável[cite: 1].
5. **Documentação e Validação:**
   - Prints, logs e waveforms organizados[cite: 1].
   - Testes unitários para cada subsistema antes da montagem final[cite: 1].
   - Integração comprovada através de dados contínuos de desempenho e latência[cite: 1].