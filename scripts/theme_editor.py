#!/usr/bin/env python3

import customtkinter as ctk
import tkinter as tk
from tkinter import filedialog, messagebox

ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("blue")

# Theme presets (r, g, b in DAC 0-63

PRESETS = {
    "DEFAULT": [
        (2,3,5),(25,24,52),(21,37,10),(18,26,40),(46,9,12),(27,28,48),
        (10,40,38),(63,56,50),(3,14,17),(50,19,5),(33,53,22),(16,53,56),
        (53,17,20),(32,37,37),(56,55,27),(63,63,63),
    ],
    "VGA": [
        (0,0,0),(0,0,42),(0,42,0),(0,42,42),(42,0,0),(42,0,42),
        (42,21,0),(42,42,42),(21,21,21),(21,21,63),(21,63,21),(21,63,63),
        (63,21,21),(63,21,63),(63,63,21),(63,63,63),
    ],
    "UBUNTU": [
        (20,9,14),(18,26,40),(21,37,10),(18,26,40),(46,9,12),(29,25,36),
        (41,15,12),(22,26,28),(14,19,22),(28,41,53),(33,53,22),(16,53,56),
        (53,17,20),(41,34,45),(56,55,27),(47,50,52),
    ],
    "OCEAN": [
        (5,8,15),(10,15,30),(15,40,35),(20,45,50),(50,20,25),(35,25,45),
        (25,35,40),(45,50,55),(15,20,25),(25,35,55),(30,55,50),(35,60,63),
        (60,30,35),(50,40,55),(55,58,45),(58,60,63),
    ],
    "MONO": [
        (2,3,5),(25,24,52),(41,52,31),(12,32,32),(52,13,32),(27,28,48),
        (10,40,38),(63,57,45),(3,14,17),(50,19,5),(22,27,29),(45,34,0),
        (25,30,32),(32,37,37),(36,40,40),(63,58,44),
    ],
}

COLOR_NAMES = [
    "Black", "Blue", "Green", "Cyan", "Red", "Magenta", "Brown", "White",
    "Dk.Gray", "Lt.Blue", "Lt.Green", "Lt.Cyan", "Lt.Red", "Lt.Mag.", "Yellow", "Br.White",
]

ASCII_ART = [
    "                   .l.    lo,                 ",
    "                   ;ll.  ,lll.                ",
    "                   ,lllc lc .lll;             ",
    "                   .lllloll   clll            ",
    "                .ccllllll. , ;ll;             ",
    "               ccllllllllllo ,loll            ",
    "             lllllllllllloolllc               ",
    "           llllllllllllllllll:lc              ",
    "           llllllllllllllllllllll.            ",
    "         cllllllllllllllllllllllll            ",
    "     :clllllllllllllllllllllllllllo.          ",
    "ccllll:      .ll ;lllllllllllllllllo          ",
    "lllllll        .;  cllllllllllllllll,         ",
    " llll.           .  ,lllllllllllllllo         ",
    " ;llolc: c;         .llllllllllllllll,        ",
    "  lcllllolll  ,   . .lllllllllllllllll        ",
    "     ;c .lllo ., .: lllllllllllllllll;        ",
    "      ;:, ,lloo; cool. ;lllllllllllllll.      ",
    "       ;o:.llllolll.   ,lllllllllllllll:      ",
    "        llollll.      .lllllllllllllll.       ",
    "         :ll         .ollllllllllll           ",
    "                    :llllllll:                ",
    "                    lllll,                    ",
    "                    ;ll:                      ",
    "                     l                        ",
]

FETCH_INFO = [
    [("green", "user"), ("white", "@"), ("cyan", "PRos")],
    [("white", "-" * 15)],
    [("yellow", "OS:     "), ("white", "x16-PRos")],
    [("yellow", "Host:   "), ("white", "IBM PC AT 5170")],
    [("yellow", "Kernel: "), ("white", "PRos Kernel")],
    [("yellow", "Shell:  "), ("white", "PRos Terminal")],
    [("yellow", "CPU:    "), ("white", "Intel 8088")],
    [("yellow", "VESA:   "), ("green", "Yes")],
    [("yellow", "Res:    "), ("white", "640x480")],
    [("white", "")],
    [("__blocks__", "")],
    [("white", "")],
]


