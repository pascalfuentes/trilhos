// =====================================================================
//  ermo.h - base do codigo em C do Ermo (o jogo esta migrando de assembly
//  para C aos poucos; os dois convivem no mesmo executavel).
//
//  - O estado global continua no bloco G do assembly: o registrador x28
//    aponta sempre para ele. O C e compilado com -ffixed-x28 para nunca
//    mexer nesse registrador, e le/escreve G pelos mesmos deslocamentos
//    (G_*, gerados de comum.h em ermo_equ.h).
//  - Funcao em assembly chamada do C: declare com ASM(nome), que acerta o
//    nome no Mac (sem o "_" que o C poe na frente).
//  - Funcao em C chamada do assembly: no assembly use bl F(nome).
// =====================================================================
#pragma once
#include <stdint.h>
#include "ermo_equ.h"

#define ASM(nome) __asm__(#nome)

extern uint8_t G[] ASM(G);

// campos de G pelo deslocamento
#define G_I32(off)  (*(int32_t  *)(G + (off)))
#define G_U32(off)  (*(uint32_t *)(G + (off)))
#define G_U64(off)  (*(uint64_t *)(G + (off)))
#define G_F32(off)  (*(float    *)(G + (off)))
