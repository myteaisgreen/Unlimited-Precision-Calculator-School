section .rodata
    format_string: db "%s", 0
    CALC:   db "calc:", 32 , 0         ; format string
    debugPrefix: db "debug:", 32, 0
    format_char: db "%c", 0
    formatError_opStackOverflow: db "Error: Operand Stack Overflow", 10, 0 ;  if the calculation attempts to push operands onto the operand stack and there is no free space on the operand stack.    ; if the byte is not one of them than it is a regular number input to insert into the stack
    formatError_insufficientNumOfArgs: db "Error: Insufficient Number of Arguments on Stack", 10, 0 
    formatError_yIsAbove200: db "wrong Y value", 10, 0
    format_hex: db "%0X", 10, 0         ;  hexdecimal format string 

section .bss
    buffer:         resb 82             ; store my input
    buffer_length equ $ - buffer
    headList:           resb 4             ; the list
    tempLink:             resb 4            ; temp head for add the new link
    lastLink:              resb 4            ; pointer to the last link of the list
    STACK_SIZE: equ 5
    operandStack:          resb 4 * STACK_SIZE             ; hold the input
    

section .data
    numberOfOperations: dd 0 
    stack_counter: dd 0                 ; count the number of parameters in the stack
    onesCounter: dd 0
    input_size: dd 0
    debugMode: dd 0                         ; debug mode
    operandX: dd 0
    operandY: dd 0
    operandXPower: dd 0 ; operand X for negative power/power Mode
    operandYPower: dd 0 ; operand Y for negative power/power Mode
    tempLinkPower: dd 0 ; used in negativePower operation
    carry: db 0
    powerMode: dd 0 ; powerMode = 1 - ON - We are currently computing X* 2^Y
    avoidZeros: dd 1
    basePointerToPush: dd 1   ; for epb & esp
    ourBasePointer: dd 1
    listToDelete: dd 0      ; address for the temp list to delete
    anotherListToDelete: dd 0
    nextLinkToDelete: dd 0
    bufferToRelease: dd 0
    
    
%macro convertDecToHexPutInAl 1
    xor eax, eax
    cmp %1, 10
    jb %%digit
    
    mov al, %1
    add al, 55
    jmp %%end
    
  %%digit:
    mov al, %1
    add al, 48
%%end:
%endmacro

%macro updateCarry 0 
    jc %%c
    jnc %%noC
    %%c:
    mov byte [carry], 1
    jmp %%end
    %%noC:
    mov byte [carry], 0
    %%end:
%endmacro

%macro checkIfDebugMode 0 
    cmp dword [ebp + 8], 1 
    ja %%debug
    je %%notDebug
    %%debug:
    mov dword [debugMode], 1
    jmp %%end
    %%notDebug:
    mov dword [debugMode], 0
    %%end:
%endmacro

section .text
  align 16
     global main 
     extern printf
     extern fprintf
     extern fflush
     extern malloc 
     extern calloc 
     extern free 
     extern fgets 
     extern stdin
     extern stdout
     extern stderr
     extern exit

main:
    push ebp
    mov ebp, esp
    pushad
    
    checkIfDebugMode

    call myCalc
mainAftermyCalc:
    push eax
    push format_hex
    call printf
    add esp, 8
    
    popad
    mov esp, ebp
    pop ebp
    ret


myCalc:
    mov dword [basePointerToPush], ebp
    push ebp
    mov ebp, esp
    mov dword [ourBasePointer], ebp
    pushad
inputLoop:
    push CALC
    push format_string              ; print the "calc"
    call printf
    add esp, 8
    
    
    push dword [stdin]  
    push buffer_length  
    push dword buffer   
    call fgets         
    add esp, 12    

    
    mov esi, buffer     ; pointr to the input

    cmp byte [buffer], 'p'
    je popAndPrint

    cmp byte [buffer], '+'
    je plus

    cmp byte [buffer], 'd'
    je duplicate

    cmp byte [buffer], '^'
    je power

    cmp byte [buffer], 'n'
    je numberOfOnes

    cmp byte [buffer], 'v'
    je negativePower
    
    cmp byte [buffer], 'q'
    je quit_case

    cmp byte [buffer], 0xA
    je inputLoop

    xor ecx, ecx
    
