# Made by Ilnarildarovuch

import struct
import sys
import math
import argparse

IMF_RATE = 700.0
OPL_CHANNELS = 9

# 9 channels
OP_OFFSETS = [
    [0x00, 0x03], [0x01, 0x04], [0x02, 0x05],
    [0x08, 0x0B], [0x09, 0x0C], [0x0A, 0x0D],
    [0x10, 0x13], [0x11, 0x14], [0x12, 0x15]
]

# frequences
NOTE_FREQS = []
for i in range(128):
    freq = 440.0 * (2.0 ** ((i - 69) / 12.0))
    NOTE_FREQS.append(freq)

# midi parser
def read_variable_length(data, ptr):
    # VLV
    value = 0
    while True:
        byte = data[ptr]
        ptr += 1
        value = (value << 7) | (byte & 0x7F)
        if not (byte & 0x80):
            break
    return value, ptr

def parse_midi(filename):
    # parser itself
    with open(filename, 'rb') as f:
        data = f.read()

    if data[0:4] != b'MThd':
        raise ValueError("Invalid MIDI file header")

    # header
    fmt, tracks_count, division = struct.unpack('>HHH', data[8:14])

    ptr = 14
    all_events = []

    # 120 BPM
    tempo = 500000

    for _ in range(tracks_count):
        if data[ptr:ptr+4] != b'MTrk':
            break
        track_len = struct.unpack('>I', data[ptr+4:ptr+8])[0]
        ptr += 8
        track_end = ptr + track_len

        current_tick = 0
        last_status = 0

        while ptr < track_end:
            delta, ptr = read_variable_length(data, ptr)
            current_tick += delta

            if data[ptr] & 0x80:
                status = data[ptr]
                ptr += 1
                last_status = status
            else:
                status = last_status

            cmd = status & 0xF0
            ch = status & 0x0F

            if cmd == 0x80: # note Off
                note = data[ptr]; vel = data[ptr+1]; ptr += 2
                all_events.append({'tick': current_tick, 'type': 'off', 'ch': ch, 'note': note})
            elif cmd == 0x90: # note On
                note = data[ptr]; vel = data[ptr+1]; ptr += 2
                if vel == 0:
                    all_events.append({'tick': current_tick, 'type': 'off', 'ch': ch, 'note': note})
                else:
                    all_events.append({'tick': current_tick, 'type': 'on', 'ch': ch, 'note': note, 'vel': vel})
            elif cmd in (0xA0, 0xB0, 0xE0): # magic
                ptr += 2
            elif cmd in (0xC0, 0xD0): # magic
                ptr += 1
            elif status == 0xFF: # FKN MAGIK
                meta_type = data[ptr]
                ptr += 1
                length, ptr = read_variable_length(data, ptr)
                if meta_type == 0x51: # tempo
                    tempo = struct.unpack('>I', b'\x00' + data[ptr:ptr+3])[0]
                    all_events.append({'tick': current_tick, 'type': 'tempo', 'val': tempo})
                elif meta_type == 0x2F: # end of track
                    pass
                ptr += length
            else:
                pass

    all_events.sort(key=lambda x: x['tick'])

    abs_events = []
    current_time = 0.0
    prev_tick = 0
    current_tempo = 500000 # mks per beat
    ticks_per_beat = division if division & 0x8000 == 0 else 480

    for ev in all_events:
        delta_ticks = ev['tick'] - prev_tick
        # time = (ticks * (mks_per_beat / ticks_per_beat)) / 1000000
        seconds_per_tick = (current_tempo / ticks_per_beat) / 1000000.0
        current_time += delta_ticks * seconds_per_tick
        prev_tick = ev['tick']

        if ev['type'] == 'tempo':
            current_tempo = ev['val']
        elif ev['type'] in ('on', 'off'):
            ev['time'] = current_time
            abs_events.append(ev)

    return abs_events

# OPL2
class OPL2Allocator:
    def __init__(self):
        self.channels = [{'note': -1, 'midi_ch': -1, 'active': False} for _ in range(OPL_CHANNELS)]
        self.lru_counter = 0
        self.last_used = [0] * OPL_CHANNELS

    def allocate(self, midi_ch, note):
        self.lru_counter += 1

        for i in range(OPL_CHANNELS):
            if not self.channels[i]['active']:
                self.channels[i] = {'note': note, 'midi_ch': midi_ch, 'active': True}
                self.last_used[i] = self.lru_counter
                return i

        oldest_idx = self.last_used.index(min(self.last_used))
        self.channels[oldest_idx] = {'note': note, 'midi_ch': midi_ch, 'active': True}
        self.last_used[oldest_idx] = self.lru_counter
        return oldest_idx

    def release(self, midi_ch, note):
        for i in range(OPL_CHANNELS):
            if self.channels[i]['active'] and \
               self.channels[i]['midi_ch'] == midi_ch and \
               self.channels[i]['note'] == note:
                self.channels[i]['active'] = False
                return i
        return -1

