;Modified: April 2014
;by: Phillip Marr
;for: EE 3752 semester project - make a gameboy game

;Original below
; Hello Sprite Good Delay 1.0
; February 19, 2007
; John Harrison

; An extension of Hello World, based mostly from GALP

;The INCLUDE instructions is a macro the RGBDS compiler recognizes. It is not a part of the Z80 assembly language
INCLUDE "gbhw.inc" ; standard hardware definitions from devrs.com
INCLUDE "ibmpc1.inc" ; ASCII character set from devrs.com
INCLUDE "stddefs.inc" ; specific defs, http://cratel.wichita.edu/cratel/ECE238Spr08
INCLUDE "incdecss.inc"	; devrs.com for increment 16 bit registers without corrupting OAM (sprite) RAM

;SpriteAttr Macro define in stddefs.inc
;Sprite attibutes are defined further down in code after the instruction pages code
;Sprite0 is the player controlled object
;Sprite1 is the apple, the pseudo-randomly generated object (apple) that changes position when its 8x8 block overlaps the player's object
;Sprites 2,3,4,5 spawn around apple object, cause gameover if touched by player
	SpriteAttr	Sprite0 
	SpriteAttr	Sprite1
	SpriteAttr	Sprite2
	SpriteAttr	Sprite3
	SpriteAttr	Sprite4
	SpriteAttr	Sprite5
	
; IRQs
SECTION	"Vblank",HOME[$0040]
	jp	DMACODELOC ; *hs* update sprites every time the Vblank interrupt is called (~60Hz)
SECTION	"LCDC",HOME[$0048]
	reti
SECTION	"Timer_Overflow",HOME[$0050]
	jp	TimerInterrupt		; flag the timer interrupt
SECTION	"Serial",HOME[$0058]
	reti
SECTION	"p1thru4",HOME[$0060]
	reti

; ****************************************************************************************
; boot loader jumps to here.
; ****************************************************************************************
SECTION	"start",HOME[$0100]
nop
jp	begin

; ****************************************************************************************
; ROM HEADER and ASCII character set
; ****************************************************************************************
; ROM header, MACRO defined in gbhw.inc, Passed parameters are 0,0,0
	ROM_HEADER	ROM_NOMBC, ROM_SIZE_32KBYTE, RAM_SIZE_0KBYTE
INCLUDE "gbrandom.asm"	;creates random seed based on time between key presses,
	;Help on using Rand16 from: http://cratel.wichita.edu/cratel/ECE238Spr08/tutorials/Random 
INCLUDE "memory.asm"	;writes data to memory or changes to Video RAM
INCLUDE "print-number.asm"	;for use in creating a score 
INCLUDE "easyscore.asm"		;prints a score to the bottom left hand of the screen from: http://cratel.wichita.edu/cratel/ECE238Spr08/tutorials/EasyScore
TileData:
	chr_IBMPC1	1,8 ; LOAD ENTIRE CHARACTER SET, defined in ibmpc1.inc

; ****************************************************************************************
; Main code Initialization:
; set the stack pointer, enable interrupts, set the palette, set the screen relative to the window
; copy the ASCII character table, clear the screen
; ****************************************************************************************
begin:
	nop
	di				; disable interrupts
	ld	sp, $ffff		; set the stack pointer to highest mem location + 1
	;stack is LIFO and decrements after init, so points to $FFFE

; NEXT FOUR LINES FOR SETTING UP SPRITES *hs*
	call	initdma			; move routine to High RAM
	ld	a, IEF_VBLANK|IEF_TIMER
	ld	[rIE],a			; $FFFF, ENABLE VBLANK AND TIMER INTERRUPT
	ei					; enable interrupts

init:
	ld	a, %11100100 		; Window palette colors, from darkest to lightest
	ld	[rBGP], a		; set background and window pallette
	ldh	[rOBP0],a		; set sprite pallette 0 (choose palette 0 or 1 when describing the sprite)
	ldh	[rOBP1],a		; set sprite pallette 1

	ld	a,0			; SET SCREEN TO TO UPPER LEFT HAND CORNER. 0,0
	ld	[rSCX], a		; $FF42, Scroll Screen Y
	ld	[rSCY], a		; $FF43, Scroll Screen X
	call	StopLCD		; You can not load over adress $8000 with LCD on
	ld	hl, TileData	; source, the IBM pc character set
	ld	de, _VRAM	; destination, $8000, VRAM
	ld	bc, 8*256 		; bytecount of source, b=8,c=256, 8 bytes a character, 256 of them. ASCII character set
	call	mem_CopyMono	; load tile data, MACRO defined in memory.asm

; *hs* erase sprite table
	ld	a,0
	ld	hl,OAMDATALOC	;source, OAMDATALOC defined in stddefs.inc, starts at _RAM ($C000)
	ld	bc,OAMDATALENGTH	;length, $A0, 100
	call	mem_Set			;defined in memory.asm

	;_ON - turns on LCD, 
	;_WIN9C00- sets window address to Tile Map 2 ($9c00)
	;_WINON - turns on windows
	;_BG8000 - sets background to display tile values from 0-255 (which means window, background, and sprites can both pull from this area)
	;_BG9800 - sets background address to Tile Map 1 ($9800)
	;_BGON - turns background on
	;_OBJ8 - sets sprite sizes to 8x8
	;_OBJON - turns sprites on
	;ld	a, LCDCF_ON|LCDCF_WIN9C00|LCDCF_WINON|LCDCF_BG8000|LCDCF_BG9800|LCDCF_BGON|LCDCF_OBJ8|LCDCF_OBJON ; *hs* see gbspec.txt lines 1525-1565 and gbhw.inc lines 70-86
	ld	a, LCDCF_ON|LCDCF_BG8000|LCDCF_BG9800|LCDCF_BGON|LCDCF_OBJ8|LCDCF_OBJON ; *hs* see gbspec.txt lines 1525-1565 and gbhw.inc lines 70-86
	;	gbhw.inc - %1000 0000|%0100 0000|%0010 0000|%0001 0000|%0000 0000|%0000 0001|%0000 0000|%0000 0010
	;	I can only assume the ld above is adding all those bit values together,
	ld	[rLCDC], a	; $FF40 LCD control
	
