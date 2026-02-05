setup_welcome_msg     db 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB2, 0xB2, 0xB2, 0xB2, 0xB2, 0xB2, 0xDB, 0xDB, ' ', 'x16 PRos setup', ' ', 0xDB, 0xDB, 0xB2, 0xB2, 0xB2, 0xB2, 0xB2, 0xB2, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 10, 13, 0

setup_username_prompt db 0xC9, 39 dup(0xCD), 0xBB, 10, 13
                      db 0xBA, '  Enter your username (max 31 chars):  ', 0xBA, 10, 13
                      db 0xBA, '    _______________________________    ', 0xBA, 10, 13
                      db 0xC8, 39 dup(0xCD), 0xBC, 10, 13, 0

setup_password_prompt db 0xC9, 39 dup(0xCD), 0xBB, 10, 13
                      db 0xBA, '  Enter your password (max 31 chars):  ', 0xBA, 10, 13
                      db 0xBA, '    _______________________________    ', 0xBA, 10, 13
                      db 0xC8, 39 dup(0xCD), 0xBC, 10, 13, 0

setup_timezone_prompt db 0xC9, 39 dup(0xCD), 0xBB, 10, 13
                      db 0xBA, '  Enter your timezone offset from UTC: ', 0xBA, 10, 13
                      db 0xBA, '    _______________________________    ', 0xBA, 10, 13
                      db 0xC8, 39 dup(0xCD), 0xBC, 10, 13, 0

setup_theme_prompt    db 0xC9, 39 dup(0xCD), 0xBB, 10, 13
                      db 0xBA, '  Select color theme (1-4):            ', 0xBA, 10, 13
                      db 0xBA, '    _______________________________    ', 0xBA, 10, 13
                      db 0xC8, 39 dup(0xCD), 0xBC, 10, 13, 0

setup_prompt_prompt   db 0xC9, 39 dup(0xCD), 0xBB, 10, 13
                      db 0xBA, '  Select command prompt style (1-3):   ', 0xBA, 10, 13
                      db 0xBA, '    _______________________________    ', 0xBA, 10, 13
                      db 0xC8, 39 dup(0xCD), 0xBC, 10, 13, 0

setup_help_msg1       db 0xC9, 39 dup(0xCD), 0xBB, 10, 13
                      db 0xBA, ' Welcome to the x16-PRos installation  ', 0xBA, 10, 13
                      db 0xBA, ' and configuration wizard!             ', 0xBA, 10, 13
                      db 0xBA, 39 dup(0xC4), 0xBA, 10, 13
                      db 0xBA, ' Now the basic setup of the x16-Pros   ', 0xBA, 10, 13
                      db 0xBA, ' operating system will be performed.   ', 0xBA, 10, 13
                      db 0xBA, '                                       ', 0xBA, 10, 13
                      db 0xBA, 39 dup(0xC4), 0xBA, 10, 13
                      db 0xBA, ' Press any key to continue             ', 0xBA, 10, 13
                      db 0xC8, 39 dup(0xCD), 0xBC, 10, 13, 10, 13, 0

setup_help_msg2       db 0xC9, 39 dup(0xCD), 0xBB, 10, 13
                      db 0xBA, ' Setting up a username                 ', 0xBA, 10, 13
                      db 0xBA, '                                       ', 0xBA, 10, 13
                      db 0xBA, 39 dup(0xC4), 0xBA, 10, 13
                      db 0xBA, ' The user name is currently being      ', 0xBA, 10, 13
                      db 0xBA, ' configured. The user name is stored   ', 0xBA, 10, 13
                      db 0xBA, ' in the USER.CFG file.                 ', 0xBA, 10, 13
                      db 0xBA, '                                       ', 0xBA, 10, 13
                      db 0xC8, 39 dup(0xCD), 0xBC, 10, 13
                      db 41 dup(' '), 10, 13, 10, 13, 0

setup_help_msg3       db 0xC9, 39 dup(0xCD), 0xBB, 10, 13
                      db 0xBA, ' Setting up a password                 ', 0xBA, 10, 13
                      db 0xBA, '                                       ', 0xBA, 10, 13
                      db 0xBA, 39 dup(0xC4), 0xBA, 10, 13
                      db 0xBA, ' The password is currently being       ', 0xBA, 10, 13
                      db 0xBA, ' configured. The password is stored    ', 0xBA, 10, 13
                      db 0xBA, ' in the PASSWORD.CFG file.             ', 0xBA, 10, 13
                      db 0xBA, '                                       ', 0xBA, 10, 13
                      db 0xC8, 39 dup(0xCD), 0xBC, 10, 13, 10, 13, 0

