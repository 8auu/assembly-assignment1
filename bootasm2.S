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
    call cons_write_crlf

    # output contents of sector message
    movw $contents_of_sector_message, %si
    call cons_write
    
    # move cursor to new line
    call cons_write_crlf
    ret

real_start:
    xorw    %ax, %ax                 # Set %ax to zero
    movw    %ax, %ds                 # -> Data Segment
    movw    %ax, %es                 # -> Extra Segment
    movw    %ax, %ss                 # -> Stack Segment
    movw    $0, %sp                  # Set the stack to the top of the segment
    movb    %dl, (boot_device) # Boot device number is passed in DL from BIOS. Save it here since DL might get trashed

    movw $enter_sector_number_message, %si
    
    # call cons_write
    
    # call get_keyboard_input

    # call read_disk
    
    jmp     finish

read_disk:
    movw    $disk_address_packet, %si # Move address of the disk address packet into SI
    movw    $7, 2(%si)                # Set the number of blocks to read to be 7
    movw    $0xD000, 4(%si)           # Set the adddress to read into to be 0x9000
    movw    $1, 8(%si)                # Set the first block to read to be block 1
    movb    $0x42, %ah                # 0x42 is the int 13h BIOS function to read the disk using LBA addressing
	movb	(boot_device), %dl        # Retrieve the ID of our boot device and put in DL	
    int     $0x13                     # Read the disk
    jc      read_failed	              # The carry flag will be set if an error occured

    movb    (0xD000), %al             # Check that what we loaded is not empty
    cmpb    $0, %al
    je      read_failed
    call read_sector
    movb $0, %bh
    ret

read_sector:
    movw $emptyness, %si
    call cons_write
    movb    (0xD000), %bl             # Load the byte to print into BL
    inc %bl
    inc %bh
    cmp $4, %bh
    jz finish
    call    cons_write_hex
    call read_sector
    ret

emptyness: .string "  "

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

harddrive:
    movw    $hd, %si

read_failed:	                      # Display error messages
	movw 	$read_failed_msg, %si
    call    cons_writeline
	
	mov 	$cannot_continue, %si	
    call    cons_writeline

finish:
    jmp finish

# Program data

boot_device:
    .byte   0

boot_message:     
    .string "Boot Loader Stage 2 loaded"             
booted_from_msg:
    .string "Booting from "
fd: .string "floppy disk"
hd: .string "hard drive"
enter_sector_number_message: .string "Enter the sector number to read: "
contents_of_sector_message: .string "Contents of sector"
read_failed_msg:
    .string "Unable to read disk"
cannot_continue:
    .string "Cannot continue boot process"


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