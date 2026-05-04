.386
.model flat, stdcall
option casemap :none

include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
include \masm32\include\masm32.inc
include \masm32\include\user32.inc

includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\masm32.lib
includelib \masm32\lib\user32.lib




; CONSTANTS
PLAYER_START_HP equ 100        ; health(100%)
ENEMY_START_HP  equ 100        ; new enemy each room
TOTAL_ROOMS     equ 3          ; win when roomMoved >= 3
POTION_HEAL     equ 30         ; playerhealth +30
POTION_REWARD   equ 2          ; add 2 potions on kill





.data

    ; MAIN MENU
    MenuHeader  db 10,"================================================",10,0
    MenuTitle   db    "           DUNGEON QUEST                        ",10,0
    MenuFooter  db    "================================================",10,0
    MenuOpt1    db 10,"  [1] New Game",10,0
    MenuOpt2    db    "  [2] Load Game",10,0
    MenuOpt3    db    "  [3] Exit",10,0
    MenuPrompt  db 10,"  Enter choice: ",0




    ; ROOM DISPLAY
    GameHeader  db 10,"================================================",10,0
    GameFooter  db    "================================================",10,0
    RoomLbl     db 10,"  Room        : ",0
    RoomSuffix  db " / 3",10,0
    PHPLbl      db    "  Player HP   : ",0
    EHPLbl      db    "  Enemy HP    : ",0
    HPSuffix    db 10,0
    PotLbl      db    "  Potions     : ",0
    PotSuffix   db 10,0
    EnemyHere   db    "  [!] An enemy stands before you!",10,0
    NoEnemy     db    "  [ ] The room is clear.",10,0



    ; ACTION MENU
    ActionHdr   db 10,"  What do you do?",10,0
    ActMove     db    "  [1] Move",10,0
    ActFight    db    "  [2] Fight",10,0
    ActInv      db    "  [3] Inventory",10,0
    ActSave     db    "  [4] Save",10,0
    ActBack     db    "  [5] Back to Menu",10,0
    ActPrompt   db 10,"  Enter choice: ",0



    ; FIGHT
    FightHdr    db 10,"  --- COMBAT ---",10,0
    FightRound  db    "  You trade blows with the enemy!",10,0
    FightDmg1   db    "  Enemy HP  : ",0
    FightDmg2   db    "  Your HP   : ",0
    FightNewLn  db 10,0
    EnemyDead   db 10,"  Enemy Defeated",10,0
    FightNone   db 10,"  No enemy here. Nothing to fight.",10,0
    PotReward1  db    "  You find ",0
    PotReward2  db " potions on the enemy!",10,0



    ; INVENTORY MENU
    InvHeader   db 10,"  --- INVENTORY ---",10,0
    InvPotLine  db    "  Potions : ",0
    InvPotSfx   db 10,0
    InvOpt1     db 10,"  [1] Use Potion  (HP +30)",10,0
    InvOpt2     db    "  [2] Back",10,0
    InvPrompt   db 10,"  Enter choice: ",0
    PotUsed     db 10,"  You drink a potion. HP +30!",10,0
    PotNone     db 10,"  You have no potions!",10,0
    PotFull     db 10,"  HP is already full (100)!",10,0



    ; MOVE
    MoveOk      db 10,"  You advance to the next room...",10,0
    MoveFail    db 10,"  Defeat the enemy before moving!",10,0
    

    ; SAVE / LOAD
    SaveOk      db 10,"  Game saved to savegame.txt!",10,0
    SaveFail    db 10,"  Failed to save.",10,0
    LoadOk      db 10,"  Save file loaded!",10,0
    LoadFail    db 10,"  No save file found. Starting new game.",10,0

    ; WIN / LOSE
    WinMsg1     db 10,"================================================",10,0
    WinMsg2     db    "   YOU CLEARED ALL 3 ROOMS!  YOU WIN!",10,0



    LoseMsg1    db 10,"================================================",10,0
    LoseMsg2    db    "   YOU DIED...  GAME OVER.",10,0
    LoseMsg3    db    "================================================",10,10,0


    BackMenuMsg db 10,"  Returning to main menu...",10,0
    ExitMsg     db 10,"  Thanks for playing! Goodbye.",10,10,0
    PressKey    db 10,"  Press ENTER to continue...",0
    BadInput    db 10,"  Invalid choice. Try again.",10,0

    ; ---- FILE
    SaveFileName db "savegame.txt",0
    SpaceStr     db " ",0

    ; ---- NUMBER HELPERS
    Rm1Str  db "1",0
    Rm2Str  db "2",0
    Rm3Str  db "3",0





