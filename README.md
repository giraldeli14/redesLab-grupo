# Minha pequena internet

Laboratório do trabalho semestral de **Redes e Sistemas Distribuídos** —
Prof. Me. Luiz Ricardo Mantovani da Silva.

Uma topologia só, que cresce ao longo do semestre: começa com duas redes que
não se falam e termina com um serviço replicado, roteamento que se refaz
sozinho e a demonstração de por que uma senha não deve viajar sem proteção.

Tudo roda no **Google Cloud Shell**, que é gratuito, não pede cartão de crédito
e dá a cada aluno uma máquina Linux com root só dela.

---

## Começando

Construa a imagem do laboratório — uma vez por sessão do Cloud Shell:

```bash
make base
```

Suba a topologia da primeira entrega:

```bash
make up E=1
```

Rode as provas:

```bash
make verificar E=1
```

`make verificar` **começa vermelho de propósito**. O laboratório vem
incompleto: o roteiro de verificação é o enunciado de verdade, e o trabalho é
levá-lo ao verde.

Enunciado de cada entrega em [`entregas/`](entregas/).

---

## As cinco entregas

| # | Semana | Tema | Vale |
|---|---|---|---|
| [E1](entregas/E1.md) | 6 | Dois segmentos e um serviço | 0,8 |
| [E2](entregas/E2.md) | 9 | O roteador e o encapsulamento | 1,4 |
| [E3](entregas/E3.md) | 11 | O serviço não pode cair | 1,2 |
| [E4](entregas/E4.md) | 12 | A rota se refaz sozinha | 1,2 |
| — | 14 | Apresentação | 1,4 |
| [E5](entregas/E5.md) | 13 | O pacote entrega o segredo · **Cartilha** | **2,0 (Extensão)** |

E1–E4 e a apresentação compõem os 6,0 de avaliação prática. E5 é a atividade
de extensão, com nota escalonada em 1,2 / 1,7 / 2,0.

---

## Entrega 1 — Plano de endereçamento

### Sub-redes

| Segmento | Sub-rede | Endereços totais | Utilizáveis para host |
|---|---|---|---|
| A | `10.0.10.0/24` | 256 | 254 (`10.0.10.1` a `10.0.10.254`) |
| B | `10.0.20.0/24` | 256 | 254 (`10.0.20.1` a `10.0.20.254`) |

Uma `/24` reserva sempre 2 endereços por sub-rede: o primeiro (`.0`) identifica
a própria rede, e o último (`.255`) é o endereço de broadcast, que atinge
todos os hosts da sub-rede ao mesmo tempo. Nenhum dos dois pode ser atribuído
a uma máquina individual — por isso 256 − 2 = 254 endereços utilizáveis.

### Máquinas

| Contêiner | Segmento | Endereço |
|---|---|---|
| `e1-host-a1` | A | `10.0.10.10` |
| `e1-host-a2` | A | `10.0.10.11` |
| `e1-srv-a` | A | `10.0.10.20` |
| `e1-host-b1` | B | `10.0.20.10` |
| `e1-host-b2` | B | `10.0.20.11` |

### Por que o segmento A não alcança o B

Cada host tem a rota padrão removida de propósito
(`ip route del default`), e não existe nenhum roteador ligando as duas
sub-redes. Sem rota para fora da própria rede, um host de A não tem como
encaminhar um pacote destinado a `10.0.20.0/24` — o próprio kernel já sabe que
não tem por onde mandar. Por isso o `ping` de A para B falha imediatamente com
`Network is unreachable`, um erro de camada 3 detectado localmente, e não um
timeout (que indicaria uma tentativa de envio sem resposta).

---

## Entrega 2 — O roteador e o encapsulamento

### Topologia

| Contêiner | Segmento | Endereço | Rota |
|---|---|---|---|
| `e2-host-a1` | A | `10.0.10.10` | `10.0.20.0/24 via 10.0.10.254` |
| `e2-host-a2` | A | `10.0.10.11` | nenhuma (grupo de controle) |
| `e2-host-b1` | B | `10.0.20.10` | `10.0.10.0/24 via 10.0.20.254` |
| `e2-router` | A e B | `10.0.10.254` / `10.0.20.254` | repasse IP ligado |

As rotas estão escritas no `command` de `host-a1` e `host-b1` em
`e2-roteador/docker-compose.yml`, e não digitadas no terminal, para
sobreviverem a um reinício. O `host-a2` não foi tocado: ele é o grupo de
controle.

### O que a verificação prova