def calc_opl_freq(hz):
    if hz == 0: return 0, 0

    for block in range(8):
        fnum = (hz * (1 << (20 - block))) / 49716.0
        if fnum < 1024:
            return int(fnum), block
    return 1023, 7 # max value

class ImfWriter:
    def __init__(self):
        self.buffer = bytearray()
        self.total_ticks = 0
        self.current_delay_buffer = 0

    def add_packet(self, reg, val, delay_ticks=0):
        total_delay = self.current_delay_buffer + delay_ticks

        while total_delay > 65535:
            # too much
            self.buffer.extend(struct.pack('<HBB', 65535, 0, 0))
            total_delay -= 65535

        self.buffer.extend(struct.pack('<HBB', int(total_delay), reg, val))
        self.current_delay_buffer = 0 # release delay
        self.total_ticks += total_delay

    def wait(self, ticks):
        self.current_delay_buffer += ticks

    def get_binary(self):
        length = len(self.buffer)
        header = struct.pack('<I', length)
        return header + self.buffer

def setup_default_instrument(writer, ch):
    op1_off = OP_OFFSETS[ch][0] # Modulator
    op2_off = OP_OFFSETS[ch][1] # Carrier

    # 20: Multiplier / Tremolo / Vibrato
    writer.add_packet(0x20 + op1_off, 0x01)
    writer.add_packet(0x20 + op2_off, 0x01)

    # 40: KSL / Output Level
    writer.add_packet(0x40 + op1_off, 0x40 | 0x15)
    writer.add_packet(0x40 + op2_off, 0x10)

    # 60: Attack / Decay
    writer.add_packet(0x60 + op1_off, 0x60)
    writer.add_packet(0x60 + op2_off, 0x60)

    # 80: Sustain / Release
    writer.add_packet(0x80 + op1_off, 0x75)
    writer.add_packet(0x80 + op2_off, 0x75)

    # E0: Waveform Select
    writer.add_packet(0xE0 + op1_off, 0x00)
    writer.add_packet(0xE0 + op2_off, 0x00)

    # C0: Feedback / Connection
    writer.add_packet(0xC0 + ch, 0x00) # 0 to SAVE YOUR EARS. OTHERSWISE TS WOULD MAKE WHITE NOISE

def convert_mid_to_imf(input_file, output_file):
    print(f"Reading MIDI: {input_file}")
    events = parse_midi(input_file)

    writer = ImfWriter()
    allocator = OPL2Allocator()

    # waveform select enable
    writer.add_packet(0x01, 0x20)
    # keyboard Split
    writer.add_packet(0x08, 0x00)

    # default instrument
    for i in range(OPL_CHANNELS):
        setup_default_instrument(writer, i)

    current_time = 0.0

    print(f"Processing {len(events)} events...")

    for ev in events:
        # delta
        delta_time = ev['time'] - current_time
        if delta_time < 0: delta_time = 0

        ticks = int(delta_time * IMF_RATE)
        if ticks > 0:
            writer.wait(ticks)
            current_time = ev['time']
        if ev.get('ch') == 9: # save YOUR ears again. YOUR TAKING TOO LONG
            continue
        if ev['type'] == 'on':
            # allocate channel
            ch_idx = allocator.allocate(ev['ch'], ev['note'])

            # calculate pitch
            freq = NOTE_FREQS[ev['note']]
            fnum, block = calc_opl_freq(freq)

            # key OFF
            writer.add_packet(0xB0 + ch_idx, 0x00)

            # set freq
            writer.add_packet(0xA0 + ch_idx, fnum & 0xFF)

            # set ON + block + B0
            b0_val = 0x20 | ((block & 0x07) << 2) | ((fnum >> 8) & 0x03)
            writer.add_packet(0xB0 + ch_idx, b0_val)

        elif ev['type'] == 'off':
            ch_idx = allocator.release(ev['ch'], ev['note'])
            if ch_idx != -1:
                freq = NOTE_FREQS[ev['note']]
                fnum, block = calc_opl_freq(freq)

                b0_val = ((block & 0x07) << 2) | ((fnum >> 8) & 0x03)
                writer.add_packet(0xB0 + ch_idx, b0_val)

    # FINALLY
    print(f"Writing IMF: {output_file}")
    with open(output_file, 'wb') as f:
        f.write(writer.get_binary())
    print("Done!")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="MIDI to IMF")
    parser.add_argument("input", help="Input .mid file")
    parser.add_argument("output", nargs="?", help="Output .imf file")

    args = parser.parse_args()

    out_path = args.output
    if not out_path:
        out_path = args.input.rsplit('.', 1)[0] + ".imf"

    try:
        convert_mid_to_imf(args.input, out_path)
    except Exception as e:
        print(f"Error: {e}")