setup_help_msg4       db 0xC9, 39 dup(0xCD), 0xBB, 10, 13
                      db 0xBA, ' Setting up timezone                   ', 0xBA, 10, 13
                      db 0xBA, '                                       ', 0xBA, 10, 13
                      db 0xBA, 39 dup(0xC4), 0xBA, 10, 13
                      db 0xBA, ' Enter offset from UTC (e.g. 3 )       ', 0xBA, 10, 13
                      db 0xBA, ' The timezone is stored in             ', 0xBA, 10, 13
                      db 0xBA, ' TIMEZONE.CFG file.                    ', 0xBA, 10, 13
                      db 0xBA, '                                       ', 0xBA, 10, 13
                      db 0xC8, 39 dup(0xCD), 0xBC, 10, 13, 10, 13, 0

setup_help_msg5       db 0xC9, 39 dup(0xCD), 0xBB, 10, 13
                      db 0xBA, ' Program selection                     ', 0xBA, 10, 13
                      db 0xBA, '                                       ', 0xBA, 10, 13
                      db 0xBA, 39 dup(0xC4), 0xBA, 10, 13
                      db 0xBA, ' Select programs package:              ', 0xBA, 10, 13
                      db 0xBA, '  [1] All programs (default)           ', 0xBA, 10, 13
                      db 0xBA, '  [2] Only essential programs          ', 0xBA, 10, 13
                      db 0xBA, '  [3] Minimal (only kernel)            ', 0xBA, 10, 13
                      db 0xC8, 39 dup(0xCD), 0xBC, 10, 13, 0

setup_help_msg6       db 0xC9, 39 dup(0xCD), 0xBB, 10, 13
                      db 0xBA, ' Setting up command prompt             ', 0xBA, 10, 13
                      db 0xBA, '                                       ', 0xBA, 10, 13
                      db 0xBA, 39 dup(0xC4), 0xBA, 10, 13
                      db 0xBA, ' Select a command prompt style:        ', 0xBA, 10, 13
                      db 0xBA, '  [1] [user@PRos] >                    ', 0xBA, 10, 13
                      db 0xBA, '  [2] ', 0xDA, 0xC4, 0xC4, ' user                         ', 0xBA, 10, 13
                      db 0xBA, '      ', 0xC0, 0xC4, ' ', 0xFE, ' ', 0x10,'                           ', 0xBA, 10, 13
                      db 0xBA, '  [3] user@pros:~$                     ', 0xBA, 10, 13
                      db 0xC8, 39 dup(0xCD), 0xBC, 10, 13, 10, 13, 0

setup_help_msg7       db 0xC9, 39 dup(0xCD), 0xBB, 10, 13
                      db 0xBA, ' Setting up color theme                ', 0xBA, 10, 13
                      db 0xBA, '                                       ', 0xBA, 10, 13
                      db 0xBA, 39 dup(0xC4), 0xBA, 10, 13
                      db 0xBA, ' Select your preferred color theme:    ', 0xBA, 10, 13
                      db 0xBA, '  [1] Standard (default PRos colors)   ', 0xBA, 10, 13
                      db 0xBA, '  [2] Ubuntu (warm orange/purple)      ', 0xBA, 10, 13
                      db 0xBA, '  [3] VGA Default (classic 16 colors)  ', 0xBA, 10, 13
                      db 0xBA, '  [4] Ocean Deep (blue aqua theme)     ', 0xBA, 10, 13
                      db 0xC8, 39 dup(0xCD), 0xBC, 10, 13, 10, 13, 0

setup_program_prompt  db 0xC9, 39 dup(0xCD), 0xBB, 10, 13
                      db 0xBA, ' Enter your choice (1-3):              ', 0xBA, 10, 13
                      db 0xBA, '    _______________________________    ', 0xBA, 10, 13
                      db 0xC8, 39 dup(0xCD), 0xBC, 10, 13, 0

setup_bottom_msg      db 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB2, 0xB2, 0xB2, 0xB2, 0xB2, 0xB2, 0xDB, 0xDB, 0xDB, 0xDB, 0xDB, 0xDB, 0xDB, 0xDB, 0xDB, 0xDB, 0xDB, 0xDB, 0xDB, 0xDB, 0xDB, 0xDB, 0xDB, 0xDB, 0xDB, 0xDB, 0xB2, 0xB2, 0xB2, 0xB2, 0xB2, 0xB2, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0
setup_complete_msg    db 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, ' Setup was successfully completed! Press any key to continue. ', 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0