import curses
import os

class HexEditor:
    def __init__(self, filename):
        self.filename = filename
        with open(filename, 'rb+') as f:
            self.data = bytearray(f.read())
        self.offset = 0
        self.cursor_pos = 0
        self.hex_mode = True
        self.edit_nibble = 0  # 0 = high nibble, 1 = low nibble
        self.running = True

    def save_changes(self):
        with open(self.filename, 'wb') as f:
            f.write(self.data)

    def display(self, stdscr):
        stdscr.clear()
        height, width = stdscr.getmaxyx()
        lines = min(height - 2, (len(self.data) + 15) // 16 - self.offset // 16)
        
        for i in range(lines):
            current_offset = self.offset + i * 16
            if current_offset >= len(self.data):
                break
            
            # Address
            addr = f"{current_offset:08X}"
            stdscr.addstr(i, 0, addr)
            
            # Hex data
            hex_part = ' '.join(
                f"{self.data[current_offset + j]:02X}" 
                if current_offset + j < len(self.data) else '  ' 
                for j in range(16))
            stdscr.addstr(i, 9, hex_part)
            
            # ASCII part
            ascii_part = ''.join(
                chr(self.data[current_offset + j]) 
                if 32 <= self.data[current_offset + j] <= 126 and current_offset + j < len(self.data) 
                else '.' 
                for j in range(16))
            stdscr.addstr(i, 9 + 16 * 3 + 1, ascii_part)
        
        # Calculate cursor position
        cursor_line = (self.offset + self.cursor_pos) // 16 - self.offset // 16
        if self.hex_mode:
            cursor_col = 9 + (self.cursor_pos * 3) + self.edit_nibble
        else:
            cursor_col = 9 + 16 * 3 + 1 + self.cursor_pos
        
        # Status line
        status = f"Offset: {self.offset + self.cursor_pos:08X} | Mode: {'HEX' if self.hex_mode else 'ASCII'} | Ctrl+S: Save | q: Quit"
        try:
            stdscr.addstr(height-1, 0, status[:width-1])
        except curses.error:
            pass
        
        # Position cursor
        try:
            stdscr.move(cursor_line, cursor_col)
        except curses.error:
            pass
        
        stdscr.refresh()

    def handle_edit(self, key):
        current_byte_pos = self.offset + self.cursor_pos
        if current_byte_pos >= len(self.data):
            return

        if self.hex_mode:
            if key in range(ord('0'), ord('9')+1) or key in range(ord('a'), ord('f')+1) or key in range(ord('A'), ord('F')+1):
                char = chr(key).upper()
                val = int(char, 16)
                current_byte = self.data[current_byte_pos]
                
                if self.edit_nibble == 0:
                    new_byte = (val << 4) | (current_byte & 0x0F)
                    self.edit_nibble = 1
                else:
                    new_byte = (current_byte & 0xF0) | val
                    self.edit_nibble = 0
                    if self.cursor_pos < 15 and (current_byte_pos + 1) < len(self.data):
                        self.cursor_pos += 1
                
                self.data[current_byte_pos] = new_byte
        else:
            if 32 <= key <= 126:
                self.data[current_byte_pos] = key
                if self.cursor_pos < 15 and (current_byte_pos + 1) < len(self.data):
                    self.cursor_pos += 1

    def run(self, stdscr):
        curses.curs_set(1)
        self.display(stdscr)
        
        while self.running:
            key = stdscr.getch()
            height, width = stdscr.getmaxyx()
            max_lines = height - 1
            max_offset = (len(self.data) // 16) * 16
            
            if key == curses.KEY_UP:
                self.offset = max(0, self.offset - 16)
                self.cursor_pos = min(self.cursor_pos, 15)
            elif key == curses.KEY_DOWN:
                if self.offset + 16 < len(self.data):
                    self.offset += 16
                    self.cursor_pos = min(self.cursor_pos, 15)
            elif key == curses.KEY_LEFT:
                if self.cursor_pos > 0:
                    self.cursor_pos -= 1
                    self.edit_nibble = 0
                elif self.offset >= 16:
                    self.offset -= 16
                    self.cursor_pos = 15
                    self.edit_nibble = 0
            elif key == curses.KEY_RIGHT:
                if self.cursor_pos < 15 and (self.offset + self.cursor_pos + 1) < len(self.data):
                    self.cursor_pos += 1
                    self.edit_nibble = 0
                elif self.offset + 16 < len(self.data):
                    self.offset += 16
                    self.cursor_pos = 0
                    self.edit_nibble = 0
            elif key == ord('\t'):
                self.hex_mode = not self.hex_mode
            elif key == 19:  # Ctrl+S
                self.save_changes()
                # Show save confirmation
                try:
                    stdscr.addstr(height-1, 0, "Changes saved successfully! Press any key to continue...")
                    stdscr.refresh()
                    stdscr.getch()
                except curses.error:
                    pass
            elif key == ord('q'):
                self.running = False
            else:
                self.handle_edit(key)
            
            self.display(stdscr)

def main():
    import sys
    if len(sys.argv) != 2:
        print("Usage: hexo.py <filename>")
        return
    
    filename = sys.argv[1]
    if not os.path.exists(filename):
        print(f"File {filename} not found!")
        return
    
    editor = HexEditor(filename)
    curses.wrapper(editor.run)
    editor.save_changes()

if __name__ == '__main__':
    main()
