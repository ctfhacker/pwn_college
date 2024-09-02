#!/usr/bin/env python3
from pwn import *
context.arch = 'aarch64'

asm_bytes = asm("""
""")

if 'dojo' in os.environ['SHELL']:
  challenge = '/challenge/run'
else:
  challenge = './run'
  
with process(challenge) as p:
  p.send(asm_bytes)
  p.stdin.close()
  p.interactive()