def dac_to_rgb(r6: int, g6: int, b6: int) -> tuple[int, int, int]:
    """Convert 6-bit DAC (0-63) to 8-bit RGB (0-255)."""
    return (r6 * 255 // 63, g6 * 255 // 63, b6 * 255 // 63)

def rgb_to_dac(r: int, g: int, b: int) -> tuple[int, int, int]:
    """Convert 8-bit RGB (0-255) to 6-bit DAC (0-63)."""
    return (r * 63 // 255, g * 63 // 255, b * 63 // 255)

def rgb_to_hex(r: int, g: int, b: int) -> str:
    return f"#{r:02X}{g:02X}{b:02X}"

def hex_to_rgb(s: str) -> tuple[int, int, int] | None:
    s = s.strip().lstrip("#")
    if len(s) != 6:
        return None
    try:
        return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))
    except ValueError:
        return None

def brightness(r: int, g: int, b: int) -> float:
    return 0.299 * r + 0.587 * g + 0.114 * b


class ColorPicker(ctk.CTkFrame):
    """RGB sliders + hex entry with a live swatch. All in 8-bit (0-255) space."""

    def __init__(self, parent, on_change=None, **kw):
        super().__init__(parent, **kw)
        self._cb = on_change
        self._lock = False

        # Colour swatch at top
        self.swatch = tk.Label(self, width=12, height=2, bg="#000000", relief="flat")
        self.swatch.grid(row=0, column=0, columnspan=3, padx=10, pady=(10, 4), sticky="ew")

        self._sliders: dict[str, ctk.CTkSlider] = {}
        self._vars: dict[str, tk.StringVar] = {}

        channels = [("R", "#CC3333"), ("G", "#33AA33"), ("B", "#3366CC")]
        for i, (ch, accent) in enumerate(channels):
            ctk.CTkLabel(self, text=ch, width=20).grid(
                row=i+1, column=0, padx=(10, 2), pady=3, sticky="w"
            )
            sl = ctk.CTkSlider(
                self, from_=0, to=255, number_of_steps=255, width=155,
                button_color=accent, button_hover_color=accent,
                command=self._on_slider,
            )
            sl.grid(row=i+1, column=1, padx=4, pady=3)
            var = tk.StringVar(value="0")
            ent = ctk.CTkEntry(self, textvariable=var, width=46, justify="center")
            ent.grid(row=i+1, column=2, padx=(2, 10), pady=3)
            ent.bind("<Return>", self._on_entry)
            ent.bind("<FocusOut>", self._on_entry)
            self._sliders[ch] = sl
            self._vars[ch] = var

        ctk.CTkLabel(self, text="Hex", width=20).grid(
            row=4, column=0, padx=(10, 2), pady=(8, 10), sticky="w"
        )
        self._hex_var = tk.StringVar(value="#000000")
        hex_ent = ctk.CTkEntry(self, textvariable=self._hex_var, width=95, justify="center")
        hex_ent.grid(row=4, column=1, columnspan=2, padx=(4, 10), pady=(8, 10), sticky="w")
        hex_ent.bind("<Return>", self._on_hex)
        hex_ent.bind("<FocusOut>", self._on_hex)

        self._rgb = (0, 0, 0)

    def _apply(self, r: int, g: int, b: int):
        self._rgb = (r, g, b)
        self._sliders["R"].set(r)
        self._sliders["G"].set(g)
        self._sliders["B"].set(b)
        self._vars["R"].set(str(r))
        self._vars["G"].set(str(g))
        self._vars["B"].set(str(b))
        hx = rgb_to_hex(r, g, b)
        self._hex_var.set(hx)
        self.swatch.config(bg=hx)

    def _emit(self):
        if self._cb:
            self._cb(self._rgb)

    def _on_slider(self, _):
        if self._lock:
            return
        self._lock = True
        r = int(self._sliders["R"].get())
        g = int(self._sliders["G"].get())
        b = int(self._sliders["B"].get())
        self._apply(r, g, b)
        self._lock = False
        self._emit()

    def _on_entry(self, _=None):
        if self._lock:
            return
        try:
            r = max(0, min(255, int(self._vars["R"].get())))
            g = max(0, min(255, int(self._vars["G"].get())))
            b = max(0, min(255, int(self._vars["B"].get())))
        except ValueError:
            return
        self._lock = True
        self._apply(r, g, b)
        self._lock = False
        self._emit()

    def _on_hex(self, _=None):
        rgb = hex_to_rgb(self._hex_var.get())
        if rgb is None:
            return
        self._lock = True
        self._apply(*rgb)
        self._lock = False
        self._emit()

    def set_rgb(self, r: int, g: int, b: int):
        self._lock = True
        self._apply(r, g, b)
        self._lock = False

    def get_rgb(self) -> tuple[int, int, int]:
        return self._rgb


