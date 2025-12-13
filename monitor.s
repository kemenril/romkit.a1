
; Assemble with xa -C wozmon.s

;-------------------------------------------------------------------------
;  Here's something to allow us to cook up ROMs which don't run the 
;    monitor in the conventional way.  Instead of booting the Woz monitor, 
;    they'll run the initialization code as usual, and then jump into 
;    something else, just as if we'd run it from the command shell.  This 
;    means that what's left of the command handler is three bytes ahead in 
;    the ROM, and it has no idea what to do with backspace.
;
;    Functions at the end do not move, and the software we want to run, runs.
;    To use this feature, define one of the EXBASIC or EXKRUSADER
;    convenience macros, or define AUTORUN directly to hold the address to
;    to which we'll pass control after initialization.
;
;    It turns out that this is far easier than flipping the reset vecor 
;    around, because initialization of the PIA is required for console I/O,
;    and if we change the vector, the code we're loading in has to do all 
;    the initialization that's already done at the default vector.
;
;-------------------------------------------------------------------------

#ifdef EXBASIC
#define AUTORUN	$E000
#endif

#ifdef EXKRUSADER
#define	AUTORUN	$F000
#endif

;-------------------------------------------------------------------------
;
;  The WOZ Monitor for the Apple 1
;  Written by Steve Wozniak 1976
;
;  Dissassembly by San Bergmans
;  Ported to the XA assembler and patched up to support automatic loading 
;    by Chris Smith 2025
;
;-------------------------------------------------------------------------
* = $FF00


;-------------------------------------------------------------------------
;  Part of the keymap/character set.
;-------------------------------------------------------------------------
#define		KEY_R		$D2
#define		KEY_ZERO	$B0
#define		KEY_NINE	$B9
#define		KEY_DOT		$AE
#define		KEY_COLON	$BA
#define		KEY_SPACE	$A0

;-------------------------------------------------------------------------
;  Memory declaration
;-------------------------------------------------------------------------

;Last "opened" location Low
#define		XAML    $24
;Last "opened" location High
#define		XAMH    $25
;Store address Low
#define		STL     $26
;Store address High
#define		STH     $27
;Hex value parsing Low
#define		L       $28
;Hex value parsing High
#define		H       $29
;Used to see if hex value is given
#define		YSAV    $2A
;$00=XAM, $7F=STOR, $AE=BLOCK XAM
#define		MODE    $2B

;Input buffer
; This was .EQ $0200,$027F, which doesn't seem to work here, but we probably
; only need the lower address.
#define		IN      $0200

;PIA.A keyboard input
#define		KBD     $D010
;PIA.A keyboard control register
#define		KBDCR   $D011
;PIA.B display output register
#define		DSP     $D012
;PIA.B display control register
#define		DSPCR   $D013

; KBD b7..b0 are inputs, b6..b0 is ASCII input, b7 is constant high
;     Programmed to respond to low to high KBD strobe
; DSP b6..b0 are outputs, b7 is input
;     CB2 goes low when data is written, returns high when CB1 goes high
; Interrupts are enabled, though not used. KBD can be jumpered to IRQ,
; whereas DSP can be jumpered to NMI.

;-------------------------------------------------------------------------
;  Constants
;-------------------------------------------------------------------------

;Backspace key, arrow left key
#define		BS      $DF
;Carriage Return
#define		CR      $8D
;ESC key
#define		ESC     $9B
;Prompt character
; Used to be "\", but this may need to be explicit.
#define		PROMPT	$DC

;-------------------------------------------------------------------------
;  Let's get started
;
;  Remark the RESET routine is only to be entered by asserting the RESET
;  line of the system. This ensures that the data direction registers
;  are selected.
;-------------------------------------------------------------------------

RESET           CLD                     ;Clear decimal arithmetic mode
                CLI
                LDY     #%01111111     ;Mask for DSP data direction reg
                STY     DSP             ; (DDR mode is assumed after reset)
                LDA     #%10100111     ;KBD and DSP control register mask
                STA     KBDCR           ;Enable interrupts, set CA1, CB1 for
                STA     DSPCR           ; positive edge sense/output mode.

