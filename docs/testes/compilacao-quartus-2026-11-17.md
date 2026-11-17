# Compilação e arquivo QAR — 17/11/2026

Projeto `SensoPiano_DE0_CV`, topo `sensopiano_de0_cv`, dispositivo
`5CEBA4F23C7`. Versão com 12 LEDs de uma cor e eventos físicos com tempo.
Quartus Prime Lite **20.1.1 Build 720**, executado no Windows a partir do WSL.

## Resultado da compilação final

| Verificação | Resultado |
| --- | --- |
| Compilação completa, incluindo fitting e assembler | 0 erros, 20 avisos, nenhum aviso crítico |
| Clock interno | 50 MHz / período 20 ns |
| Pior folga de setup | +5,436 ns |
| Pior folga de hold | +0,156 ns |
| Setup, hold, recovery, removal e largura de pulso | Todas as 20 verificações positivas nos quatro modelos de operação |
| Pinos atribuídos e aplicados | 42; conferidos individualmente entre QSF e `.pin` |
| Utilização lógica | 1.102 / 18.480 ALMs, 6% |
| Registradores | 1.443 |
| Memória de blocos | 2.480 bits; quatro blocos RAM |
| DSP / PLL | Nenhum |
| Testes RTL afetados pela correção | `tb_uart_metrics_sender` e `tb_metrics_uart`: 2 aprovados |
| Tabelas de pinagem | 42 atribuições CSV/QSF conferidas; posições físicas verificadas no manual |

Os relatórios originais estão em
[Entregas/relatorios_quartus](../../Entregas/relatorios_quartus).
O `.sof` foi produzido pelo assembler da mesma compilação.

O QAR foi gerado pelo arquivador nativo e restaurado pelo próprio Quartus
em uma pasta vazia. Foram conferidos os hashes de 25 arquivos de fontes,
restrições, documentação, relatórios e bitstream, além das 42 atribuições
do QSF. O teste de compilação do arquivador também passou.

## Ajustes necessários para a compilação

As atribuições `-to {porta}` do QSF estavam sendo interpretadas pelo leitor
do Quartus como nomes contendo chaves. Foram substituídas por `-to "porta"`.
O relatório final confirma cada pino físico atribuído, sem atribuições ignoradas.

A conversão decimal das métricas usava uma cadeia combinacional de divisões
e restos. A primeira compilação indicou pior setup de **−13,020 ns**. A
conversão agora usa shift/add-3 em 16 ciclos, para os três contadores em
paralelo, antes de transmitir a linha congelada. Isso acrescenta 320 ns de
preparo a 50 MHz, mantendo os mesmos 23 bytes ASCII, contagem, saturação,
agregação, prioridades e comportamento sob transmissor ocupado.

Os dois testes afetados passaram, incluindo os 65.535 incrementos, snapshots,
reset e recepção UART pelo fio. A nova compilação completa apresentou pior
setup de **+5,436 ns**. O número de processadores foi limitado a quatro para
uma compilação reproduzível sem sobrecarregar a máquina.

## Avisos e alcance da validação

Os avisos remanescentes incluem larguras de expressões truncadas ao tamanho
dos registradores, cases com valores padrão definidos antes do case, memória
inferida com lógica para leitura durante escrita, conectividade de portas de
depuração, drive/slew não explicitados e recurso LogicLock indisponível no
Lite. Não há aviso crítico na compilação final nem aviso no Timing Analyzer
final. As correntes e slew usam as escolhas padrão do Quartus; a montagem
proposta usa LEDs indicadores de baixa corrente, com resistor individual.

As entradas humanas e saídas assíncronas têm exceções SDC. Portanto, o
resultado de 50 MHz se refere aos caminhos internos; não mede latência UART,
contato mecânico, integridade elétrica da fiação ou áudio analógico.
Não houve gravação na FPGA nem ensaio físico nesta execução.

O autoteste do arquivador executa uma análise de tempo pós-mapeamento, sem
o posicionamento e roteamento finais, e apresentou avisos de timing nessa
estimativa. O resultado de 50 MHz acima usa a análise **pós-Fitter** da
compilação completa, com todas as folgas positivas. Os logs separados do
arquivamento e da compilação completa estão na pasta de relatórios.

## Reproduzir

```sh
cd Quartus
quartus_sh --flow compile SensoPiano_DE0_CV
quartus_sh --archive -self_test -output ../Entregas/SensoPiano_DE0_CV.qar SensoPiano_DE0_CV
```

Depois de restaurar o QAR em uma pasta vazia, abra
`Quartus/SensoPiano_DE0_CV.qpf`. Fontes e referências usam caminhos relativos.
As tabelas, instruções e `.sof` acompanham o projeto no arquivo.