checkInput: ; Run over the input string, convert each char to its decimal value
    cmp byte [esi], 0xA ; =?= \n 
    je endCheckInput
    
    cmp byte [esi], 'F'
    ja illegal_input
    
    cmp byte [esi], 'A'
    jge convertLetters
    
    cmp byte [esi], '9'
    ja illegal_input
    
    cmp byte [esi], '0'
    jge convertDigits
    jmp illegal_input
    
convertLetters:
    sub byte [esi], 55
    inc esi
    inc cl ; counter for the size input
    jmp checkInput
convertDigits:
    sub byte [esi], 48
    inc esi
    inc cl  ; counter for the size input
    jmp checkInput
endCheckInput:
    mov dword [input_size], ecx
    dec esi ; Now we point to the last digit in the input string (hopefuly)
    
inputStringToLinkedList: ; from end to beggining 
    cmp dword [input_size], 0
    je endInputStringToLinkedList
    
makeLink:
    push 1
    push 5
    call calloc
    add esp, 4
    
    mov edx, eax ; EDX -> Holds the address of the array of size 5
    
    
    cmp dword [input_size], 1 ; Is there only one digit to deal with?
    je makeLink.singleDigit
    
    cmp dword [input_size], 2 ; Are there two digits to make a link of?
    jge makeLink.doubleDigit
 
.singleDigit:
    dec dword [input_size]
    
    mov al, byte [esi]
    mov byte [edx], al ; byte [edx] = the first byte of the link, the DATA of the link
    
    jmp endMakeLink
.doubleDigit:
    dec dword [input_size]
    dec dword [input_size]
    
    mov al, byte [esi - 1]
    shl al, 4
    or al, byte [esi]
    mov byte [edx], al ; byte [edx] = the first byte of the link, the DATA of the link
    dec esi
    
    jmp endMakeLink
endMakeLink:
    ; Either way, the new link NEXT field should hold a pointer to NULL
    mov dword [edx + 1], 0
    dec esi
    
    cmp dword [headList], 0  ; 0 = null, DO WE HAVE A LIST??
    je .newList
    ; ELSE - A LIST EXISTS
    
    xor eax, eax 
    mov eax, dword [lastLink]
    mov [eax + 1], edx ; LastLink.NEXT = the new link
    mov dword [lastLink], edx
    
    jmp inputStringToLinkedList
    
.newList:
    mov dword [headList], edx
    mov dword [lastLink], edx
    
    jmp inputStringToLinkedList

endInputStringToLinkedList:    
pushOpStack:
    cmp dword [stack_counter], STACK_SIZE ; stackOverFlow
    je printError_opStackOverflow
    
    xor edx, edx
    mov edx, dword [stack_counter]
    
    xor eax, eax
    mov eax, dword [headList]
    mov dword [operandStack + edx*4], eax ; update the head of the list
    
    mov dword [headList], 0
    mov dword [lastLink], 0
    
    inc dword [stack_counter]   ; increase the stack_counter
    call free_LinkedList
endPushOpStack:
    jmp inputLoop
; ------------------------------------------------------------ POP AND PRINT
popAndPrint:
    inc dword [numberOfOperations]
    cmp dword [stack_counter], 0    ; If there is nothing on the stack, go to the print error
    je printError_insufficientNumOfArgs
    
    dec dword [stack_counter]
    mov eax, dword [stack_counter]
    
    mov ebx, dword [operandStack + eax*4] ; the head of the LL to print
    mov dword [headList], ebx
    mov dword [listToDelete], ebx
    
    
    xor ecx, ecx ; Our counter for the PUSH operations
    