class ThemeEditor(ctk.CTk):

    _ART_WIDTH = 48

    def __init__(self):
        super().__init__()
        self.title("x16-PRos Theme Editor")
        self.geometry("1130x720")
        self.resizable(False, False)

        # palette[i] = [r6, g6, b6] in DAC 0-63
        self.palette: list[list[int]] = [list(c) for c in PRESETS["DEFAULT"]]
        self.selected: int = 0

        self._build_toolbar()
        self._build_body()
        self._full_refresh()

    def _build_toolbar(self):
        bar = ctk.CTkFrame(self, height=50, fg_color=("gray82", "gray22"), corner_radius=0)
        bar.pack(fill="x")
        bar.pack_propagate(False)

        ctk.CTkButton(bar, text="💾  Save",   width=95, command=self._save  ).pack(side="left", padx=(10, 4), pady=10)
        ctk.CTkButton(bar, text="📂  Import", width=95, command=self._import).pack(side="left", padx=4,       pady=10)

        ctk.CTkLabel(bar, text="│", text_color="gray45").pack(side="left", padx=12)
        ctk.CTkLabel(bar, text="Presets:").pack(side="left", padx=(0, 6))

        for name in PRESETS:
            ctk.CTkButton(
                bar, text=name, width=78,
                command=lambda n=name: self._load_preset(n),
            ).pack(side="left", padx=3, pady=10)

    def _build_body(self):
        body = ctk.CTkFrame(self, fg_color="transparent")
        body.pack(fill="both", expand=True, padx=10, pady=10)

        left = ctk.CTkFrame(body, fg_color="transparent")
        left.pack(side="left", fill="both", expand=True, padx=(0, 8))

        ctk.CTkLabel(
            left, text="Terminal Preview",
            font=ctk.CTkFont(size=13, weight="bold"),
        ).pack(anchor="w", pady=(0, 6))

        self._prev_frame = ctk.CTkFrame(left, fg_color="#000000", corner_radius=6)
        self._prev_frame.pack(fill="both", expand=True)

        self._prev = tk.Text(
            self._prev_frame,
            font=("Courier", 10),
            bg="#000000", fg="#FFFFFF",
            state="disabled", relief="flat",
            padx=8, pady=8,
            wrap="none", width=72, height=30,
            cursor="arrow",
            selectbackground="#000000",
            highlightthickness=0,
        )
        self._prev.pack(fill="both", expand=True)

        right = ctk.CTkFrame(body, width=315, fg_color="transparent")
        right.pack(side="right", fill="y", padx=(0, 0))
        right.pack_propagate(False)

        ctk.CTkLabel(
            right, text="Palette  (click to edit)",
            font=ctk.CTkFont(size=13, weight="bold"),
        ).pack(anchor="w", pady=(0, 6))

        grid_frame = ctk.CTkFrame(right, corner_radius=6)
        grid_frame.pack(fill="x", pady=(0, 10))

        self._pal_cells: list[tuple[tk.Frame, tk.Button, tk.Label]] = []
        for i in range(16):
            row, col = divmod(i, 4)
            cell = tk.Frame(grid_frame, bd=2, relief="flat", bg="#1E1E1E")
            cell.grid(row=row, column=col, padx=5, pady=5)
            btn = tk.Button(
                cell, width=6, height=2, relief="flat",
                cursor="hand2",
                command=lambda i=i: self._select(i),
            )
            btn.pack()
            lbl = tk.Label(
                cell,
                text=f"{i}\n{COLOR_NAMES[i]}",
                font=("Arial", 6),
                bg="#1E1E1E", fg="#888888",
                justify="center",
            )
            lbl.pack()
            self._pal_cells.append((cell, btn, lbl))

        self._edit_label = ctk.CTkLabel(
            right, text=f"Editing: 0 \u2013 {COLOR_NAMES[0]}",
            font=ctk.CTkFont(size=12, weight="bold"),
        )
        self._edit_label.pack(anchor="w", pady=(2, 4))

        self._picker = ColorPicker(right, on_change=self._picker_changed)
        self._picker.pack(fill="x")


    def _pal_hex(self, i: int) -> str:
        return rgb_to_hex(*dac_to_rgb(*self.palette[i]))


    def _select(self, i: int):
        self.selected = i
        self._picker.set_rgb(*dac_to_rgb(*self.palette[i]))
        self._edit_label.configure(text=f"Editing: {i} \u2013 {COLOR_NAMES[i]}")
        self._refresh_palette_ui()

    def _picker_changed(self, rgb8: tuple[int, int, int]):
        self.palette[self.selected] = list(rgb_to_dac(*rgb8))
        self._refresh_palette_ui()
        self._refresh_preview()

    def _load_preset(self, name: str):
        self.palette = [list(c) for c in PRESETS[name]]
        self._full_refresh()


    def _full_refresh(self):
        self._refresh_palette_ui()
        self._refresh_preview()
        self._picker.set_rgb(*dac_to_rgb(*self.palette[self.selected]))

    def _refresh_palette_ui(self):
        for i, (cell, btn, lbl) in enumerate(self._pal_cells):
            hx = self._pal_hex(i)
            btn.config(bg=hx, activebackground=hx)
            r, g, b = dac_to_rgb(*self.palette[i])
            fg = "#000000" if brightness(r, g, b) > 128 else "#DDDDDD"
            btn.config(fg=fg)

            selected = i == self.selected
            cell.config(bg="#FFFFFF" if selected else "#1E1E1E",
                        relief="solid" if selected else "flat")
            lbl.config(fg="#EEEEEE" if selected else "#888888",
                       bg=hx if selected else "#1E1E1E")

    def _refresh_preview(self):
        bg_hex = self._pal_hex(0)
        t = self._prev
        t.config(state="normal", bg=bg_hex)
        t.delete("1.0", "end")

        for i in range(16):
            t.tag_configure(f"ci{i}", foreground=self._pal_hex(i), background=bg_hex)

        semantic = {
            "white":  self._pal_hex(7),
            "green":  self._pal_hex(2),
            "cyan":   self._pal_hex(3),
            "yellow": self._pal_hex(14),
            "red":    self._pal_hex(4),
        }
        for tag, hx in semantic.items():
            t.tag_configure(tag, foreground=hx, background=bg_hex)
        t.tag_configure("bg", foreground=bg_hex, background=bg_hex)

        for row_i, art_line in enumerate(ASCII_ART):
            padded = art_line.ljust(self._ART_WIDTH)
            t.insert("end", padded, "white")

            if row_i < len(FETCH_INFO):
                for tag, text in FETCH_INFO[row_i]:
                    if tag == "__blocks__":
                        for ci in range(16):
                            t.insert("end", "\u2588\u2588", f"ci{ci}")
                    else:
                        t.insert("end", text, tag)

            t.insert("end", "\n", "bg")

        t.insert("end", "\n", "bg")
        t.insert("end", "user",  "green")
        t.insert("end", "@",     "white")
        t.insert("end", "PRos",  "cyan")
        t.insert("end", ":/$ ",  "white")
        t.insert("end", "\u2588", "white")

        t.config(state="disabled")
        self._prev_frame.configure(fg_color=bg_hex)

    def _save(self):
        path = filedialog.asksaveasfilename(
            title="Save Theme",
            defaultextension=".cfg",
            filetypes=[("Config files", "*.cfg"), ("All files", "*.*")],
            initialfile="THEME.CFG",
        )
        if not path:
            return
        try:
            lines = []
            for i, (r6, g6, b6) in enumerate(self.palette):
                term = "\n" if i < 15 else ""
                lines.append(f"{i},{r6},{g6},{b6}{term}")
            with open(path, "w", newline="") as fh:
                fh.write("".join(lines))
            messagebox.showinfo("Saved", f"Theme saved to:\n{path}")
        except Exception as exc:
            messagebox.showerror("Error", str(exc))

    def _import(self):
        path = filedialog.askopenfilename(
            title="Import Theme",
            filetypes=[("Config files", "*.cfg"), ("All files", "*.*")],
        )
        if not path:
            return
        try:
            pal: list[list[int]] = [[0, 0, 0]] * 16
            with open(path) as fh:
                for line in fh:
                    line = line.strip()
                    if not line:
                        continue
                    parts = line.split(",")
                    if len(parts) == 4:
                        idx = int(parts[0])
                        if 0 <= idx < 16:
                            pal[idx] = [int(parts[1]), int(parts[2]), int(parts[3])]
            self.palette = pal
            self._full_refresh()
        except Exception as exc:
            messagebox.showerror("Error", str(exc))


if __name__ == "__main__":
    app = ThemeEditor()
    app.mainloop()