#ifdef AUTORUN
; Defining AUTORUN causes us to jump to that address, instead of including 
;	the code here that's supposed to handle backspace.
;	Not ideal, but it allows us to easily generate ROM images which 
;       load BASIC on boot, for example.
		JMP	AUTORUN
		NOP	; Preserve the alignment of the functions down below.
#endif

; Program falls through to the GETLINE routine to save some program bytes
; Please note that Y still holds $7F, which will cause an automatic Escape

;-------------------------------------------------------------------------
; The GETLINE process
;-------------------------------------------------------------------------

#ifndef AUTORUN
NOTCR           CMP     #BS             ;Backspace key?
                BEQ     BACKSPACE       ;Yes
		CMP	#ESC		;ESC?
#else		; Then the entry point moves over here.
NOTCR           CMP     #ESC            ;ESC?
#endif

                BEQ     ESCAPE          ;Yes
                INY                     ;Advance text index
                BPL     NEXTCHAR        ;Auto ESC if line longer than 127

ESCAPE          LDA     #PROMPT         ;Print prompt character
                JSR     ECHO            ;Output it.

GETLINE         LDA     #CR             ;Send CR
                JSR     ECHO

                LDY     #0+1            ;Start a new input line
BACKSPACE       DEY                     ;Backup text index
                BMI     GETLINE         ;Oops, line's empty, reinitialize

NEXTCHAR        LDA     KBDCR           ;Wait for key press
                BPL     NEXTCHAR        ;No key yet!
                LDA     KBD             ;Load character. B7 should be '1'
                STA     IN,Y            ;Add to text buffer
                JSR     ECHO            ;Display character
                CMP     #CR
                BNE     NOTCR           ;It's not CR, back to the top!

; Line received, now let's parse it

                LDY     #$FF             ;Reset text index
                LDA     #0              ;Default mode is XAM
                TAX                     ;X=0

SETSTOR         ASL                     ;Leaves $7B if setting STOR mode

SETMODE         STA     MODE            ;Set mode flags

BLSKIP          INY                     ;Advance text index

NEXTITEM        LDA     IN,Y            ;Get character
                CMP     #CR
                BEQ     GETLINE         ;We're done if it's CR!
                CMP     #KEY_DOT
                BCC     BLSKIP          ;Ignore everything below "."!
                BEQ     SETMODE         ;Set BLOCK XAM mode ("." = $AE)
                CMP     #KEY_COLON
                BEQ     SETSTOR         ;Set STOR mode! $BA will become $7B
                CMP     #KEY_R
                BEQ     RUN             ;Run the program! Forget the rest
                STX     L               ;Clear input value (X=0)
                STX     H
                STY     YSAV            ;Save Y for comparison

; Here we're trying to parse a new hex value

NEXTHEX         LDA     IN,Y            ;Get character for hex test
                EOR     #$B0            ;Map digits to 0-9
                CMP     #9+1            ;Is it a decimal digit?
                BCC     DIG             ;Yes!
                ADC     #$88            ;Map letter "A"-"F" to $FA-FF
                CMP     #$FA            ;Hex letter?
                BCC     NOTHEX          ;No! Character not hex

DIG             ASL
                ASL                     ;Hex digit to MSD of A
                ASL
                ASL

                LDX     #4              ;Shift count
HEXSHIFT        ASL                     ;Hex digit left, MSB to carry
                ROL     L               ;Rotate into LSD
                ROL     H               ;Rotate into MSD's
                DEX                     ;Done 4 shifts?
                BNE     HEXSHIFT        ;No, loop
                INY                     ;Advance text index
                BNE     NEXTHEX         ;Always taken

NOTHEX          CPY     YSAV            ;Was at least 1 hex digit given?
                BEQ     ESCAPE          ;No! Ignore all, start from scratch

                BIT     MODE            ;Test MODE byte
                BVC     NOTSTOR         ;B6=0 is STOR, 1 is XAM or BLOCK XAM