.linkedListToOutputStack:
    cmp dword [headList], 0             ; check if null
    je endLinkedListToOutputStack
    
    mov eax, dword [headList]
    mov eax, [eax]
    mov bl, al ; 4
    shl bl, 4
    shr bl, 4

    convertDecToHexPutInAl bl   ; check letters
    push eax
    inc ecx
    
    mov eax, dword [headList]
    mov eax, [eax]
    mov bl, al ; 3
    shr bl, 4
    
    
    convertDecToHexPutInAl bl
    push eax
    inc ecx
    
    ; The progression - Link = Link.Next
    xor eax, eax
    mov eax, dword [headList]
    mov eax, dword [eax + 1]
    mov dword [headList], eax 
    
    jmp popAndPrint.linkedListToOutputStack
    
 endLinkedListToOutputStack:    ; print the whole list
    cmp ecx, 0
    je printEnterAndFinishPopAndPrint
    
    pop eax

    cmp dword [avoidZeros], 1
    je avoidZerosLoop

continueAfterZerosPrefix:
    
    pushad
    push eax
    push format_char 
    call printf
    add esp, 8
    popad
    
    dec ecx
    jmp endLinkedListToOutputStack
    
printEnterAndFinishPopAndPrint:
    cmp dword [avoidZeros], 1 ; It means we only had zeros up until now, and we should print at least one
    je printOneZero
    mov dword [avoidZeros], 1
continueAfterOneZero:
    push 10
    push format_char
    call printf
    add esp, 8

    call free_LinkedList
    
    jmp inputLoop

avoidZerosLoop:
    cmp eax, '0'
    jne stopAvoidingZeros
    dec ecx
    pop eax

    cmp ecx, 0
    je printEnterAndFinishPopAndPrint
    jmp avoidZerosLoop

stopAvoidingZeros:
    mov dword [avoidZeros], 0
    jmp continueAfterZerosPrefix

printOneZero:
    push 0x30
    push format_char
    call printf
    add esp, 8

    jmp continueAfterOneZero
; END popAndPrint

; ------------------------------------------------------------ DUPLICATE
duplicate:
    inc dword [numberOfOperations]
.afterIncrementOfNumberOfOperations:
    ; Check the legality of the operation
    cmp dword [stack_counter], 0
    je printError_insufficientNumOfArgs
    
    cmp dword [stack_counter], STACK_SIZE ; stackOverFlow
    je printError_opStackOverflow

    dec dword [stack_counter]

    xor ebx, ebx 
    mov ebx, dword [stack_counter]
    mov ebx, dword [operandStack + 4*ebx] ; The temp head of the list to be copied

.duplicateLoop:
    cmp ebx, 0
    je endDuplicateLoop

    cmp dword [headList], 0
    je duplicate.initializeList

    push 1
    push 5
    call calloc
    add esp, 8
    
    mov ecx, dword [lastLink] ; previousLink -> [data | next = null] EAX = newLink = [data = null | next = null]
    mov [ecx + 1], eax ; previousLink -> [data | next = newLink] EAX = newLink = [data = null | next = null]
    mov dword [lastLink], eax ; new lastLink = newLink

.continueDuplicateLoop:
    mov ecx, dword [lastLink]
    mov edx, [ebx] ; EDX will temporarily hold the DATA of head of the list to be copied
    mov [ecx], dl
    
    mov ebx, [ebx + 1]
    jmp duplicate.duplicateLoop

.initializeList:
    
    push 1
    push 5
    call calloc
    add esp, 8

    mov dword [headList], eax
    mov dword [lastLink], eax
    jmp duplicate.continueDuplicateLoop

endDuplicateLoop:
    inc dword [stack_counter]

    mov ecx, dword [headList]
    mov ebx, dword [stack_counter]
    mov dword [operandStack + 4*ebx] , ecx ; The cell to put the head of the duplicate list

    inc dword [stack_counter]

    mov dword [headList], 0
    mov dword [lastLink], 0

    cmp dword [powerMode], 1
    je powerLoop.afterDuplicate

    cmp dword [debugMode], 1
    je debugPrint

    jmp inputLoop
; END ------------------------------ duplicate
; ------------------------------------------------------------ NUMBER OF ONES
numberOfOnes:
    inc dword [numberOfOperations]
    ; Check the legality of the operation
    cmp dword [stack_counter], 0
    je printError_insufficientNumOfArgs

    dec dword [stack_counter]

    xor ebx, ebx 
    mov ebx, dword [stack_counter]
    mov ebx, dword [operandStack + 4*ebx] ; The temp head of the list to count it's ones
    mov dword [listToDelete], ebx
    xor ecx, ecx ; ECX shall be our counter