;clear the background tiles
	ld	a, 32			; ASCII for blank space $20, SP. clear the tiles
	ld	hl, _SCRN0	; $9800 Tile map 1 in VRAM
	ld	bc, SCRN_VX_B * SCRN_VY_B	; ;virtual width and height in bytes 32*32. ;virtual pixels would be 256*256
	call	mem_SetVRAM	;defined in memory.asm
;clear the window tiles - this in is done when we call easyScoreInit
	;ld	a,32
	;ld	hl,_SCRN1
	;ld	bc,SCRN_VX_B * SCRN_VY_B
	;call	mem_SetVRAM
; ****************************************************************************************
; Main code:
; Define variables, setup timer interrupt, call instruction pages, setup sprites' attributes
; Modified from hello-sprite-good-delay by me
; ****************************************************************************************
Variables:
;LoByteVar is a MACRO from stddefs.inc
;prev_dir stores in memory the last pressed button (specifically the direction keys) to move player continuously in that direction	
;IFlags keeps track of the interrupts that have occured
;GameOverF is set to 1 if a game over event should be called
;TimerEvent is a flag that a timer interrupt has occurred.
	LoByteVar		prev_dir
	LoByteVar		IFlags
	LoByteVar		GameOverF
	LoByteVar		TimerEvent 
;set all flags to zero. TimerEvent is set in TimerInterrupt subroutine.
	ld			a,$0
	ld			[prev_dir],a
	ld			[IFlags],a
	ld			[GameOverF],a
	
	call	TimerInterrupt	;enable the timer to set the speed of loops
	
;The following display the instructions and the start game page
;Pressing Right scrolls one page over, and Left goes back. On the third page, pressing Up starts the game
;In order to slow down the page switching to the next one I added artificial loading
;A couple hundred microseconds is way to fast. By the time you finished pressing right the first time, you would be on the last page
;Initially I had it display a loading screen, but realized if I just displayed the current screen and waited an amount of time, it would solve my too fast switching problem
;Another issue was that if a different direction wasn't pressed between the second and third page, it would not switch
;to compensate for this, I simulate the pressing of a key not used for that page, in between each page. 
;Order of pages displayed are: Pg1,2,3, the actual game, PgGameOver, Pg4
;PgGameOver is below MainLoop, set up as another loop. It made more sense for the Gameover display to be below the actual game display when reading code.
;All code until the label "sprsetup:" is my own logic. The rest of my code begins after after the hard coded data(just below the main loop)
StartPg1:
	call	LdLoop	;waits an amount of time while keeping current display
	;call	Pg1
;Displays first page of instructions
Pg1:
	call	ClearScreen	;clears screen by drawing blank spaces in the viewable space
	ld	hl,Instructions
	ld	de,_SCRN0+(SCRN_VY_B*3)	;$9800, Tile Map 1 plus whatever that is
	ld	bc,InstructionsOneEnd-Instructions
	call	mem_CopyVRAM
	ld	a,%00001000		;set last pressed key to something other than the needed key press
	ld	[prev_dir],a
.InstructionLoop
	call	TimeDelay		;waits an amount of time
	call	GetKeys		;accept user input
	cp	$1			;%0001 right key is pressed, go to Pg2
	jr	nz,.InstructionLoop
StartPg2:
	call	LdLoop
	;call	Pg2
;Displays second page of instructions
Pg2:
	call	ClearScreen	;overwrite previous page display, then draw new page
	ld	hl,InstructionsTwo
	ld	de,_SCRN0+(SCRN_VY_B*4)	;$9800, Tile Map 1 plus whatever that is
	ld	bc,InstructionsTwoEnd-InstructionsTwo
	call	mem_CopyVRAM
	ld	a,%00001000	;set last pressed key to something other than the needed key press
	ld	[prev_dir],a
.InstructionTwoLoop
	call	TimeDelay
	call	GetKeys
	cp	$2				;%0010 left is pressed, go back to Pg1
	jr	z,StartPg1
	cp	$1				;%0001 right is pressed, go to Pg3
	jr	nz,.InstructionTwoLoop
StartPg3:
	call	LdLoop
	;call	Pg3
;Displays game start page
Pg3:
	call	ClearScreen
	ld	hl,InstructionsThree
	ld	de,_SCRN0+(SCRN_VY_B*4)	;$9800, Tile Map 1 plus whatever that is
	ld	bc,InstructionsThreeEnd-InstructionsThree
	call	mem_CopyVRAM
	ld	a,%00000001		;set last pressed key to something other than the needed key press
	ld	[prev_dir],a
	call	MakeRandomSeedByTimingKeypress
.InstructionThreeLoop
	call	TimeDelay
	call	GetKeys
	cp	$2				;%0010 left is pressed, go back to Pg2
	jr	z,StartPg2
	cp	$4				;%0100 up is pressed, begin game
	jr	nz,.InstructionThreeLoop
	jr	skipPg4			;Leads into MainLoop where the game play takes place after setting up sprites
