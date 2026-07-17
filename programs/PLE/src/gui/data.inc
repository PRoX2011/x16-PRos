; mouse + input state
mx              dw 0
my              dw 0
lmb             db 0
prev_lmb        db 0
dragging        db 0
closing         db 0
close_slot      db 0xFF
drag_slot       db 0
hit_slot        db 0xFF
hit_kind        db 0
dragdx          dw 0
dragdy          dw 0
dragx           dw 0
dragy           dw 0
dragw           dw 0
dragh           dw 0
drag_resize     db 0
cur_shape       db 0
ntmpx           dw 0
ntmpy           dw 0
ntmpw           dw 0
ntmph           dw 0

; icon layout scratch
ico_x           dw 0
ico_y           dw 0
ico_i           dw 0
ico_row         dw 0
ico_col         dw 0
icon_count      dw 0

; double-click + launch tracking
last_icon       dw 0xFFFF
last_tick       dw 0
launch_idx      dw 0
last_title_slot db 0xFF
last_title_tick dw 0
clk_last_sec    db 0xFF
clk_buf         times 24 db 0

; per-window state
w_open          times MAX_WIN db 0
w_task          times MAX_WIN db 0
w_icon          times MAX_WIN db 0
w_x             times MAX_WIN dw 0
w_y             times MAX_WIN dw 0
w_w             times MAX_WIN dw 0
w_h             times MAX_WIN dw 0
w_max           times MAX_WIN db 0
w_rx            times MAX_WIN dw 0
w_ry            times MAX_WIN dw 0
w_rw            times MAX_WIN dw 0
w_rh            times MAX_WIN dw 0
wtile_x         dw 30, 260, 30, 260, 145
wtile_y         dw 30, 30, 240, 240, 135

menu_str        db 'x16-PRos GUI v0.1', 0
pledir_name     db 'PLE.DIR', 0
guidir_name     db 'GUI.DIR', 0

file_list_buf   times 720          db 0
icon_names      times MAX_ICONS*16 db 0
icon_has_logo   times MAX_ICONS    db 0