- `host-a1` alcança `host-b1` com **TTL 63**: o pacote saiu com 64 e chegou
  com 63, ou seja, houve um salto.
- `host-a2`, sem rota, continua com `Network is unreachable`. Mesma máquina,
  mesma rede, só muda a configuração: foi a rota que fez a diferença.
- Capturas simultâneas nas duas pernas do roteador:
  `perna-a.pcap` e `perna-b.pcap`.

### O que mudou e o que não mudou

| Campo | Perna A | Perna B | |
|---|---|---|---|
| Ethernet origem | `06:cd:9c:9c:db:eb` (host-a1) | `c6:43:8b:e8:f9:be` (roteador, lado B) | mudou |
| Ethernet destino | `b2:b4:bc:69:12:45` (roteador, lado A) | `06:d2:24:b9:e3:9e` (host-b1) | mudou |
| IP origem → destino | `10.0.10.10` → `10.0.20.10` | `10.0.10.10` → `10.0.20.10` | **não mudou** |
| Identification | `0x88d4` | `0x88d4` | não mudou (mesmo pacote) |
| TTL | 64 | 63 | mudou |
| Checksum do cabeçalho IP | `0x7fc1` | `0x80c1` | mudou (consequência do TTL) |

Print do Wireshark com os campos marcados (vermelho = mudou, verde = não
mudou): `/home/giraldagiovana/redes-lab/e2-roteador/print/wireshark.png`.

### Por que o MAC muda e o IP não

O endereço MAC só vale dentro de um enlace: ele diz qual interface, naquele segmento, deve receber o quadro. Quando o pacote do host-a1 chega ao roteador, o quadro da perna A é desmontado; o roteador consulta a tabela de rotas, descobre que 10.0.20.0/24 está na outra perna e monta um quadro novo, com o MAC da própria interface como origem e o MAC do host-b1 como destino. Por isso o MAC muda a cada enlace. Já o endereço IP identifica quem enviou e quem deve receber de ponta a ponta, então o pacote IP atravessa dentro dos quadros sem ser reescrito: nas duas capturas a origem é 10.0.10.10, o destino é 10.0.20.10 e até o campo Identification é o mesmo. O roteador só decrementa o TTL (64 para 63) e recalcula o checksum do cabeçalho. É por isso também que o host-a2 não passa: sem rota, ele não sabe que o roteador é o próximo salto.

---

## Regras do jogo

**A entrega é o repositório, nunca o ambiente.** A correção é feita clonando o
repositório do grupo numa Cloud Shell limpa e rodando `make up` e
`make verificar`. Se não subir lá, não entregou.

**Evidência é obrigatória.** `make evidencias E=<n>` grava a saída da
verificação; os `.pcap` das entregas 2 e 5 vão junto. Isso é versionado — nunca
apaguem a pasta `evidencias/`.

**Imagem pequena.** A máquina do Cloud Shell é efêmera e recicla o cache de
imagens: só a pasta pessoal (5 GB) sobrevive. Por isso a base é Alpine.

**Nada de varredura de rede.** Os termos de uso do Cloud Shell proíbem
explicitamente varredura, e a conta que descumprir é desligada. Todo o trabalho
aqui é captura passiva dentro da rede virtual do próprio grupo — o que é outra
coisa, e é permitido.

---

## Para o professor

Antes de liberar para a turma, uma vez, numa Cloud Shell limpa:

```bash
make autoteste
```

Confere as quatro coisas de que o laboratório depende e que documentação
nenhuma garante: criação de bridge com sub-rede própria, `tcpdump` com
`NET_RAW` efetivo, `net.ipv4.ip_forward` por contêiner, e o pacote `bird` no
Alpine (só a E4 depende dele).

### Botão "Abrir no Cloud Shell"

Para cada entrega, na página do trabalho:

```
https://shell.cloud.google.com/cloudshell/editor
  ?cloudshell_git_repo=https://github.com/LuizRMSilva1973/redes-lab
  &cloudshell_tutorial=entregas/E1.md
  &show=ide%2Cterminal
```

O aluno cai no terminal com o repositório clonado e o enunciado aberto como
roteiro guiado ao lado. Trocar `E1.md` pela entrega da vez.

O repositório precisa estar em **GitHub ou Bitbucket**, público.

### Correção

```bash
git clone <repo-do-grupo> && cd <repo> && make up E=2 && make verificar E=2
```

Os roteiros imprimem o valor observado em cada ponto, não só passou/falhou —
dá para corrigir lendo a saída.