StartPg4:
	call	LdLoop
	;call	Pg4
;displays highscores
;This page is out of order, as PgGameOver happens before this page. 
Pg4:
	call	ClearScreen
	ld	hl,InstructionsFour
	ld	de,_SCRN0+(SCRN_VY_B*1)	;$9800, Tile Map 1 plus whatever that is
	ld	bc,InstructionsFourEnd-InstructionsFour
	call	mem_CopyVRAM
	ld	a,%00000001		;set last pressed key to something other than the needed key press
	ld	[prev_dir],a
.InstructionFourLoop
	call	TimeDelay
	call	GetKeys
	cp	$2				;%0010 left is pressed, go back to game over screen
	jp	z,GameOverLoop
	cp	$8				;%0100 down is pressed, go to Pg1, view instruction pages
	jp	z,StartPg1
	cp	$4				;%0100 up is pressed, begin game
	jr	nz,.InstructionFourLoop
skipPg4:	
	ld	a,%00000000	;clear key presses so player does not move from pressing a key to change pages
	ld	[prev_dir],a
	call	PgLoading		;add artificial loading screen
	call	PgLoading		;this way, if a key is held when starting game,
	call	PgLoading		;there isn't instaneous movement before player is ready
	call	PgLoading
	call	ClearScreen
	
;End of my code for now, the following is modified from hello-sprite-good-delay
	call	easyScoreInit		;from easyscore.asm, intializes the score at bottom left of screen
sprsetup:
;initialize Sprite0 (player)
	PutSpriteYAddr	Sprite0,40	; column
	PutSpriteXAddr	Sprite0,60	; row
 	ld	a,18				;tiles from ibmpc1.inc
 	ld 	[Sprite0TileNum],a     ;sprite 0's tile address
 	ld	a,%00000000         	;set flags (see gbhw.inc lines 33-42)
 	ld	[Sprite0Flags],a   	;save flags
	ld	[Sprite1Flags],a		;set the other sprites flags here instead of having to load A with zero 5 times. saves cycles
	ld	[Sprite2Flags],a
	ld	[Sprite3Flags],a
	ld	[Sprite4Flags],a
	ld	[Sprite5Flags],a
	
;Initialize Sprite1 (object to grab, described as apple in code. Looks like a circle.)
	PutSpriteYAddr	Sprite1,40	; row
	PutSpriteXAddr	Sprite1,70	; column
 	ld	a,7				;tiles from ibmpc1.inc
 	ld 	[Sprite1TileNum],a     ;sprite 1's tile address
;Initialize Sprite2 (block that causes game over when player runs into)
	PutSpriteYAddr	Sprite2,50	; row
	PutSpriteXAddr	Sprite2,70	; column
 	ld	a,8				;tiles from ibmpc1.inc
 	ld 	[Sprite2TileNum],a     ;sprite 2's tile address
;Initialize Sprite3 (block that causes game over when player runs into)
	PutSpriteYAddr	Sprite3,30	; row
	PutSpriteXAddr	Sprite3,70	; column
 	ld	a,8				;tiles from ibmpc1.inc
 	ld 	[Sprite3TileNum],a     ;sprite 3's tile address
;Initialize Sprite4 (block that causes game over when player runs into)
	PutSpriteYAddr	Sprite4,40	; row
	PutSpriteXAddr	Sprite4,80	; column
 	ld	a,8				;tiles from ibmpc1.inc
 	ld 	[Sprite4TileNum],a     ;sprite 4's tile address
;Initialize Sprite5 (block that causes game over when player runs into)
	PutSpriteYAddr	Sprite5,40	;row
	PutSpriteXAddr	Sprite5,40	;column
	ld	a,8				;from ibmpc1.inc
	ld	[Sprite5TileNum],a	;sprite 5's tile address
	
	call	easyScoreReset		;If entering MainLoop, score must be 0. defined in easyscore.asm

; ****************************************************************************************
; MainLoop:
; Sets speed of loop with TimeDelay, checks for buttons pressed (down, up, left, right) and moves accordingly
; Checks for gameover flag to jump to GameOverLoop
; Movement is inverted for artificial difficulty. Eg. when the up button is pressed, the player moves down
; Modified from hello-sprite-good-delay by me
; ****************************************************************************************
MainLoop:
	call	TimeDelay		;set's loop speed based on timer interrupt
	call	GetKeys		;only grabs down, up, left, and right. Stores last pressed direction in prev_dir
	push	af
	ld	a,[prev_dir]
	and	PADF_RIGHT	;0001
	call	nz,left;right
	pop	af
	push	af
	ld	a,[prev_dir]
	and	PADF_LEFT	;0010
	call	nz,right;left
	pop	af
	push	af
	ld	a,[prev_dir]
	and	PADF_UP		;0100
	call	nz,down;up
	pop	af
	push	af
	ld	a,[prev_dir]
	and	PADF_DOWN	;1000
	call	nz,up;down
	pop	af
	push	af
	ld	a,[GameOverF]
	cp	$1
	jr	z,GameOverLoop
	pop		af
	jr	MainLoop

;Displays the game over screen and quits MainLoop
;MyCode
GameOverLoop:
	ld	a,%00000000
	ld	[GameOverF],a	;reset Game Over flag
