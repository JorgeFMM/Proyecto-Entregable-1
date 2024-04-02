PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
PPUADDR   = $2006
PPUDATA   = $2007
OAMADDR   = $2003
OAMDMA    = $4014

.segment "ZEROPAGE"
sprite_y: .res 1
sprite_tile: .res 1
sprite_flags: .res 1
sprite_x: .res 1
block_h: .res 1
block_l: .res 1
block_tile: .res 1
.exportzp sprite_y, sprite_tile, sprite_flags, sprite_y, block_h, block_l, block_tile

.segment "HEADER"
.byte $4e, $45, $53, $1a ; Magic string that always begins an iNES header
.byte $02        ; Number of 16KB PRG-ROM banks
.byte $01        ; Number of 8KB CHR-ROM banks
.byte %00000000  ; Horizontal mirroring, no save RAM, no mapper
.byte %00000000  ; No special-case flags set, no mapper
.byte $00        ; No PRG-RAM present
.byte $00        ; NTSC format

.segment "CODE"
.proc irq_handler
  RTI
.endproc

.proc nmi_handler
  LDA #$00
  STA OAMADDR
  LDA #$02
  STA OAMDMA
	LDA #$00
	STA $2005
	STA $2005
  RTI
.endproc

.proc reset_handler
  SEI
  CLD
  LDX #$40
  STX $4017
  LDX #$FF
  TXS
  INX
  STX $2000
  STX $2001
  STX $4010
  BIT $2002
vblankwait:
  BIT $2002
  BPL vblankwait

	LDX #$00
	LDA #$FF
clear_oam:
	STA $0200,X ; set sprite y-positions off the screen
	INX
	INX
	INX
	INX
	BNE clear_oam

vblankwait2:
  BIT $2002
  BPL vblankwait2
  JMP main
.endproc

.proc main
  ; write a palette
  LDX PPUSTATUS
  LDX #$3f
  STX PPUADDR
  LDX #$00
  STX PPUADDR
load_palettes:
  LDA palettes,X
  STA PPUDATA
  INX
  CPX #$20
  BNE load_palettes

  ; write sprite data
LDX #$00
LDY #$00
load_sprites:
  LDA sprites,X
  STA sprite_y
  INX
  LDA sprites,X
  STA sprite_tile
  INX
  LDA sprites,X
  STA sprite_flags
  INX
  LDA sprites,X
  STA sprite_x
  INX
  JSR draw_sprite
  CPX #$c0
  BNE load_sprites

LDX #$00
load_blocks:
  LDA blocks,X
  STA block_h
  INX
  LDA blocks,X
  STA block_l
  INX
  LDA blocks,X
  STA block_tile
  INX
  JSR draw_block
  CPX #$6c
  BNE load_blocks

; finally, attribute table
LDA PPUSTATUS
LDA #$23
STA PPUADDR
LDA #$e9
STA PPUADDR
LDA #%00000101
STA PPUDATA

vblankwait:       ; wait for another vblank before continuing
  BIT PPUSTATUS
  BPL vblankwait

  LDA #%10010000  ; turn on NMIs, sprites use first pattern table
  STA PPUCTRL
  LDA #%00011110  ; turn on screen
  STA PPUMASK

forever:
  JMP forever
.endproc

.proc draw_sprite
  ; save registers
  PHP
  PHA
  TXA
  PHA
  PHA

  LDA sprite_y
  STA $0200, Y
  INY
  LDA sprite_tile
  STA $0200, Y
  INY
  LDA sprite_flags
  STA $0200, Y
  INY
  LDA sprite_x
  STA $0200, Y
  INY

  PLA
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc draw_block
  ; save registers
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  LDA PPUSTATUS
  LDA block_h
  STA PPUADDR
  LDA block_l
  STA PPUADDR
  LDX block_tile
  STX PPUDATA

  ; restore registers and return
  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "RODATA"
palettes:
.byte $0f, $12, $23, $27
.byte $0f, $00, $10, $32
.byte $0f, $00, $00, $00
.byte $0f, $00, $00, $00

.byte $0f, $0c, $21, $32
.byte $0f, $00, $00, $00
.byte $0f, $00, $00, $00
.byte $0f, $00, $00, $00

sprites:
.byte $50, $04, $00, $60
.byte $50, $05, $00, $68
.byte $58, $06, $00, $60
.byte $58, $07, $00, $68

.byte $50, $08, $00, $70
.byte $50, $09, $00, $78
.byte $58, $0a, $00, $70
.byte $58, $0b, $00, $78

.byte $50, $08, $00, $80
.byte $50, $09, $00, $88
.byte $58, $0b, %01000000, $80
.byte $58, $0a, %01000000, $88

.byte $60, $0c, $00, $60
.byte $60, $0d, $00, $68
.byte $68, $0e, $00, $60
.byte $68, $0f, $00, $68

.byte $60, $10, $00, $70
.byte $60, $11, $00, $78
.byte $68, $12, $00, $70
.byte $68, $13, $00, $78

.byte $60, $10, $00, $80
.byte $60, $11, $00, $88
.byte $68, $13, %01000000, $80
.byte $68, $12, %01000000, $88

.byte $70, $14, $00, $60
.byte $70, $15, $00, $68
.byte $78, $16, $00, $60
.byte $78, $17, $00, $68

.byte $70, $18, $00, $70
.byte $70, $19, $00, $78
.byte $78, $1a, $00, $70
.byte $78, $1b, $00, $78

.byte $70, $1c, $00, $80
.byte $70, $1d, $00, $88
.byte $78, $1e, $00, $80
.byte $78, $1f, $00, $88

.byte $80, $15, %01000000, $60
.byte $80, $14, %01000000, $68
.byte $88, $17, %01000000, $60
.byte $88, $16, %01000000, $68

.byte $80, $19, %01000000, $70
.byte $80, $18, %01000000, $78
.byte $88, $1b, %01000000, $70
.byte $88, $1a, %01000000, $78

.byte $80, $1d, %01000000, $80
.byte $80, $1c, %01000000, $88
.byte $88, $1f, %01000000, $80
.byte $88, $1e, %01000000, $88

blocks:
.byte $22, $84, $24
.byte $22, $85, $25
.byte $22, $a4, $26
.byte $22, $a5, $27
.byte $22, $86, $04
.byte $22, $87, $05
.byte $22, $a6, $06
.byte $22, $a7, $07
.byte $22, $88, $08
.byte $22, $89, $09
.byte $22, $a8, $0a
.byte $22, $a9, $0b
.byte $22, $8a, $0c
.byte $22, $8b, $0d
.byte $22, $aa, $0e
.byte $22, $ab, $0f
.byte $22, $8c, $10
.byte $22, $8d, $11
.byte $22, $ac, $12
.byte $22, $ad, $13
.byte $22, $8e, $14
.byte $22, $8f, $15
.byte $22, $ae, $16
.byte $22, $af, $17
.byte $22, $90, $18
.byte $22, $91, $19
.byte $22, $b0, $1a
.byte $22, $b1, $1b
.byte $22, $92, $1c
.byte $22, $93, $1d
.byte $22, $b2, $1e
.byte $22, $b3, $1f
.byte $22, $94, $20
.byte $22, $95, $21
.byte $22, $b4, $22
.byte $22, $b5, $23

.segment "CHARS"
.incbin "sprites.chr"
