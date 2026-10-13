#!/usr/bin/env python3
# equ2h.py - gera c/ermo_equ.h com as constantes .equ do assembly
# (comum.h e pixel.h), para o codigo em C usar os mesmos numeros.
#   python3 arte/equ2h.py comum.h pixel.h > c/ermo_equ.h
import re, sys
print('// ermo_equ.h - GERADO por arte/equ2h.py a partir de %s (nao edite)' % ', '.join(sys.argv[1:]))
print('#pragma once')
for f in sys.argv[1:]:
    for line in open(f):
        m = re.match(r'\s*\.equ\s+(\w+)\s*,\s*([^/]+?)\s*(//.*)?$', line)
        if m:
            print('#define %s (%s)' % (m.group(1), m.group(2)))
