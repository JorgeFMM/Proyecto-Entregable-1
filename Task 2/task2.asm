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
sprite_index: .res 1
delay_counter: .res 1
.exportzp sprite_y, sprite_tile, sprite_flags, sprite_x, sprite_index, delay_counter

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
  
  LDX delay_counter
  CPX #$00
  BNE no_update
  LDX #$00
  CPY #$80
  BNE continue
  LDY #$00
continue:
  LDA sprites,Y
  STA sprite_y
  INY
  LDA sprites,Y
  STA sprite_tile
  INY
  LDA sprites,Y
  STA sprite_flags
  INY
  LDA sprites,Y
  STA sprite_x
  INY
  JSR draw_sprite
  INX
  CPX #$10
  BNE continue

  LDA #$00
  STA sprite_index
  LDX #$00
no_update:
  INX
  STX delay_counter
  LDX delay_counter
  CPX #$10
  BNE keep_counting
  LDX #$00
  STX delay_counter
keep_counting:
	LDA #$00
	STA $2005
	STA $2005
  RTI
.endproc

.proc reset_handler
  LDA #$00
  STA sprite_index
  LDY #$00

  LDA #$00
  STA delay_counter

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
  TYA
  PHA

  LDY sprite_index
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
  STY sprite_index

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
.byte $70, $08, $00, $50
.byte $70, $09, $00, $58
.byte $78, $0a, $00, $50
.byte $78, $0b, $00, $58

.byte $70, $18, $00, $60
.byte $70, $19, $00, $68
.byte $78, $1a, $00, $60
.byte $78, $1b, $00, $68

.byte $70, $10, $00, $70
.byte $70, $11, $00, $78
.byte $78, $12, $00, $70
.byte $78, $13, $00, $78

.byte $70, $19, %01000000, $80
.byte $70, $18, %01000000, $88
.byte $78, $1b, %01000000, $80
.byte $78, $1a, %01000000, $88

.byte $70, $08, $00, $50
.byte $70, $09, $00, $58
.byte $78, $0b, %01000000, $50
.byte $78, $0a, %01000000, $58

.byte $70, $1c, $00, $60
.byte $70, $1d, $00, $68
.byte $78, $1e, $00, $60
.byte $78, $1f, $00, $68

.byte $70, $10, $00, $70
.byte $70, $11, $00, $78
.byte $78, $13, %01000000, $70
.byte $78, $12, %01000000, $78

.byte $70, $1d, %01000000, $80
.byte $70, $1c, %01000000, $88
.byte $78, $1f, %01000000, $80
.byte $78, $1e, %01000000, $88


.segment "CHARS"
.incbin "sprites.chr"