numberOfOnesLoop:
    cmp ebx, 0
    je .numberOfOnesToLinkedList

    xor eax, eax
    mov al, [ebx]

    xor edx, edx
    mov edx, 8

    .countOnesInTempLinkData:
    cmp edx, 0
    je .endCountOnesInTempLinkData

    shr al, 1
    adc ecx, 0
    dec edx
    jmp .countOnesInTempLinkData

    .endCountOnesInTempLinkData:
    mov ebx, [ebx + 1]
    jmp numberOfOnesLoop

    .numberOfOnesToLinkedList: ; Currently ECX holds the number of ones
    ; NOTE: The number of ones can only be a single link or a linked list of length two, no more

    push ecx ; We save the counter's value
    push 1
    push 5
    call calloc
    pop ecx ; pop 5
    pop ecx ; Discard the 1 pushed onto the stack
    pop ecx ; We restore the counter's value
    
    cmp ecx, 255
    ja .twoLinks

    cmp ecx, 0
    jae .oneLink 

    mov dword [eax], 0
    jmp endNumberOfOnes

    .oneLink:
    mov [eax], cl
    mov dword [eax + 1], 0
    jmp endNumberOfOnes

    .twoLinks: ; EXAMPLE : ECX = 0x120, CL = 0x20, CH = 0x01
    mov [eax], cl ; Link #1 [data = CL = 0x20 | next = null] 
    mov ebx, eax ; EBX = Link #1

    push ebx ; We save the pointer to the first link
    push ecx ; We save the counter's value
    
    push 1
    push 5
    call calloc

    pop ecx ; pop 5
    pop ecx ; Discard the 1 pushed onto the stack
    pop ecx ; We restore the counter's value
    pop ebx ; We restore the pointer to the first link

    mov [ebx + 1], eax
    mov [eax], ch
    mov dword [eax + 1], 0

    mov eax, ebx

endNumberOfOnes:
    mov ecx, dword [stack_counter]
    mov dword [operandStack + ecx*4], eax
    inc dword [stack_counter]

    cmp dword [debugMode], 1
    je debugPrint

    call free_LinkedList

    jmp inputLoop
; END ----------------------------- numberOfOnes
; ------------------------------------------------------------ PLUS
plus:
    inc dword [numberOfOperations]
.afterIncrementOfNumberOfOperations:
    ; Check the legality of the operation
    cmp dword [stack_counter], 2
    jb printError_insufficientNumOfArgs

    push 1
    push 5
    call calloc
    add esp, 8

    mov dword [headList], eax
    mov dword [lastLink], eax ; lastLink now holds the pointer to the head of the linked list of the sum
    

    dec dword [stack_counter]
    mov eax, dword [stack_counter]
    mov eax, dword [operandStack + eax*4] ; contains the head of 78->56 "5678"
    mov dword [operandX], eax ; contains the head of 78->56 "5678"
    mov dword [listToDelete], eax

    dec dword [stack_counter]
    mov ebx, dword [stack_counter]
    mov ebx, dword [operandStack + ebx*4] ; contains the head of 34->12 "1234"
    mov dword [operandY], ebx ; contains the head of 34->12 "1234"
    mov dword [anotherListToDelete], ebx

firstAddition: 

    mov al, [eax]
    mov bl, [ebx]
    add al, bl
    updateCarry


    mov ecx, dword [lastLink]
    mov [ecx], al ; The first link in the linked list of the sum

    ; PROGRESSION
    mov eax, dword [operandX]
    mov eax, [eax + 1]
    mov dword [operandX], eax

    mov ebx, dword [operandY]
    mov ebx, [ebx + 1]
    mov dword [operandY], ebx

plusLoop:
    cmp dword [operandX], 0
    je opXIsDone ; 

    cmp dword [operandY], 0
    je continueWithOneOperandAlive


