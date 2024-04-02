PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
PPUSCROLL = $2005
PPUADDR   = $2006
PPUDATA   = $2007
OAMADDR   = $2003
OAMDMA    = $4014

CONTROLLER1 = $4016
CONTROLLER2 = $4017

BTN_RIGHT   = %00000001
BTN_LEFT    = %00000010
BTN_DOWN    = %00000100
BTN_UP      = %00001000
BTN_START   = %00010000
BTN_SELECT  = %00100000
BTN_B       = %01000000
BTN_A       = %10000000

.segment "ZEROPAGE"
player_x: .res 1
player_y: .res 1
player_dir: .res 1
player_walk: .res 1
pad1: .res 1
is_moving: .res 1
delay_counter: .res 1
.exportzp player_x, player_y, player_dir, player_walk, pad1, is_moving, delay_counter

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

	; read controller
	JSR read_controller1

  ; update tiles *after* DMA transfer
	; and after reading controller state
	JSR update_player
  JSR draw_player
  
  LDX delay_counter
  CPX #$00
  BNE continue
  LDX #$00
  CPX player_walk
  BNE negate
  LDX #$01
  STX player_walk
  LDX #$00
  JMP continue
negate:
  LDX #$00
  STX player_walk
continue:
  INX
  STX delay_counter
  LDX delay_counter
  CPX #$10
  BNE keep_counting
  LDX #$00
  STX delay_counter
keep_counting:

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

	; initialize zero-page values
	LDA #$80
	STA player_x
	LDA #$a0
	STA player_y
  LDA #$00 
  STA is_moving
  STA player_dir
  STA player_walk
  STA delay_counter

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
.proc update_player
  PHP  ; Start by saving registers,
  PHA  ; as usual.
  TXA
  PHA
  TYA
  PHA

  LDA #$00
  STA is_moving
  LDX player_x
  LDY player_y
  
  LDA pad1        ; Load button presses
  AND #BTN_LEFT   ; Filter out all but Left
  BEQ check_right ; If result is zero, left not pressed
  DEC player_x  ; If the branch is not taken, move player left
  LDA #$01
  STA player_dir
check_right:
  LDA pad1
  AND #BTN_RIGHT
  BEQ check_up
  INC player_x
  LDA #$03
  STA player_dir
check_up:
  LDA pad1
  AND #BTN_UP
  BEQ check_down
  DEC player_y
  LDA #$02
  STA player_dir
check_down:
  LDA pad1
  AND #BTN_DOWN
  BEQ check_movedx
  INC player_y
  LDA #$00
  STA player_dir
check_movedx:
  LDA #$00
  CPX player_x
  BEQ check_movedy
  LDA #$01
  STA is_moving
check_movedy:
  CPY player_y
  BEQ done_checking
  CLC
  ADC #$01
  STA is_moving
done_checking:
  PLA ; Done with updates, restore registers
  TAY ; and return to where we called this
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc draw_player
  ; save registers
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  ; store tile locations
  ; top left tile:
  LDA player_y
  STA $0200
  LDA player_x
  STA $0203

  ; top right tile (x + 8):
  LDA player_y
  STA $0204
  LDA player_x
  CLC
  ADC #$08
  STA $0207

  ; bottom left tile (y + 8):
  LDA player_y
  CLC
  ADC #$08
  STA $0208
  LDA player_x
  STA $020b

  ; bottom right tile (x + 8, y + 8)
  LDA player_y
  CLC
  ADC #$08
  STA $020c
  LDA player_x
  CLC
  ADC #$08
  STA $020f

  ; store tiles and sprite flags
  LDX #$00
  CPX is_moving
  BEQ standing
  JMP moving_down
standing:
  CPX player_dir
  BNE standing_left
  ; tiles
  LDA #$04
  STA $0201
  LDA #$05
  STA $0205
  LDA #$06
  STA $0209
  LDA #$07
  STA $020d
  ; flags
  LDA #$00
  STA $0202
  STA $0206
  STA $020a
  STA $020e
  JMP done

