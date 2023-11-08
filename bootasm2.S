# When the PC starts, the processor is essentially emulating an 8086 processor, i.e. 
# a 16-bit processor.  So our initial boot loader code is 16-bit code that will 
# eventually switch the processor into 32-bit mode.

# This code is linked to assume a starting address of 0x7C00 which is where the BIOS
# will load a boot segment.

.code16                         # Assemble for 16-bit mode
.globl start
start:
    jmp     real_start

# Write to the console using BIOS.
# 
# Input: SI contains the address of the null-terminated string to be displayed

cons_write:
    movb    $0x0e, %ah           # 0x0e is the INT 10h BIOS call to output the value contained in AL to screen

cons_write_rpt:
    movb    (%si), %al          # Load the byte at the location contained in the SI register into AL   
    inc     %si                 # Add 1 to the value in SI
    cmp     $0, %al             # Compare the value in AL with 0
    jz      cons_write_done     # If it is zero, then we are done
    int     $0x10               # Output the character in AL to the screen
    jmp     cons_write_rpt      # and continue

cons_write_done:                # Something that is called will never return 
    ret                         # until a 'ret' instruction is encountered.  Labels do 
                                # not give a program any structure.  They just give a 
                                # memory location a name that we can use in our code. 

cons_write_crlf:
    movb    $0x0e, %ah          # Output CR
    movb    $0x0d, %al
    int     $0x10
    movb    $0x0a, %al          # Output LF
    int     $0x10
    ret

cons_writeline:
    call    cons_write
    call    cons_write_crlf
    ret    

get_keyboard_input:
    # http://www.ctyme.com/intr/rb-1754.htm
    movb $0x00, %ah     # int 16 bios call for get keystroke
    int $0x16           # run get keystroke interrupt
    
    # output character to screen
    movb    $0x0e, %ah
    int $0x10

    pushw %ax # save the contents of %al (the inputted character)
    call cons_write_crlf

    # output contents of sector message
    movw $contents_of_sector_message, %si
    call cons_write

    popw %ax # restore values of ax

    # output the inputted character to screen
    movb    $0x0e, %ah
    int $0x10
    call cons_writeline
    ret

real_start:
    xorw    %ax, %ax                 # Set %ax to zero
    movw    %ax, %ds                 # -> Data Segment
    movw    %ax, %es                 # -> Extra Segment
    movw    %ax, %ss                 # -> Stack Segment
    movw    $0, %sp                  # Set the stack to the top of the segment
    movb    %dl, (boot_device) # Boot device number is passed in DL from BIOS. Save it here since DL might get trashed

    movw $enter_sector_number_message, %si
    call cons_write
    call get_keyboard_input # returns value to %AL
    
    jmp     finish


HexChars:	.ascii "0123456789ABCDEF"

cons_write_hex:
	movw	$4, %cx
    movb    $0x0E, %ah
	
hexloop:
    rol     $4, %bx
    movw    %bx, %si
    and     $0x000F, %si
    movb    HexChars(%si), %al
	int		$0x10
	loop	hexloop
	ret

finish:
    jmp finish

boot_device:
    .byte   0

enter_sector_number_message: 
    .string "enter the sector number to read: "

contents_of_sector_message: 
    .string "Contents of sector "