continueWithTwoOperandsAlive: ; BOTH OPERANDS ARE ALIVE
    push 1
    push 5
    call calloc
    add esp, 8

    mov ecx, dword [lastLink]
    mov [ecx + 1], eax
    mov dword [lastLink], eax

    mov eax, dword [operandX]
    mov ebx, dword [operandY]

    mov al, [eax]
    mov bl, [ebx]

    add al, byte [carry]
    updateCarry
    add al, bl
    jc doUpdate

cont:
    mov ecx, dword [lastLink]
    mov [ecx], al

    ; PROGRESSION
    mov eax, dword [operandX]
    mov eax, [eax + 1]
    mov dword [operandX], eax

    mov ebx, dword [operandY]
    mov ebx, [ebx + 1]
    mov dword [operandY], ebx

    jmp plusLoop
continueWithOneOperandAlive: ; At this point - X is finished -> X=Y
    push 1
    push 5
    call calloc
    add esp, 8

    mov ecx, dword [lastLink]
    mov [ecx + 1], eax
    mov dword [lastLink], eax

    mov eax, dword [operandX]

    mov al, [eax]

    add al, byte [carry]
    updateCarry
    
    mov ecx, dword [lastLink]
    mov byte [ecx], al

    ; PROGRESSION
    mov eax, dword [operandX]
    mov eax, [eax + 1]
    mov dword [operandX], eax

    jmp plusLoop

endPlus:
    xor eax, eax
    mov al, byte [carry] ; TODO REMOVE
    cmp byte [carry], 1
    je makeLastLinkOutOfCarry
    ; TODO : maybe both numbers are done but there is still some carry to consider?
.finishEndPlus:
    mov eax, dword [stack_counter]
    
    mov ebx, dword [headList]
    mov dword [operandStack + 4*eax], ebx

    inc dword [stack_counter]

    mov dword [operandX], 0
    mov dword [operandY], 0
    mov dword [headList], 0
    mov dword [lastLink], 0

    cmp dword [powerMode], 1
    je powerLoop.afterPlus

    cmp dword [debugMode], 1
    je debugPrint

    call free_LinkedList

    mov eax, dword [anotherListToDelete]
    mov dword [listToDelete], eax
    call free_LinkedList

    jmp inputLoop

opXIsDone:
    cmp dword [operandY], 0
    je endPlus

    mov eax, dword [operandY]
    mov dword [operandX], eax

    mov dword [operandY], 0
    jmp continueWithOneOperandAlive

doUpdate: 
    updateCarry
    jmp cont

makeLastLinkOutOfCarry:
    push 1
    push 5
    call calloc
    add esp, 8

    mov ebx, dword [lastLink]
    mov byte [eax], 1
    mov [ebx + 1], eax
     
    jmp endPlus.finishEndPlus    
; END ---------------------------- plus
; ------------------------------------------------------------ POWER
power:
    inc dword [numberOfOperations]
    ; Check the legality of the operation
    cmp dword [stack_counter], 2
    jb printError_insufficientNumOfArgs
    
    cmp dword [stack_counter], STACK_SIZE ; stackOverFlow
    je printError_opStackOverflow

    dec dword [stack_counter] ; NOW WE POINT TO THE TOP OF THE STACK, i.e. X
    mov eax, dword [stack_counter]
    mov eax, dword [operandStack + 4*eax]
    mov dword [operandXPower], eax

    dec dword [stack_counter] ; Now we point to Y
    mov eax, dword [stack_counter]
    mov eax, dword [operandStack + 4*eax]
    mov dword [operandYPower], eax
    mov dword [listToDelete], eax
    
.checkIfYIsAbove200:
    cmp byte [eax], 200
    ja printError_yIsAbove200

    mov eax, [eax + 1]
    cmp eax, 0
    jne printError_yIsAbove200

    mov ebx, dword [operandYPower]
    mov ecx, [ebx] ; ECX now holds the Y operand
    xor ebx, ebx
    mov bl, cl
    mov dword [operandYPower], ebx

    mov ebx, dword [operandXPower]
    mov eax, dword [stack_counter]
    mov dword [operandStack + 4*eax], ebx ; = dword [operandXPower]

    inc dword [stack_counter]

    mov dword [powerMode], 1 ; POWER MODE - ON