.data?
    Choice      db 8 dup(?)
    InvChoice   db 8 dup(?)
    Dummy       db 8 dup(?)
    NumBuf      db 16 dup(?)



    PlayerHealth dd ?      
    RoomCount    dd ?       ; room count / roomMoved
    EnemyHealth  dd ?       
    PotionCount  dd ?       ; inventory (only item = potion)
    TheresEnemy  dd ?       ; 1 = enemy alive, 0 = cleared


    hFile        dd ?
    SaveBuf      db 40 dup(?)
    LoadBuf      db 40 dup(?)
    TokBuf       db 16 dup(?)   ; temp buffer for each parsed token






; CODE
.code




PrintNum proc
    invoke dwtoa, eax, addr NumBuf
    invoke StdOut, addr NumBuf
    ret
PrintNum endp





; DrawRoom/Initialize Room
DrawRoom proc
    invoke ClearScreen
    invoke StdOut, addr GameHeader

    ; Room N / 3
    invoke StdOut, addr RoomLbl
    .if RoomCount == 1
        invoke StdOut, addr Rm1Str
    .elseif RoomCount == 2
        invoke StdOut, addr Rm2Str
    .else
        invoke StdOut, addr Rm3Str
    .endif
    invoke StdOut, addr RoomSuffix

    ; Player HP
    invoke StdOut, addr PHPLbl
    mov eax, PlayerHealth
    call PrintNum
    invoke StdOut, addr HPSuffix

    ; Enemy HP (only show if enemy alive)
    .if TheresEnemy == 1
        invoke StdOut, addr EHPLbl
        mov eax, EnemyHealth
        call PrintNum
        invoke StdOut, addr HPSuffix
    .endif



    ; Potion count
    invoke StdOut, addr PotLbl
    mov eax, PotionCount
    call PrintNum
    invoke StdOut, addr PotSuffix

    invoke StdOut, addr GameFooter



    ; Enemy status
    .if TheresEnemy == 1
        invoke StdOut, addr EnemyHere
    .else
        invoke StdOut, addr NoEnemy
    .endif

    ret
DrawRoom endp





; CopyToken
;   IN : EBX = pointer to start of token in LoadBuf
;   OUT: TokBuf filled with digits, null-terminated
;        EBX advanced past token and trailing space
;   Copies digit characters into TokBuf until space or null found
CopyToken proc


    push edi
    lea edi, TokBuf         ; EDI = destination

    @@copy:
        mov al, [ebx]       ; read char from LoadBuf
        .if al == ' ' || al == 0 || al == 13 || al == 10
            mov byte ptr [edi], 0   ; null-terminate TokBuf
            .if al == ' '
                inc ebx     ; skip the space
            .endif
            pop edi
            ret
        .endif
        mov [edi], al       ; copy digit to TokBuf
        inc ebx
        inc edi
        jmp @@copy
CopyToken endp






; SaveGame
SaveGame proc
    ; Build save string manually using dwtoa (avoids wsprintf number corruption)
    ; Format: "playerHP roomCount enemyHP potionCount"
    invoke dwtoa, PlayerHealth, addr SaveBuf
    invoke lstrcat, addr SaveBuf, addr SpaceStr
    invoke dwtoa, RoomCount, addr NumBuf
    invoke lstrcat, addr SaveBuf, addr NumBuf
    invoke lstrcat, addr SaveBuf, addr SpaceStr
    invoke dwtoa, EnemyHealth, addr NumBuf
    invoke lstrcat, addr SaveBuf, addr NumBuf
    invoke lstrcat, addr SaveBuf, addr SpaceStr
    invoke dwtoa, PotionCount, addr NumBuf
    invoke lstrcat, addr SaveBuf, addr NumBuf

    invoke CreateFile, addr SaveFileName,
                       GENERIC_WRITE, 0, NULL,
                       CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL
    mov hFile, eax

    .if eax == INVALID_HANDLE_VALUE
        invoke StdOut, addr SaveFail
        ret
    .endif

    invoke lstrlen, addr SaveBuf
    invoke WriteFile, hFile, addr SaveBuf, eax, addr Dummy, NULL
    invoke CloseHandle, hFile
    invoke StdOut, addr SaveOk
    ret
SaveGame endp






