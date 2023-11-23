# When the PC starts, the processor is essentially emulating an 8086 processor, i.e. 
# a 16-bit processor.  So our initial boot loader code is 16-bit code that will 
# eventually switch the processor into 32-bit mode.

# This code is linked to assume a starting address of 0x7C00 which is where the BIOS
# will load a boot segment.

.code16                         # Assemble for 16-bit mode
.globl start
start:
    jmp     real_start



cons_write:
    pushw %ax
    movb    $0x0e, %ah           # 0x0e is the INT 10h BIOS call to output the value contained in AL to screen

cons_write_rpt:
    movb    (%si), %al          # Load the byte at the location contained in the SI register into AL   
    inc     %si                 # Add 1 to the value in SI
    cmp     $0, %al             # Compare the value in AL with 0
    jz      cons_write_done     # If it is zero, then we are done
    int     $0x10               # Output the character in AL to the screen
    jmp     cons_write_rpt      # and continue

cons_write_done:                # Something that is called will never return 
    popw %ax
    ret                         # until a 'ret' instruction is encountered.  Labels do 
                                # not give a program any structure.  They just give a 
                                # memory location a name that we can use in our code. 

cons_write_ascii:
    pushw %ax
    pushw %cx
    pushw %bx
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
    popw %bx
    popw %cx
    popw %ax
    ret                         # until a 'ret' instruction is encountered.  Labels do 
                                # not give a program any structure.  They just give a 
                                # memory location a name that we can use in our code. 

cons_write_crlf:
    pushw %ax
    movb    $0x0e, %ah          # Output CR
    movb    $0x0d, %al
    int     $0x10
    movb    $0x0a, %al          # Output LF
    int     $0x10
    popw %ax
    ret

cons_writeline:
    call    cons_write
    call    cons_write_crlf
    ret      


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
    call get_sector_number

    popw %ax # restore values of ax

    # output contents of sector message
    movw $contents_of_sector_message, %si
    call cons_write

    pushw %ax
    # output the inputted character to screen
    movb    $0x0e, %ah
    int $0x10
    call cons_write_crlf
    popw %ax

    call gather_information
    ret

enter_amount_of_sector_to_read_message:
    .string "Enter amount of sectors to read: "


get_sector_number:
    call cons_write_crlf
    movw $enter_sector_number_message, %si
    call cons_write

    # we will store the number in dxwbn
    xor %bx, %bx # reset dx
    
    pushw %cx
    movw $0, %cx
    call sector_number_loop
    popw %cx

sector_number_loop:
    call get_keyboard_input

    # output character to screen
    movb $0x0e, %ah
    int $0x10

    cmp $13, %al # Check if input is enter
    jz gather_information

    xor %ah, %ah
    # Convert ASCII to digit
    sub $48, %al

    imul $10, %bx
    add %ax, %bx

    inc %cx
    cmp $4, %cx
    jz gather_information

    call sector_number_loop

enter_search_query_message:
    .string "Please enter a search query: "

search_query:
    .string "    "

get_search_query:
    pushw %si
    pushw %ax
    pushw %cx

    movw $enter_search_query_message, %si
    call cons_write
    movw $search_query, %si

search_query_loop:
    xor %ax, %ax
    call get_keyboard_input
 
    # output character to screen
    movb $0x0e, %ah
    int $0x10

    cmp $13, %al # Check if input is enter
    jz exit_string_loop
 
    xor %ah, %ah
    movw %ax, (%si)
  
    inc %cx
    inc %si
    cmp $5, %cx
    jz exit_string_loop
    
    call search_query_loop

exit_string_loop:
    call cons_write_crlf
    popw %cx
    popw %ax
    popw %si

    jmp read_disk

gather_information:
    call cons_write_crlf
    movw $enter_amount_of_sector_to_read_message, %si
    call cons_write
    xor %ax, %ax
    call get_keyboard_input

    # output character to screen
    movb $0x0e, %ah
    int $0x10

    sub $48, %al
    xor %ah, %ah
    imul $2, %ax

    call cons_write_crlf

    call get_search_query

read_disk:
    # movw    $disk_address_packet, %si # Move address of the disk address packet into SI
    # movb    %al, 2(%si)                # Set the number of blocks to read to be 7
    # movw    $0xD000, 4(%si)           # Set the adddress to read into to be 0xD000
    # movw    %bx, 8(%si)                # Set the first block to read to be block the keyboard input
    # movb    $0x42, %ah                # 0x42 is the int 13h BIOS function to read the disk using LBA addressing
	# movb	(boot_device), %dl        # Retrieve the ID of our boot device and put in DL	
    # int     $0x13                     # Read the disk
    # jc      read_failed	              # The carry flag will be set if an error occured
# 
    # # prepare registers for disk loop
    # movw $0xD000, %si
    # movw $0, %cx
    # movw $0, %dx
    # 
    # # print first offset (0000)
    # movw %dx, %bx
    # call cons_write_hex2