; STOR mode, save LSD of new hex byte

                LDA     L               ;LSD's of hex data
                STA     (STL,X)         ;Store current 'store index'(X=0)
                INC     STL             ;Increment store index.
                BNE     NEXTITEM        ;No carry!
                INC     STH             ;Add carry to 'store index' high
TONEXTITEM      JMP     NEXTITEM        ;Get next command item.

;-------------------------------------------------------------------------
;  RUN user's program from last opened location
;-------------------------------------------------------------------------

RUN             JMP     (XAML)          ;Run user's program

;-------------------------------------------------------------------------
;  We're not in Store mode
;-------------------------------------------------------------------------

NOTSTOR         BMI     XAMNEXT         ;B7 = 0 for XAM, 1 for BLOCK XAM

; We're in XAM mode now

                LDX     #2              ;Copy 2 bytes
SETADR          LDA     L-1,X           ;Copy hex data to
                STA     STL-1,X         ; 'store index'
                STA     XAML-1,X        ; and to 'XAM index'
                DEX                     ;Next of 2 bytes
                BNE     SETADR          ;Loop unless X = 0

; Print address and data from this address, fall through next BNE.

NXTPRNT         BNE     PRDATA          ;NE means no address to print
                LDA     #CR             ;Print CR first
                JSR     ECHO
                LDA     XAMH            ;Output high-order byte of address
                JSR     PRBYTE
                LDA     XAML            ;Output low-order byte of address
                JSR     PRBYTE
                LDA     #KEY_COLON            ;Print colon
                JSR     ECHO

PRDATA          LDA     #KEY_SPACE            ;Print space
                JSR     ECHO
                LDA     (XAML,X)       ;Get data from address (X=0)
                JSR     PRBYTE          ;Output it in hex format
XAMNEXT         STX     MODE            ;0 -> MODE (XAM mode).
                LDA     XAML            ;See if there's more to print
                CMP     L
                LDA     XAMH
                SBC     H
                BCS     TONEXTITEM      ;Not less! No more data to output

                INC     XAML            ;Increment 'examine index'
                BNE     MOD8CHK         ;No carry!
                INC     XAMH

MOD8CHK         LDA     XAML            ;If address MOD 8 = 0 start new line
                AND     #%00000111
                BPL     NXTPRNT         ;Always taken.

;-------------------------------------------------------------------------
;  Subroutine to print a byte in A in hex form (destructive)
;-------------------------------------------------------------------------

PRBYTE          PHA                     ;Save A for LSD
                LSR
                LSR
                LSR                     ;MSD to LSD position
                LSR
                JSR     PRHEX           ;Output hex digit
                PLA                     ;Restore A

; Fall through to print hex routine

;-------------------------------------------------------------------------
;  Subroutine to print a hexadecimal digit
;-------------------------------------------------------------------------

PRHEX           AND     #%00001111      ;Mask LSD for hex print
                ORA     #KEY_ZERO       ;Add "0"
                CMP     #KEY_NINE+1     ;Is it a decimal digit?
                BCC     ECHO            ;Yes! output it
                ADC     #6              ;Add offset for letter A-F

; Fall through to print routine

;-------------------------------------------------------------------------
;  Subroutine to print a character to the terminal
;-------------------------------------------------------------------------

ECHO            BIT     DSP             ;DA bit (B7) cleared yet?
                BMI     ECHO            ;No! Wait for display ready
                STA     DSP             ;Output character. Sets DA
                RTS

;-------------------------------------------------------------------------
;  The vector map from the original dump.  By putting it back, we can create
;  the whole thing from this source.
;  It is entirely possible that not all of it is useful.
;-------------------------------------------------------------------------

	; Empty space between the monitor and the vector map.
	.word	$0000
	; This is the NMI vector.  It will apparently not be used because that
	;	line is unconnected in the Apple 1.
	.word	$0f00
	; In the context of the system memory map, this is the reset vector.
	;	We just point it to the reset function up above.
	.word	RESET
	; Originally there were two free bytes at the end of the 256-bute ROM
	.word	$0000		

;-------------------------------------------------------------------------