; LoadGame
LoadGame proc
    invoke CreateFile, addr SaveFileName,
                       GENERIC_READ, 0, NULL,
                       OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
    mov hFile, eax

    ; Flowchart: check if there's Saved file
    .if eax == INVALID_HANDLE_VALUE
        invoke StdOut, addr LoadFail
        ; fall back: same as new game
        mov PlayerHealth, PLAYER_START_HP
        mov RoomCount,    1
        mov EnemyHealth,  ENEMY_START_HP
        mov PotionCount,  0
        mov TheresEnemy,  1
        ret
    .endif

    invoke ReadFile, hFile, addr LoadBuf, 39, addr Dummy, NULL
    invoke CloseHandle, hFile


    lea ebx, LoadBuf        ; EBX walks through the save string

    ; Token 1: PlayerHealth
    call CopyToken          ; copies digits at EBX into TokBuf, advances EBX
    invoke atodw, addr TokBuf
    mov PlayerHealth, eax

    ; Token 2: RoomCount
    call CopyToken
    invoke atodw, addr TokBuf
    mov RoomCount, eax

    ; Token 3: EnemyHealth
    call CopyToken
    invoke atodw, addr TokBuf
    mov EnemyHealth, eax

    ; Token 4: PotionCount
    call CopyToken
    invoke atodw, addr TokBuf
    mov PotionCount, eax

    ; restore TheresEnemy based on loaded EnemyHealth
    .if EnemyHealth > 0
        mov TheresEnemy, 1
    .else
        mov TheresEnemy, 0
    .endif

    invoke StdOut, addr LoadOk
    ret
LoadGame endp






; DoFight
DoFight proc
    ; Flowchart: if theresEnemy == true
    .if TheresEnemy == 0
        invoke StdOut, addr FightNone
        invoke StdOut, addr PressKey
        invoke StdIn,  addr Dummy, 4
        ret
    .endif

    invoke StdOut, addr FightHdr
    invoke StdOut, addr FightRound

    ; enemy health -50  (flat 50 damage per fight action)
    mov eax, EnemyHealth
    .if eax > 50
        sub eax, 50
    .else
        mov eax, 0          ; cannot go below 0
    .endif
    mov EnemyHealth, eax

    ; player health -30  (flat 30 damage per fight action)
    mov eax, PlayerHealth
    .if eax > 30
        sub eax, 30
    .else
        mov eax, 0          ; cannot go below 0
    .endif
    mov PlayerHealth, eax

    ; show updated HP
    invoke StdOut, addr FightDmg1
    mov eax, EnemyHealth
    call PrintNum
    invoke StdOut, addr FightNewLn

    invoke StdOut, addr FightDmg2
    mov eax, PlayerHealth
    call PrintNum
    invoke StdOut, addr FightNewLn

    ; Flowchart: if EnemyHealth <= 0 -> enemy defeated
    ;            if EnemyHealth > 0  -> return, still alive
    mov eax, EnemyHealth
    .if eax == 0
        jmp EnemyDefeated
    .endif

    ret             ; enemy still alive, exit fight for now




    EnemyDefeated:
        invoke StdOut, addr EnemyDead
        mov TheresEnemy, 0

        mov eax, PotionCount
        add eax, POTION_REWARD      ; +2 potions
        mov PotionCount, eax

        invoke StdOut, addr PotReward1
        mov eax, POTION_REWARD
        call PrintNum
        invoke StdOut, addr PotReward2

    ret
DoFight endp




; DoInventory
; Display current items (potion)

DoInventory proc
    InvLoop:
        ; Flowchart: Display current items - potion
        invoke StdOut, addr InvHeader
        invoke StdOut, addr InvPotLine
        mov eax, PotionCount
        call PrintNum
        invoke StdOut, addr InvPotSfx

        invoke StdOut, addr InvOpt1
        invoke StdOut, addr InvOpt2
        invoke StdOut, addr InvPrompt
        invoke StdIn,  addr InvChoice, 8

        ; Flowchart: potion -> use potion: playerhealth +30
        .if InvChoice == '1'
            .if PotionCount == 0
                invoke StdOut, addr PotNone
            .else
                ; only use if HP is not already full
                mov eax, PlayerHealth
                .if eax >= PLAYER_START_HP
                    invoke StdOut, addr PotFull
                .else
                    dec PotionCount
                    mov eax, PlayerHealth
                    add eax, POTION_HEAL    ; playerhealth + 30
                    ; cap at 100
                    .if eax > PLAYER_START_HP
                        mov eax, PLAYER_START_HP
                    .endif
                    mov PlayerHealth, eax
                    invoke StdOut, addr PotUsed
                    invoke StdOut, addr PHPLbl
                    mov eax, PlayerHealth
                    call PrintNum
                    invoke StdOut, addr FightNewLn
                .endif
            .endif
            invoke StdOut, addr PressKey
            invoke StdIn,  addr Dummy, 4

        ; Flowchart: back -> return
        .elseif InvChoice == '2'
            ret

        .else
            invoke StdOut, addr BadInput
            invoke StdOut, addr PressKey
            invoke StdIn,  addr Dummy, 4
        .endif

    jmp InvLoop