powerLoop:
    cmp dword [operandYPower], 0
    je endPower

    jmp duplicate.afterIncrementOfNumberOfOperations
.afterDuplicate:
    jmp plus.afterIncrementOfNumberOfOperations
.afterPlus:
    dec dword [operandYPower]
    jmp powerLoop
endPower:
    mov dword [powerMode], 0
    mov dword [operandXPower], 0
    mov dword [operandYPower], 0

    cmp dword [debugMode], 1
    je debugPrint

    call free_LinkedList

    jmp inputLoop
;END ---------------------------- power
; ------------------------------------------------------------ NEGATIVE POWER
negativePower:
    inc dword [numberOfOperations]
    ; Check the legality of the operation
    cmp dword [stack_counter], 2
    jb printError_insufficientNumOfArgs
    
    cmp dword [stack_counter], STACK_SIZE ; stackOverFlow
    je printError_opStackOverflow

    dec dword [stack_counter] ; NOW WE POINT TO THE TOP OF THE STACK, i.e. X
    mov eax, dword [stack_counter]
    mov eax, dword [operandStack + 4*eax]
    mov dword [operandXPower], eax

    dec dword [stack_counter] ; Now we point to Y
    mov eax, dword [stack_counter]
    mov eax, dword [operandStack + 4*eax]
    mov dword [operandYPower], eax
    mov dword [listToDelete], eax
    
.checkIfYIsAbove200:
    cmp byte [eax], 200
    ja printError_yIsAbove200

    mov eax, [eax + 1]
    cmp eax, 0
    jne printError_yIsAbove200

    mov ebx, dword [operandYPower]
    mov ecx, [ebx] ; ECX now holds the Y operand
    xor ebx, ebx
    mov bl, cl
    mov dword [operandYPower], ebx

    mov ebx, dword [operandXPower]
    mov eax, dword [stack_counter]
    mov dword [operandStack + 4*eax], ebx ; = dword [operandXPower]

negativePowerLoop: ; Main loop - it's where we do Y times - SHR(X)
    cmp dword [operandYPower], 0
    je endNegativePower

    mov eax, dword [operandXPower]
    mov dword [headList], eax

.shrOfALinkedListLoop:
    mov eax, dword [headList]
    mov eax, [eax]
    mov bl, al
    shr bl, 1 ; All that is left is to add the carry from the SHR on the data of the following link

    mov eax, dword [headList]
    mov edx, [eax + 1]
    mov dword [tempLinkPower], edx
    cmp dword [tempLinkPower], 0 
    je .endShrOfALinkedListLoop ; IF the following link is null, it means we are about to finish the shr operation on the current X
    
    mov ecx, dword [tempLinkPower]
    mov ecx, [ecx]
    shr cl, 1
    updateCarry

    mov dl, byte [carry]
    shl dl, 7

    or bl, dl ; BL now holds the SHR(currentLink.data) + SHL*7(carry((currentLink.next).data))

    mov eax, dword [headList]
    mov [eax], bl

    mov edx, [eax + 1]
    mov dword [headList], edx
    jmp .shrOfALinkedListLoop

.endShrOfALinkedListLoop:   
    mov eax, dword [headList]
    mov [eax], bl

    dec dword [operandYPower]
    jmp negativePowerLoop
    
endNegativePower:
    inc dword [stack_counter]

    mov dword [headList], 0

    cmp dword [debugMode], 1
    je debugPrint

    call free_LinkedList

    jmp inputLoop
; END ----------------------- negativePower
; ------------------------------------------------------------ DEBUG PRINT
debugPrint: ; Almost the same like popAndPrint
    push debugPrefix
    push format_string              ; print the "calc"
    call printf
    add esp, 8
        
    dec dword [stack_counter]
    mov eax, dword [stack_counter]
    
    mov ebx, dword [operandStack + eax*4] ; the head of the LL to print
    mov dword [headList], ebx
    
    xor ecx, ecx ; Our counter for the PUSH operations
    