PgGameOver:
	call	ClearScreen
	; *hs* erase sprite table
	ld	a,0
	ld	hl,OAMDATALOC	;source, OAMDATALOC defined in stddefs.inc, starts at _RAM ($C000)
	ld	bc,OAMDATALENGTH	;length, $A0, 100
	call	mem_Set			;defined in memory.asm
	ld	hl,GameOver
	ld	de,_SCRN0+(SCRN_VY_B*3)	;$9800, Tile Map 1 plus whatever that is
	ld	bc,GameOverEnd-GameOver
	call	mem_CopyVRAM
	ld	a,%00010000
	ld	[prev_dir],a
.GameOverLoop
	call	TimeDelay
	ld	a,%00010000		;set prev key pressed to a key we're not using to navigate pages
	ld	[prev_dir],a
	call	GetKeys
	cp	$1				;%0001 right is pressed, view highscore page
	jp	z,StartPg4
	cp	$4				;%0100 up is pressed, begin game
	;call	z,.addUpText
	jp	z,skipPg4
	cp	$8				;%0100 down is pressed, view instructions Pg1
	jr	nz,.GameOverLoop
	jp	StartPg1		;flags carry over from PgGameOver
	
; ****************************************************************************************
; hard-coded data
;20 visible character, 10 hidden
;List of pages and their character data sets:
;Pg1 = Instructions
;Pg2 = InstructionsTwo
;Pg3 = InstructionsThree
;Pg4 = InstructionsFour == high scores page
;PgLoading = Loading
;PgGameOver = GameOver
; ****************************************************************************************
Clear:
	DB	"                    xxxxxxxxxxxx" ;1
	DB	"                    xxxxxxxxxxxx" ;2
	DB	"                    xxxxxxxxxxxx" ;3
	DB	"                    xxxxxxxxxxxx" ;4
	DB	"                    xxxxxxxxxxxx" ;5
	DB	"                    xxxxxxxxxxxx" ;6
	DB	"                    xxxxxxxxxxxx" ;7
	DB	"                    xxxxxxxxxxxx" ;8
	DB	"                    xxxxxxxxxxxx" ;9
	DB	"                    xxxxxxxxxxxx" ;10
	DB	"                    xxxxxxxxxxxx" ;11
	DB	"                    xxxxxxxxxxxx" ;12
	DB	"                    xxxxxxxxxxxx" ;13
	DB	"                    xxxxxxxxxxxx" ;14
	DB	"                    xxxxxxxxxxxx" ;15
	DB	"                    xxxxxxxxxxxx" ;16
ClearEnd:
;Note: the Up is Down and Down is Up applies to instruction screen where they say press Up to begin. That means the player really has to press down
;When <- or -> is shown, that means the literal key and not left and right. So <- and -> are not inverted
Instructions:
	;DB	"xxxxxxxxxxxxxxxxxxxx" ;visible 20
	;DB 	"xxxxxxxxxxxx" ;invisible 12
	DB	"You move in last    xxxxxxxxxxxx"
	DB	"pressed direction.  xxxxxxxxxxxx"
	DB	"Game controls are   xxxxxxxxxxxx"
	DB	"inverted:           xxxxxxxxxxxx"	
	DB	"Up is Down.         xxxxxxxxxxxx"
	DB	"Down is Up.         xxxxxxxxxxxx"
	DB	"Right is Left.      xxxxxxxxxxxx"
	DB	"Left is Right.      xxxxxxxxxxxx"
	DB	"                    xxxxxxxxxxxx"
	DB	"Press <- or -> key  xxxxxxxxxxxx"
	DB	"to change the page  xxxxxxxxxxxx"
	DB	"                    xxxxxxxxxxxx"
	DB	"                    xxxxxxxxxxxx"	
	DB	"            pg1 of 3"	;right aligned
InstructionsOneEnd:
InstructionsTwo:
	DB	"Run into the ball toxxxxxxxxxxxx"
	DB	"make it randomly go xxxxxxxxxxxx"
	DB	"to another spot. Onexxxxxxxxxxxx"
	DB	"point for each ball.xxxxxxxxxxxx"
	DB	"                    xxxxxxxxxxxx"
	DB	"Be careful around   xxxxxxxxxxxx"
	DB	"blocks and walls!   xxxxxxxxxxxx"
	DB	"                    xxxxxxxxxxxx"
	DB	"Press <- or -> key  xxxxxxxxxxxx"
	DB	"to change the page  xxxxxxxxxxxx"	
	DB	"                    xxxxxxxxxxxx"	
	DB	"                    xxxxxxxxxxxx"
	DB	"            pg2 of 3"	;right aligned
InstructionsTwoEnd:
InstructionsThree:
	DB 	"      GAME ON       xxxxxxxxxxxx"
	DB	"                    xxxxxxxxxxxx"
	DB	"                    xxxxxxxxxxxx"
	DB	" Reminder: controls xxxxxxxxxxxx"
	DB	"in game are INVERTEDxxxxxxxxxxxx"
	DB	"                    xxxxxxxxxxxx"
	DB	"    Tap DOWN Key    xxxxxxxxxxxx"
	DB	"  then Press UP Key xxxxxxxxxxxx"
	DB	"      to Start      xxxxxxxxxxxx"
	DB	"                    xxxxxxxxxxxx"
	DB	"                    xxxxxxxxxxxx"
	DB	"                    xxxxxxxxxxxx"
	DB	"            pg3 of 3"
InstructionsThreeEnd:
;unused
InstructionsFour:
	DB 	"     Highscores     xxxxxxxxxxxx"