DoInventory endp




; CheckWinLose
CheckWinLose proc
    ; Flowchart: health<=0 -> End
    mov eax, PlayerHealth
    .if eax == 0
        invoke StdOut, addr LoseMsg1
        invoke StdOut, addr LoseMsg2
        invoke StdOut, addr LoseMsg3
        invoke StdOut, addr PressKey
        invoke StdIn,  addr Dummy, 4
        mov eax, 1
        ret
    .endif

    ; still alive
    mov eax, 0
    ret
CheckWinLose endp






GameLoop proc
    GameTick:
        call DrawRoom

        invoke StdOut, addr ActionHdr
        invoke StdOut, addr ActMove
        invoke StdOut, addr ActFight
        invoke StdOut, addr ActInv
        invoke StdOut, addr ActSave
        invoke StdOut, addr ActBack
        invoke StdOut, addr ActPrompt
        invoke StdIn,  addr Choice, 8




        ; [1] MOVE
        .if Choice == '1'
            .if TheresEnemy == 1
                ; Flowchart: blocked by enemy
                invoke StdOut, addr MoveFail
                invoke StdOut, addr PressKey
                invoke StdIn,  addr Dummy, 4
            .else
                invoke StdOut, addr MoveOk

                ; Flowchart: initialize new enemy
                mov EnemyHealth, ENEMY_START_HP
                mov TheresEnemy, 1

                ; Flowchart: add 1 roomMoved count
                inc RoomCount

                invoke StdOut, addr PressKey
                invoke StdIn,  addr Dummy, 4

                ; Flowchart: if roomMoved >= 3 -> Win (End)
                mov eax, RoomCount
                .if eax > TOTAL_ROOMS
                    invoke StdOut, addr WinMsg1
                    invoke StdOut, addr WinMsg2
                    invoke StdOut, addr WinMsg3
                    invoke StdOut, addr PressKey
                    invoke StdIn,  addr Dummy, 4
                    ret         ; back to main menu
                .endif
            .endif






        ; [2] FIGHT

        .elseif Choice == '2'
            call DoFight

            invoke StdOut, addr PressKey
            invoke StdIn,  addr Dummy, 4

            ; Flowchart: Check Win/Lose Condition
            call CheckWinLose
            .if eax == 1
                ret
            .endif

        ;===================================================
        ; [3] INVENTORY

        .elseif Choice == '3'
            call DoInventory

        ;===================================================
        ; [4] SAVE

        .elseif Choice == '4'
            call SaveGame
            invoke StdOut, addr PressKey
            invoke StdIn,  addr Dummy, 4

        ;===================================================
        ; [5] BACK TO MENU

        .elseif Choice == '5'
            invoke StdOut, addr BackMenuMsg
            ret

        ; Flowchart: False arrow on Get Player Input -> loop back
        .else
            invoke StdOut, addr BadInput
            invoke StdOut, addr PressKey
            invoke StdIn,  addr Dummy, 4
        .endif

    jmp GameTick
GameLoop endp






start:
    MainMenu:
        invoke ClearScreen
        invoke StdOut, addr MenuHeader
        invoke StdOut, addr MenuTitle
        invoke StdOut, addr MenuFooter
        invoke StdOut, addr MenuOpt1
        invoke StdOut, addr MenuOpt2
        invoke StdOut, addr MenuOpt3
        invoke StdOut, addr MenuPrompt
        invoke StdIn,  addr Choice, 8




        ; [1] NEW GAME
        .if Choice == '1'
            mov PlayerHealth, PLAYER_START_HP
            mov RoomCount,    1
            mov EnemyHealth,  ENEMY_START_HP
            mov PotionCount,  0
            mov TheresEnemy,  1
            call GameLoop

        ; [2] LOAD GAME
        .elseif Choice == '2'
            call LoadGame
            invoke StdOut, addr PressKey
            invoke StdIn,  addr Dummy, 4
            call GameLoop

        ; [3] EXIT
        .elseif Choice == '3'
            invoke StdOut, addr ExitMsg
            invoke ExitProcess, 0


        .else
            invoke StdOut, addr BadInput
            invoke StdOut, addr PressKey
            invoke StdIn,  addr Dummy, 4
        .endif

    jmp MainMenu

end start
