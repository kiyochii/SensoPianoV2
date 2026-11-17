# Entrega atual — 17/11/2026

| Arquivo | Finalidade |
| --- | --- |
| [SensoPiano_DE0_CV.qar](SensoPiano_DE0_CV.qar) | Projeto Quartus completo para restaurar, com fontes, restrições, documentação e `.sof` |
| [SensoPiano_DE0_CV.sof](SensoPiano_DE0_CV.sof) | Programação da DE0-CV via JTAG / USB-Blaster; versão compilada com timing interno de 50 MHz atendido |
| [SensoPiano_pinagem_e_montagem.pdf](SensoPiano_pinagem_e_montagem.pdf) | Tabelas e montagem para impressão, em três páginas |
| [SensoPiano_pinagem.csv](SensoPiano_pinagem.csv) | Planilha com sinais, pinos da FPGA, posições físicas e ligações |
| [Relatórios Quartus](relatorios_quartus) | Compilação, fitting, timing e pinagem aplicada |
| [Montagem física](../Quartus/MONTAGEM.md) | Componentes, resistores, circuitos de tecla/LED e ordem de ligação |

Restaure o `.qar` em uma pasta vazia pelo Quartus, em **Project > Restore
Archived Project**, e abra `Quartus/SensoPiano_DE0_CV.qpf`. Não é necessário
instalar manualmente os fontes. O firmware do ESP32 é compilado separadamente
em `ESP32/fw` deste repositório.

O ZIP anterior e o planejamento em LaTeX são materiais anteriores a esta
entrega; use o QAR acima para a versão atual com LEDs de uma cor e telemetria
temporal. Consulte o [registro de validação](../docs/testes/compilacao-quartus-2026-11-17.md).