;	DB	"                    xxxxxxxxxxxx"
	DB	"XXXXXXX:    ####    xxxxxxxxxxxx"
	DB	"                    xxxxxxxxxxxx"
	DB	"XXXXXXX:    ####    xxxxxxxxxxxx"
	DB	"                    xxxxxxxxxxxx"
	DB	"XXXXXXX:    ####    xxxxxxxxxxxx"
	DB	"                    xxxxxxxxxxxx"
	DB	"XXXXXXX:    ####    xxxxxxxxxxxx"
	DB	"                    xxxxxxxxxxxx"
	DB	"XXXXXXX:    ####    xxxxxxxxxxxx"
	DB	"                    xxxxxxxxxxxx"
	DB	"XXXXXXX:    ####    xxxxxxxxxxxx"
	DB	"                    xxxxxxxxxxxx"
	DB	"Press <-, UP or Downxxxxxxxxxxxx"
	DB	"                    xxxxxxxxxxxx"
	DB	"YOU:                xxxxxxxxxxxx"
InstructionsFourEnd:

Loading:
	DB	"      LOADING                    "
	DB	"                                  "
	DB	"                                 "
	DB	"PLEASE WAIT..."
LoadingEnd:

GameOver:
	DB 	"     GAME OVER!     xxxxxxxxxxxx"
	DB	"                    xxxxxxxxxxxx"
	DB	"                    xxxxxxxxxxxx"
	DB	"      Press Up      xxxxxxxxxxxx"
	DB	"   to Play Again!   xxxxxxxxxxxx"
	DB	"                    xxxxxxxxxxxx"
	DB	"                    xxxxxxxxxxxx"
	DB	"     Press Down     xxxxxxxxxxxx"
	DB	"to view instructionsxxxxxxxxxxxx"
	DB	"                    xxxxxxxxxxxx"
	DB	"                    xxxxxxxxxxxx"
	DB	"    Press -> for    xxxxxxxxxxxx"
	DB	"   highscore page   xxxxxxxxxxxx"
	DB	"                    xxxxxxxxxxxx"

GameOverEnd:

; ****************************************************************************************
; Beginning of my code
; ****************************************************************************************
; GetKeys: adapted from gbspec.txt
GetKeys:                 ;gets keypress
;Initially 0=on,1=off though a compliment of bits will set it opposite
;See gbspec.txt lines 1019-1095
;With P14=0 (on) we can utilize rP1 for down up left right button presses
	ld 	a,P1F_5			; set bit 5 which means we have P15=1(off) and P14=0(on)
	ld 	[rP1],a			; select P14 by setting it low.
	ld 	a,[rP1]
 	ld 	a,[rP1]			; wait a few cycles for bounce
	cpl				; complement A to make on=1 and 0=off
	and 	$0f			; look at only the first 4 bits 
	ld	c,a		;c holds current button press
	ld	a,[prev_dir]	;prev_dir is a LoByteVar in low RAM
	ld 	b,a		;b hold previous direction
	ld	a,c		;give a the current button press
	or	b		;combine previous and current presses
	xor	b		;isolate only new presses
	ret	z		;if no new changes, return and keep old prev_dir value
	ld	[prev_dir],a	;else load in new direction
 	ret

;Move sprite right by one x pos. 144 possible positions
;Checks positions against blocks, apple, and right hand wall. Collision is based on overlapping coordinates
;If player at right edge of screen, set gameover flag
right:
	GetSpriteXAddr	Sprite0
	ld		b,a	;player position
	cp		SCRN_X-8	; already on RHS of screen?
	;jr		z,.bounceLeft
	call		z,gameover
	ret		z
	call		CompColSpr2	;compares row and column positions of sprite0 and 2, sets z flag if positions are equal
	ld		a,[GameOverF]
	cp		1
	ret		z
	call		CompColSpr3	;compares row and column positions of sprite0 and 2, sets z flag if positions are equal
	ld		a,[GameOverF]
	cp		1
	ret		z
	call		CompColSpr4	;compares row and column positions of sprite0 and 2, sets z flag if positions are equal
	ld		a,[GameOverF]
	cp		1
	ret		z
	call		CompColSpr5	;compares row and column positions of sprite0 and 2, sets z flag if positions are equal
	ld		a,[GameOverF]
	cp		1
	ret		z
	call CompCol		;this will compare row and column positions of sprite0 and 1
	inc		b	
	PutSpriteXAddr	Sprite0,b
	ret
.bounceLeft	;old code where player would bounce off wall instead of getting a gamevoer
	dec		b
	PutSpriteXAddr	Sprite0,b
	ld		a,%00000010	;down up left right = 0010
	ld		[prev_dir],a
	ret
;Identical to right: except this checks lefthand wall
left:	GetSpriteXAddr	Sprite0
	ld		b,a	;player position
	cp		0		; already on LHS of screen?
	call		z,gameover
	ret		z
	call		CompColSpr2	;compares row and column positions of sprite0 and 2, sets z flag if positions are equal
	ld		a,[GameOverF]
	cp		1
	ret		z
	call		CompColSpr3	;compares row and column positions of sprite0 and 2, sets z flag if positions are equal
	ld		a,[GameOverF]
	cp		1
	ret		z
	call		CompColSpr4	;compares row and column positions of sprite0 and 2, sets z flag if positions are equal
	ld		a,[GameOverF]
	cp		1
	ret		z
	call		CompColSpr5	;compares row and column positions of sprite0 and 2, sets z flag if positions are equal
	ld		a,[GameOverF]
	cp		1
	ret		z
	call CompCol
	dec		b	
	PutSpriteXAddr	Sprite0,b
	ret	