standing_left:
  INX
  CPX player_dir
  BNE standing_up
  ; tiles
  LDA #$14
  STA $0201
  LDA #$15
  STA $0205
  LDA #$16
  STA $0209
  LDA #$17
  STA $020d
  ; flags
  LDA #$00
  STA $0202
  STA $0206
  STA $020a
  STA $020e
  JMP done

standing_up:
  INX
  CPX player_dir
  BNE standing_right
  ; tiles
  LDA #$0C
  STA $0201
  LDA #$0D
  STA $0205
  LDA #$0E
  STA $0209
  LDA #$0F
  STA $020d
  ; flags
  LDA #$00
  STA $0202
  STA $0206
  STA $020a
  STA $020e
  JMP done
  
standing_right:
  INX
  CPX player_dir
  BNE standing_left
  ; tiles
  LDA #$15
  STA $0201
  LDA #$14
  STA $0205
  LDA #$17
  STA $0209
  LDA #$16
  STA $020d
  ; flags
  LDA #%01000000
  STA $0202
  STA $0206
  STA $020a
  STA $020e
  JMP done

moving_down:
  CPX player_dir
  BNE moving_left
  LDA #$08
  STA $0201
  LDA #$09
  STA $0205
  LDA #$00
  STA $0202
  STA $0206

  LDY #$00
  CPY player_walk
  BNE switch_down
  LDA #$0a
  STA $0209
  LDA #$0b
  STA $020d
  LDA #$00
  STA $020a
  STA $020e
  JMP done
switch_down:
  LDA #$0b
  STA $0209
  LDA #$0a
  STA $020d
  LDA #%01000000
  STA $020a
  STA $020e
  JMP done

moving_left:
  INX
  CPX player_dir
  BNE moving_up
  LDA #$00
  STA $0202
  STA $0206
  STA $020a
  STA $020e

  LDY #$00
  CPY player_walk
  BNE switch_left
  LDA #$18
  STA $0201
  LDA #$19
  STA $0205
  LDA #$1a
  STA $0209
  LDA #$1b
  STA $020d
  JMP done
switch_left:
  LDA #$1c
  STA $0201
  LDA #$1d
  STA $0205
  LDA #$1e
  STA $0209
  LDA #$1f
  STA $020d
  JMP done

moving_up:
  INX
  CPX player_dir
  BNE moving_right
  LDA #$10
  STA $0201
  LDA #$11
  STA $0205
  LDA #$00
  STA $0202
  STA $0206

  LDY #$00
  CPY player_walk
  BNE switch_up
  LDA #$12
  STA $0209
  LDA #$13
  STA $020d
  LDA #$00
  STA $020a
  STA $020e
  JMP done
switch_up:
  LDA #$13
  STA $0209
  LDA #$12
  STA $020d
  LDA #%01000000
  STA $020a
  STA $020e
  JMP done
moving_right:
  LDA #%01000000
  STA $0202
  STA $0206
  STA $020a
  STA $020e

  LDY #$00
  CPY player_walk
  BNE switch_right
  LDA #$19
  STA $0201
  LDA #$18
  STA $0205
  LDA #$1b
  STA $0209
  LDA #$1a
  STA $020d
  JMP done
switch_right:
  LDA #$1d
  STA $0201
  LDA #$1c
  STA $0205
  LDA #$1f
  STA $0209
  LDA #$1e
  STA $020d
done:
  ; restore registers and return
  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc read_controller1
  PHA
  TXA
  PHA
  PHP

  ; write a 1, then a 0, to CONTROLLER1
  ; to latch button states
  LDA #$01
  STA CONTROLLER1
  LDA #$00
  STA CONTROLLER1

  LDA #%00000001
  STA pad1

get_buttons:
  LDA CONTROLLER1 ; Read next button's state
  LSR A           ; Shift button state right, into carry flag
  ROL pad1        ; Rotate button state from carry flag
                  ; onto right side of pad1
                  ; and leftmost 0 of pad1 into carry flag
  BCC get_buttons ; Continue until original "1" is in carry flag

  PLP
  PLA
  TAX
  PLA
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


.segment "CHARS"
.incbin "sprites.chr"