.linkedListToOutputStack:
    cmp dword [headList], 0             ; check if null
    je endLinkedListToOutputStackDebugPrint
    
    mov eax, dword [headList]
    mov eax, [eax]
    mov bl, al ; 4
    shl bl, 4
    shr bl, 4

    convertDecToHexPutInAl bl   ; check letters
    push eax
    inc ecx
    
    mov eax, dword [headList]
    mov eax, [eax]
    mov bl, al ; 3
    shr bl, 4
    
    
    convertDecToHexPutInAl bl
    push eax
    inc ecx
    
    ; The progression - Link = Link.Next
    xor eax, eax
    mov eax, dword [headList]
    mov eax, dword [eax + 1]
    mov dword [headList], eax 
    
    jmp debugPrint.linkedListToOutputStack
    
 endLinkedListToOutputStackDebugPrint:    ; print the whole list
    cmp ecx, 0
    je printEnterAndFinishDebugPrint
    
    pop eax

    cmp dword [avoidZeros], 1
    je avoidZerosLoopDebugPrint

continueAfterZerosPrefixDebugPrint:
    pushad
    push eax
    push format_char 
    call printf
    add esp, 8
    popad
    
    dec ecx
    jmp endLinkedListToOutputStackDebugPrint
    
printEnterAndFinishDebugPrint:
    cmp dword [avoidZeros], 1 ; It means we only had zeros up until now, and we should print at least one
    je printOneZeroDebugPrint
    mov dword [avoidZeros], 1
continueAfterOneZeroDebugPrint:
    push 10
    push format_char
    call printf
    add esp, 8
    
    inc dword [stack_counter]
    jmp inputLoop ; TODO REMOVE

avoidZerosLoopDebugPrint:
    cmp eax, '0'
    jne stopAvoidingZerosDebugPrint
    dec ecx
    pop eax

    cmp ecx, 0
    je printEnterAndFinishDebugPrint
    jmp avoidZerosLoopDebugPrint

stopAvoidingZerosDebugPrint:
    mov dword [avoidZeros], 0
    jmp continueAfterZerosPrefixDebugPrint

printOneZeroDebugPrint:
    push 0x30
    push format_char
    call printf
    add esp, 8

    jmp continueAfterOneZeroDebugPrint
; END ----------------------- debugPrint


printError_opStackOverflow:         ; print error 1
        push formatError_opStackOverflow
        call printf
        add esp, 4
        jmp inputLoop

printError_insufficientNumOfArgs:        ; print error 2
        push formatError_insufficientNumOfArgs
        call printf
        add esp, 4
        jmp inputLoop

printError_yIsAbove200: 
        inc dword [stack_counter]
        inc dword [stack_counter]
        push formatError_yIsAbove200
        call printf
        add esp, 4
        jmp inputLoop

illegal_input:
    jmp quit_case

free_LinkedList: ; for each link in the list 
    cmp dword [listToDelete], 0 ; check if null
    jne continue_freeLinkedList
    ret

continue_freeLinkedList:
    xor ecx, ecx
    xor edx, edx
    mov ecx, dword [listToDelete]
    mov edx, [ecx + 1]
    mov dword [nextLinkToDelete], edx

    push ecx
    call free
    add esp, 4

    mov edx, dword [nextLinkToDelete]
    mov dword [listToDelete], edx
    jmp free_LinkedList

quit_case:  ; for each list in the stack
freeOperandStack:
    cmp dword [stack_counter], 0    ; check if the stack is empty
    je continue_quit

    dec dword [stack_counter]
    mov eax, dword [stack_counter]
    mov eax, dword [operandStack + 4*eax]
    mov dword [listToDelete], eax
    call free_LinkedList

    jmp freeOperandStack
continue_quit:
    ; Release the last linked list on the operand stack

    mov eax, dword [stack_counter]
    mov eax, dword [operandStack + 4*eax]
    mov dword [listToDelete], eax
    cmp dword [listToDelete], 0 ; check if null
    je end_quit
    call free_LinkedList
end_quit:
    popad
    mov eax, dword [numberOfOperations]
    mov ebp, dword [ourBasePointer]
    mov esp, ebp
    pop ebp
    mov ebp, dword [basePointerToPush]
    ret