;identical to right: except this checks upper wall
up:	GetSpriteYAddr	Sprite0
	ld		c,a
	cp		0		; already at top of screen?
	call		z,gameover
	ret		z
	GetSpriteXAddr	Sprite0
	ld		b,a
	call		CompColSpr2	;compares row and column positions of sprite0 and 2, sets z flag if positions are equal
	ld		a,[GameOverF]
	cp		1
	ret		z
	call		CompColSpr3	;compares row and column positions of sprite0 and 2, sets z flag if positions are equal
	ld		a,[GameOverF]
	cp		1
	ret		z
	call		CompColSpr4	;compares row and column positions of sprite0 and 2, sets z flag if positions are equal
	ld		a,[GameOverF]
	cp		1
	ret		z
	call		CompColSpr5	;compares row and column positions of sprite0 and 2, sets z flag if positions are equal
	ld		a,[GameOverF]
	cp		1
	ret		z
	call	CompCol
	dec		c
	PutSpriteYAddr	Sprite0,c
	ret
;identical to right: except this checks lower wall
down:	GetSpriteYAddr	Sprite0
	ld		c,a
	cp		SCRN_Y-8	; already at bottom of screen?
	call		z,gameover	
	ret		z
	GetSpriteXAddr	Sprite0
	ld		b,a
	call		CompColSpr2	;compares row and column positions of sprite0 and 2, sets z flag if positions are equal
	ld		a,[GameOverF]
	cp		1
	ret		z
	call		CompColSpr3	;compares row and column positions of sprite0 and 2, sets z flag if positions are equal
	ld		a,[GameOverF]
	cp		1
	ret		z
	call		CompColSpr4	;compares row and column positions of sprite0 and 2, sets z flag if positions are equal
	ld		a,[GameOverF]
	cp		1
	ret		z
	call		CompColSpr5	;compares row and column positions of sprite0 and 2, sets z flag if positions are equal
	ld		a,[GameOverF]
	cp		1
	ret		z
	call CompCol
	inc		c
	PutSpriteYAddr	Sprite0,c
	ret
gameover:
	ld	a,%00000001
	ld	[GameOverF],a
	cp	1		;I compare to 1, to set Z flag. there were issues if I tried returning using nz (not Z flag implies equivalence, so it is not a "Zero" flag like ARM)
	ret	z
LoadsOMoney:			;old code to set score really high.
	ld	hl,$777	
	call	easyScoreSet	;cheat by setting score to 777, musta been lucky huh? Bonus points....
	ret
	
;Compares an 8x8 collision box around apple (Sprite1) to player (Sprite0) to see if coords overlap
;reg b hold player's xpos (column) and reg c hold player's ypos (row)
;This assumes that sprites positions start in middle of 8x8 block
;We first compare if any columns match between the player and the apple
;If so then we check for any matching rows
;If both match, we call GotPoint which psuedo-randomly generates a new position for the apple
;CompCol checks Sprite1's position to a single 1x1 byte on Sprite0
CompCol:
	GetSpriteXAddr	Sprite1
	add		a,5	;increment 4 in x direction (columns). Set to 5 because we decrement at start of loop.
	ld		d,9	;counter (9 because on eigth iteration d is set to 0 and we never go a 9th iteration. we jump to CompRow). 
				;We want to check 8 units of columns
.loopC
	dec		a	;decrement apple's column
	cp		b	;Compare if equal to player's xpos
	jr		z,.CompRow	;if equal, check row values
	dec		d	;else decrement counter
	jr		nz,.loopC	;jump to start of loop if not zero yet
	ret			;if no equal columns, return
	
.CompRow
	GetSpriteYAddr	Sprite0
	ld		c,a	;store players ypos in c
	GetSpriteYAddr	Sprite1
	add		a,5	;increment 4 in y direction (rows). Set to 5 same as above
	ld		d,9	;counter. Same as above except this is to check 8 units of rows
.loopR
	dec		a	;decrement apple's row
	cp		c	;compare if equal to player's ypos
	call		z,GotPoint	;if same, reposition apple
	dec		d	;else decrement counter
	jr		nz,.loopR	;loop if not zero
	ret			;if no equal rows, return
	
CompColSpr2:
;if positions of player and sprite2 are equal, call gameover:. 
;Almost a carbon copy of CompCol just instead checks sprite2 instead of sprite1 and calls gameover instead of GotPoint
	GetSpriteXAddr	Sprite2
	add		a,5	;store sprite2 (a box) X pos in A
	ld		d,9	;
.loopC2
	dec		a
	cp		b
	jr		z,.CompRowSpr2
	dec		d
	jr		nz,.loopC2
	ret

.CompRowSpr2
	GetSpriteYAddr	Sprite0
	ld		c,a	;Store players ypos
	GetSpriteYAddr	Sprite2
	add		a,5
	ld		d,9
.loopR2
	dec		a
	cp		c
	call		z,gameover
	dec		d
	jr		nz,.loopR2
	ret
	
CompColSpr3:
;if positions of player and sprite3 are equal, call gameover:. 
;Almost a carbon copy of CompColSpr2 just instead checks sprite3 instead of sprite2
	GetSpriteXAddr	Sprite3
	add		a,5	;store sprite3(a box) X pos in A
	ld		d,9	;
.loopC3
	dec		a
	cp		b
	jr		z,.CompRowSpr3
	dec		d
	jr		nz,.loopC3
	ret

.CompRowSpr3
	GetSpriteYAddr	Sprite0
	ld		c,a	;Store players ypos
	GetSpriteYAddr	Sprite3
	add		a,5
	ld		d,9
.loopR3
	dec		a
	cp		c
	call		z,gameover
	dec		d
	jr		nz,.loopR3
	ret
	