# 
    # call read_disk_loop


    movw $test_string, %si
    call find_string

    jmp finish

    ret

read_disk_loop:   
    movw (%si), %bx 
    call cons_write_hex

    # output spaces between hex values
    pushw %si
    movw $space, %si
    call cons_write
    popw %si
    
    inc %si

    # display new line
    inc %ch
    cmp $16, %ch
    jz finish_line

    call read_disk_loop

found_message: 
    .string "<-- FOUND"

test_string:
    .string "three boot fours"

found_chars:
    .string ""

find_string:
    xor %bx, %bx
    xor %cx, %cx
    xor %dx, %dx
    movb $0, %ch # represents index into line
    movb $0, %cl # represents index into search query
    movw $search_query, %bx


find_string_loop:
    movb    (%si), %al # disk bytes
    movb    (%bx), %dl # search query
    inc %si
    inc %bx

    # \if end of line return
    cmp $16, %ch
    jz exit_search

    inc %ch # represents index into line

    # \if cl is 4 (length of search query) then the string matches
    cmp $4, %cl
    jz CHOO

    # \if dl and sl match, then one of the characters match, increment CL to move to the next character in each string
    cmp %dl, %al
    jz skip_query_index_reset

    # \if dl and sl don't match reset the index into search query string (start from beginning)
    xor %cl, %cl

    jmp find_string_loop

skip_query_index_reset:
    # only increment if dl and al are same value
    inc %cl # represents index into search query
    inc %bx
    jmp find_string_loop


found_str:
    .string "Found!"

CHOO:
    jmp endless_loop


exiting_message:
    .string " exited"
    
exit_search:
    movw $exiting_message, %si
    call cons_write 
    ret

reset_cl:
    xor %cl, %cl
    jmp find_string_loop

output_found_message:
    movw $found_message, %si
    call cons_write
    ret

finish_line:
    inc %cl
    movb $0, %ch
    movw %si, %bx

    # remove 16 off of SI so we can start at the beginning of the line
    sub $16, %si
    call cons_write_ascii


    pushw %dx
    pushw %bx
    pushw %cx
    pushw %ax
    
    sub $16, %si
    call find_string

    popw %ax
    popw %cx
    popw %bx
    popw %dx

    movw %bx, %si
    call cons_write_crlf

    # first half of sector
    cmp $16, %cl
    jz last_line_of_block

    movw %dx, %bx 
    call cons_write_hex2

    jmp read_disk_loop

last_line_of_block:
    inc %dh
    cmp %dh, %al
    jz last_line_of_sector

    pushw %si
    movw $continue_read, %si
    call cons_writeline
    popw %si

    # reserve current values of ax
    pushw %ax
    call get_keyboard_input
    popw %ax    
    
    call cons_write_crlf

    movw %dx, %bx 
    call cons_write_hex2

    xor %cl, %cl

    jmp read_disk_loop

sector_finished: .string "Finished reading requested sectors"

last_line_of_sector:
    movw $sector_finished, %si
    call cons_writeline
    jmp read_disk_start

continue_read:
    .string "Press a key to continue..."

HexChars:	
    .ascii "0123456789ABCDEF"

cons_write_hex2:
    pushw %si
    pushw %cx
    pushw %ax
    pushw %dx

	movw	$4, %cx
    
    movb    $0x0E, %ah
	
hexloop2:
    rol     $4, %bx
    movw    %bx, %si
    and     $0x000F, %si
    movb    HexChars(%si), %al
	int		$0x10
	loop hexloop2
    movw $space, %si
    call cons_write
    popw %dx
    popw %ax
    popw %cx
    popw %si
    ret

cons_write_hex:
    pushw %si
    pushw %cx
    pushw %ax
    pushw %dx
	movw	$2, %cx
    movb    $0x0E, %ah
    rol     $8, %bx
	
hexloop:
    rol     $4, %bx
    movw    %bx, %si
    and     $0x000F, %si
    movb    HexChars(%si), %al
	int		$0x10
	loop	hexloop
    popw %dx
    popw %ax
    popw %cx
    popw %si
    ret

read_failed:	                      # Display error messages
	movw 	$read_failed_msg, %si
    call    cons_writeline
	
	mov 	$cannot_continue, %si	
    call    cons_writeline

code_finished:
    .string "The code is finished"

finish:
    call cons_write_crlf
    movw $code_finished, %si
    call cons_writeline

endless_loop:
    call endless_loop


boot_device:
    .byte   0

boot_message:     
    .string "Boot Loader Stage 2 loaded"             
booted_from_msg:
    .string "Booting from "
fd: .string "floppy disk"
hd: .string "hard drive"

enter_sector_number_message: 
    .string "Enter the sector number to read: "

contents_of_sector_message: 
    .string "Contents of sector "  
space:
    .string " "


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