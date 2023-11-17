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


cons_write_ascii:
    pushw %cx
    movw $16, %cx
    movb    $0x0e, %ah           # 0x0e is the INT 10h BIOS call to output the value contained in AL to screen


cons_write_ascii_rpt:    
    movb    (%si), %al          # Load the byte at the location contained in the SI register into AL   
    inc     %si                 # Add 1 to the value in SI
    
    cmp $32, %al
    jb replace_system_char
    jmp cons_write_output


replace_system_char:
    movb $95, %al # replace with _


cons_write_output:
    int     $0x10               # Output the character in AL to the screen
    loop     cons_write_ascii_rpt      # and continue


cons_write_ascii_done:                # Something that is called will never return 
    popw %cx
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

wrong: .string "this is wrong"
woop:
    movw $wrong, %si
    call cons_writeline
    jmp finish


# returns keyboard input value (ascii) to %AL
# http://www.ctyme.com/intr/rb-1754.htm
get_keyboard_input:
    movb $0x00, %ah     # int 16 bios call for get keystroke
    int $0x16           # run get keystroke interrupt
    ret

real_start:
    movb    %dl, (boot_device) # Boot device number is passed in DL from BIOS. Save it here since DL might get trashed

    movw    $boot_message, %si  # Display our boot message
    call    cons_writeline

    movw    $booted_from_msg, %si
    call    cons_write

    movb    (boot_device), %dl
    cmp     $0x80, %dl

    movw    $fd, %si

    call read_disk_start

    jmp     finish

read_disk_start:
    call cons_write_crlf
    movw $enter_sector_number_message, %si
    call cons_write

    call get_keyboard_input # returns number 1-9 into %AX

    # output character to screen
    movb    $0x0e, %ah
    int $0x10
 
    pushw %ax # save the contents of %al (the inputted character)
    call cons_write_crlf

    # output contents of sector message
    movw $contents_of_sector_message, %si
    call cons_write

    popw %ax # restore values of ax

    # convert ascii character to an integer value
    sub $48, %al    

    pushw %ax
    # output the inputted character to screen
    movb    $0x0e, %ah
    int $0x10
    call cons_write_crlf
    popw %ax

    call read_disk
    ret

read_disk:
    movw    $disk_address_packet, %si # Move address of the disk address packet into SI
    movw    $7, 2(%si)                # Set the number of blocks to read to be 7
    movw    $0xD000, 4(%si)           # Set the adddress to read into to be 0xD000
    movb    %al, 8(%si)                # Set the first block to read to be block the keyboard input
    movb    $0x42, %ah                # 0x42 is the int 13h BIOS function to read the disk using LBA addressing
	movb	(boot_device), %dl        # Retrieve the ID of our boot device and put in DL	
    int     $0x13                     # Read the disk
    jc      read_failed	              # The carry flag will be set if an error occured

    movb    (0xD000), %al             # Check that what we loaded is not empty
    cmpb    $0, %al
    je      read_failed

    movw $0xD000, %si
    dec %si
    movw $0, %cx
    movw $0, %dx
    
    # print first offset (0000)
    movw %dx, %bx 
    call cons_write_hex2

    call read_disk_loop

    ret

space:
    .string " "

read_disk_loop:
    # cl represents the amount of lines that have been output onto the screen
    cmp $16, %cl
    jz finish
    
    movw (%si), %bx 
    inc %si
    call cons_write_hex
    
    inc %dx

    # output spaces between hex values
    pushw %si
    movw $space, %si
    call cons_write
    popw %si

    # display new line
    inc %ch
    cmp $16, %ch
    jz print_new_line

    call read_disk_loop
    jmp finish

print_new_line:
    movw %si, %bx 
    sub $16, %si
    call cons_write_ascii
    add $16, %si
    movw %bx, %si

    call cons_write_crlf
    
    cmp $15, %cl
    jz last_line_of_sector
    
    movw %dx, %bx 
    call cons_write_hex2

    inc %cl
    movb $0, %ch
    jmp read_disk_loop

last_line_of_sector:
    movw $continue_read, %si
    call cons_write

    call get_keyboard_input

    jmp read_disk_start

continue_read:
    .string "Press a key to continue..."

HexChars:	
    .ascii "0123456789ABCDEF"

cons_write_hex2:
    pushw %si
    pushw %cx

	movw	$4, %cx
    
    movb    $0x0E, %ah
	
hexloop2:
    rol     $4, %bx
    movw    %bx, %si
    and     $0x000F, %si
    movb    HexChars(%si), %al
	int		$0x10
	loop	hexloop2
    movw $space, %si
    call cons_write
    popw %cx
    popw %si
    ret

cons_write_hex:
    pushw %si
    pushw %cx
	movw	$2, %cx
    movb    $0x0E, %ah
	
hexloop:
    rol     $4, %bx
    movw    %bx, %si
    and     $0x000F, %si
    movb    HexChars(%si), %al
	int		$0x10
	loop	hexloop
    popw %cx
    popw %si
    ret

read_failed:	                      # Display error messages
	movw 	$read_failed_msg, %si
    call    cons_writeline
	
	mov 	$cannot_continue, %si	
    call    cons_writeline

finish:
    call finish


boot_device:
    .byte   0

boot_message:     
    .string "Boot Loader Stage 2 loaded"             
booted_from_msg:
    .string "Booting from "
fd: .string "floppy disk"
hd: .string "hard drive"

enter_sector_number_message: 
    .string "enter the sector number to read: "

contents_of_sector_message: 
    .string "Contents of sector "  


# Format of disk address packet
#
# Offset	Size	Description
#  0          1     size of packet (16 bytes)
#  1          1     always 0
#  2          2     number of sectors to transfer (max 127 on some BIOSes)
#  4          4     transfer buffer (first 2 bytes is 16-bit offset, next 2 bytes is 16 bit segment)
#  8          4     lower 32-bits of 48-bit starting LBA (starting from 0)
#  12         4     upper 16-bits of 48-bit starting LBA (will always be 0 for us)

disk_address_packet:
    .byte   0x10
    .byte   0
    .word   0
    .long   0
    .long   0
    .long   0

read_failed_msg:
    .string "Unable to read stage 2 of the boot process"
cannot_continue:
    .string "Cannot continue boot process"