CompColSpr4:
;if positions of player and sprite4 are equal, call gameover:. 
;Almost a carbon copy of CompCol2 just instead checks sprite4 instead of sprite2
	GetSpriteXAddr	Sprite4
	add		a,5	;store sprite4 (a box) X pos in A
	ld		d,9	;
.loopC4
	dec		a
	cp		b
	jr		z,.CompRowSpr4
	dec		d
	jr		nz,.loopC4
	ret

.CompRowSpr4
	GetSpriteYAddr	Sprite0
	ld		c,a	;Store players ypos
	GetSpriteYAddr	Sprite4
	add		a,5
	ld		d,9
.loopR4
	dec		a
	cp		c
	call		z,gameover
	dec		d
	jr		nz,.loopR4
	ret
	
CompColSpr5:
;if positions of player and sprite5 are equal, call gameover:. 
;Almost a carbon copy of CompCol2 just instead checks sprite5 instead of sprite2
	GetSpriteXAddr	Sprite5
	add		a,5	;store sprite5 (a box) X pos in A
	ld		d,9	;
.loopC5
	dec		a
	cp		b
	jr		z,.CompRowSpr5
	dec		d
	jr		nz,.loopC5
	ret

.CompRowSpr5
	GetSpriteYAddr	Sprite0
	ld		c,a	;Store players ypos
	GetSpriteYAddr	Sprite5
	add		a,5
	ld		d,9
.loopR5
	dec		a
	cp		c
	call		z,gameover
	dec		d
	jr		nz,.loopR5
	ret
	

GotPoint:
;This makes sure that the apple and player positions never overlap by spawning apple in opposite top/bottom of screen
;Rand16 is a function from gbrandom.asm that gives a number between 0-255 into reg h and a different 0-255 into reg l (that's an L)
;Compare sprite0's Y axis to 0-144 but with 16 offset on top and bottom. so 112 moveable spots. Have to take in account that the score is on bottom taking up 8 spots
;Compare sprite0's X axis 0-160, 8 offset on left and right, so 144 moveable spots
;Cp sets C flag is A is less than value specified
	ld	a,1
	call	easyScoreRaise		;raise the score by one, we've run into the apple once
	GetSpriteYAddr	Sprite0
	cp	56		;on top half (0-55) or bottom half (56-112)?
	jr	c,.Ybottom 	;if player (sprite0) on top half, jump to put apple (sprite1) on bottom half
.Ytop ;regarding placement of apple on top half
	;GetSpriteXAddr	Sprite0
	;cp	72		;left (0-71) or right (72-144) side?
	;jr	c,.TopXright	
.TopXPos
	call	Rand16
	call .loadYcoord	;limits y coord to one quadrant
	PutSpriteYAddr	Sprite1,a	;apple on top half
	PutSpriteYAddr	Sprite4,a
	PutSpriteYAddr	Sprite5,a
;Was attempting to randomize block positions, instead they are static
	;push	af
	;push	hl
	;push	bc
	;call	.randSpr2Spr3
	;pop		bc
	;pop 		hl
	;pop		af
	sub	14				;subtract means high up on screen
	PutSpriteYAddr	Sprite2,a	;box just on top of apple
	add	28				;add means lower down on screen
	PutSpriteYAddr	Sprite3,a
	call	.loadAllX		;gives x coord a valid value from the Rand16 number
	PutSpriteXAddr	Sprite1,a
	PutSpriteXAddr	Sprite2,a
	PutSpriteXAddr	Sprite3,a
	add	18
	PutSpriteXAddr	Sprite4,a
	sub	34
	PutSpriteXAddr	Sprite5,a
	ret
	
.Ybottom ;placement of apple on bottom half
	;GetSpriteXAddr	Sprite0
	;cp	72
	;jr 	c,.BotXright
.BotXPos
	call	Rand16
	call .loadYcoord
	add	a,56		;add 56 to place sprite on bottom half, otherwise code is identical to .Ytop
	;sub	16		;keep sprites in viewable background
	PutSpriteYAddr	Sprite1,a	;apple on top half
	PutSpriteYAddr	Sprite4,a
	PutSpriteYAddr	Sprite5,a
	;push	af
	;push	hl
	;push	bc
	;call	.randSpr2Spr3
	;pop		bc
	;pop 		hl
	;pop		af
	sub	14
	PutSpriteYAddr	Sprite2,a	;box just on top of apple
	add	28
	PutSpriteYAddr	Sprite3,a
	call	.loadAllX
	PutSpriteXAddr	Sprite1,a
	PutSpriteXAddr	Sprite2,a
	PutSpriteXAddr	Sprite3,a
	add	18
	PutSpriteXAddr	Sprite4,a
	sub	34
	PutSpriteXAddr	Sprite5,a
	ret
	

;Rand16 number can only be limited by powers of 2 minus one
;Since the ypos can only be 0-55, we have to see if random # is greater than 55
;power of 2 closest to 55 is 64, minus one is 63. And 63-55 is 8 away.
;So if we are above 55, we subtract 8 such that we are below ypos limit no matter the rand#
.loadYcoord
	ld	a,h	;rand# between 0 and 255
	and	%00111111	;set value 0-63
	cp	56	;if greater than 55 (C flag will NOT be set), sub an amount from rand#
	call	nc,.subY	;subtracts a number to get below limit of 56
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;old code, instead I used .loadAllX to generate a valid rand16 number for the xposition
;Unused
;xpos can only be 0-71, check if rand# is greater than 71
;power of 2 closest to 71 yet still bigger is 128 minues one, is 127.
;127-71=56, which we will subtract to keep rand# in xpos limits
.loadXcoord
	ld	a,l	;rand# 0-255 but diferent value than reg h
	and	%01111111	;set value 0-127
	cp	72	;if greater than 71 (C flag will not be set), sub an amount from rand#
	call	nc,.subX	;subtracts a number to get below limit of 72
	ret
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.subY
	sub	8
	ret
.subX
	sub 	56
	ret
	
.loadAllX
	ld	a,l
	and	%11111111	;255
	cp	144
	call	nc,.subAllX
	ret
.subAllX
	sub	111	;255-144=111
	ret
	
;Not working, so left unimplemented	
.randSpr2Spr3
;randomizes the positions of the top and bottom block, only Y positions
;guarantees that player can fit between them
	ld		b,a
	call		Rand16
	ld		a,h	;I need the number between 4 and 8
	and		%00000111	;largest number
	cp		4
	jr		c,.addFour;if less than 4, add an amount
	add		8			;at its max, it will be 15, so adding one gets us to 16 (I want max spacing to align with sprite sizes Eg. 8, 16, 32)
	add		b			;add that value to apple's relative position. Put box below apple
	PutSpriteYAddr	Sprite2,a
	ld		a,l
	and		%00000111
	cp		4
	jr		c,.addFour
	;add		4
	sub		b			;sub that value to apple's relative position. Put box above apple
	PutSpriteYAddr	Sprite3,a
	ret
.randSpr4

	ret
.addFour
	add		4
	ret
	
;FOR USE IN DISPLAYING INSTRUCTION, GAMEOVER, AND HIGHSCORE PAGES
;Writes a bunch of blank spaces to clear the screen
ClearScreen:
	ld	hl,Clear			;Source, area of memory with title string, defined below MainLoop:
	ld	de, _SCRN0+(SCRN_VY_B*1) ;Destination,  Tile Map 1 ($9800) plus the virtual height of the screen in bytes times 5 
	ld	bc, ClearEnd-Clear	;length of bytes from Title to TitleEnd, defined below MainLoop
	call	mem_CopyVRAM	;defined in memory.asm
	ret
	
;displays loading page (We load to wait for lifting of physical pressing of keys, not for any hardware reasons)
PgLoading:
	call	ClearScreen
	ld	hl,Loading
	ld	de,_SCRN0+(SCRN_VY_B*5)
	ld	bc,LoadingEnd-Loading
	call	mem_CopyVRAM
;can call loading without redrawing screen by calling LdLoop:
LdLoop:
	ld	a,$6	;numbers of waits
.LoadingLoop
	;Fake a loading time to clear key presses
	push	af	;TimeDelay does not like using pop instruction inside it
	call	TimeDelay
	pop		af
	dec	a
	jr	nz,.LoadingLoop
	ret
	
; ****************************************************************************************
; END of my code
; ****************************************************************************************

; TimerInterrupt is the routine called when a timer interrupt occurs.
; TimeDelay allows us to wait a specified amount of time 
; modified from hello-sprite-good-delay
; Based on http://cratel.wichita.edu/cratel/ECE238Spr08/tutorials/Timer 
TimerInterrupt:	
	push	af			; save a and flags
	ld	a,TimerClockDiv	; load number of counts of timer
	ld	[rTMA],a		
	ld	a,TimerHertz		; load timer speed
	ld	[rTAC],a
	ld	a,IEF_TIMER		; load value representing that the timer interrupt occured.
	ld	[IFlags],a			; save value in a variable can keeps track of flags
	pop		af			; restore a and flags.
	reti
;Timer interrupt is set to go off about 40 times a second	
TimeDelay:
	halt					;halt until an interrupt
	nop					;halt is always followed by a no operation
	ld	a,[IFlags]			;load what interrupt occured
	cp	IEF_TIMER			;compare interrupts, is it the timer interrupt?
	jr	nz,TimeDelay		;if not timer IRQ, loop
	xor	a				;else a XORed with itself is always 0
	ld	[IFlags],a			;reset timer flag
	ret

; For use in displaying and initializing sprites
initdma:
	ld	de, DMACODELOC
	ld	hl, dmacode
	ld	bc, dmaend-dmacode
	call	mem_CopyVRAM			; copy when VRAM is available
	ret
dmacode:
	push	af
	ld	a, OAMDATALOCBANK		; bank where OAM DATA is stored
	ldh	[rDMA], a			; Start DMA
	ld	a, $28				; 160ns
dma_wait:
	dec	a
	jr	nz, dma_wait
	pop	af
	reti
dmaend:
; *hs* END

; ****************************************************************************************
; StopLCD:
; turn off LCD if it is on
; and wait until the LCD is off
; ****************************************************************************************
StopLCD:
        ld      a,[rLCDC]	; $FF40, LCD control
        rlca                   	;rotate left, MSB 7 of A copied to Carry and LSB 0 of A
	;since bit 7 is 1 (LCD on) or 0 (LCD off) we can use this to determine if screen is already off
	ret     nc              	;return if no Carry, i.e. LCD Screen is off already.

; Loop until we are in VBlank
;wait until display scan line turns on Vblank (bit 4 of rSTAT, $FF41, Mode 01)
.wait:
        ld      a,[rLY]		; $FF44 LCD y coordinate
        cp      145             	; Is display on scan line 145 yet? Set Z flag when equal
        jr      nz,.wait   		; if not, keep waiting. jump to .wait when Z is not set

; Turn off the LCD
        ld      a,[rLCDC]	; $FF40 , LCD control 
        res     7,a            	; reset bit 7 of LCDC to zero. LCD on/off
        ld      [rLCDC],a
        ret
